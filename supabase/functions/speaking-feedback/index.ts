import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RequestBody {
  transcript: string
}

const SYSTEM_PROMPT = `You are a friendly German tutor giving feedback on what a learner just said in German.
Reply briefly. Correct the major mistakes, explain them in simple English, and give one improved German version of what they tried to say.
Be encouraging and concise.

You MUST respond with valid JSON in exactly this format, with no additional text:
{
  "feedback": "your short feedback here, including the corrections, a simple English explanation, and one improved German version"
}

Return ONLY the raw JSON object. Do not wrap it in markdown code fences and do not add any other text.`

// Some Azure AI Foundry (Grok) deployments wrap JSON in ```json fences even
// when asked not to. Strip them before parsing.
function stripJsonCodeFence(text: string): string {
  const trimmed = text.trim()
  if (!trimmed.startsWith('```')) return trimmed
  return trimmed
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/, '')
    .trim()
}

function buildChatCompletionsUrl(endpoint: string): string {
  const normalized = endpoint.replace(/\/+$/, '')

  if (normalized.endsWith('/chat/completions')) {
    return normalized
  }

  if (normalized.endsWith('/openai/v1')) {
    return `${normalized}/chat/completions`
  }

  if (normalized.endsWith('/openai')) {
    return `${normalized}/v1/chat/completions`
  }

  return `${normalized}/openai/v1/chat/completions`
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const requestId = crypto.randomUUID()
  console.log(`[speaking-feedback][${requestId}] start method=${req.method} contentType=${req.headers.get('content-type')} contentLength=${req.headers.get('content-length')}`)

  try {
    const projectEndpoint = Deno.env.get('AZURE_OPENAI_ENDPOINT')
    const apiKey = Deno.env.get('AZURE_OPENAI_KEY')
    const deployment = Deno.env.get('AZURE_OPENAI_DEPLOYMENT')
    console.log(
      `[speaking-feedback][${requestId}] env endpointPresent=${Boolean(projectEndpoint)} keyPresent=${Boolean(apiKey)} deployment=${deployment ?? 'missing'}`,
    )

    if (!projectEndpoint || !apiKey || !deployment) {
      console.error(`[speaking-feedback][${requestId}] missing AI Foundry credentials`)
      return new Response(
        JSON.stringify({ error: 'Azure AI Foundry credentials not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const body: RequestBody = await req.json()
    const transcript = typeof body.transcript === 'string' ? body.transcript.trim() : ''
    console.log(`[speaking-feedback][${requestId}] parsed body transcriptLength=${transcript.length}`)

    if (transcript.length === 0) {
      console.error(`[speaking-feedback][${requestId}] missing transcript field`)
      return new Response(
        JSON.stringify({ error: 'transcript field is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const messages = [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: `The learner said: "${transcript}"` },
    ]

    const url = buildChatCompletionsUrl(projectEndpoint)
    console.log(`[speaking-feedback][${requestId}] outbound url=${url}`)

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: deployment,
        messages,
        max_tokens: 500,
        temperature: 0.5,
      }),
    })
    console.log(`[speaking-feedback][${requestId}] foundry response status=${response.status} contentType=${response.headers.get('content-type')}`)

    if (!response.ok) {
      const errorBody = await response.text()
      console.error(`[speaking-feedback][${requestId}] foundry error status=${response.status} body=${errorBody.slice(0, 1500)}`)
      return new Response(
        JSON.stringify({ error: `AI Foundry error ${response.status}: ${errorBody}` }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const result = await response.json()
    const content: string = result.choices[0].message.content
    console.log(`[speaking-feedback][${requestId}] foundry success contentLength=${content?.length ?? 0}`)
    const parsed = JSON.parse(stripJsonCodeFence(content))
    console.log(
      `[speaking-feedback][${requestId}] parsed JSON feedbackLength=${parsed.feedback?.length ?? 0}`,
    )

    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error(`[speaking-feedback][${requestId}] unhandled error ${String(err)}`)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
