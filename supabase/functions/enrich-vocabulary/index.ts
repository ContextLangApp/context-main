import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RequestBody {
  word: string
  sourceContext?: string
}

const SYSTEM_PROMPT = `You are a German tutor enriching a single German word for a language learner's personal dictionary.
You are given the word and the sentence it appeared in (its context). Use the context to pick the correct meaning when the word is ambiguous.

You MUST respond with valid JSON in exactly this format, with no additional text:
{
  "word": "the German word, with correct capitalization and article if it is a noun (e.g. 'der Tisch')",
  "normalizedWord": "the lowercase base form of the word, no punctuation",
  "meaning": "a short, simple English meaning",
  "pronunciation": "an easy-to-read pronunciation hint (not strict IPA), e.g. 'der TISH'",
  "exampleSentence": "a short, natural German example sentence using the word",
  "realLifeUsage": "one brief English sentence on where or when this word is commonly used"
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
  console.log(`[enrich-vocabulary][${requestId}] start method=${req.method} contentType=${req.headers.get('content-type')} contentLength=${req.headers.get('content-length')}`)

  try {
    const projectEndpoint = Deno.env.get('AZURE_OPENAI_ENDPOINT')
    const apiKey = Deno.env.get('AZURE_OPENAI_KEY')
    const deployment = Deno.env.get('AZURE_OPENAI_DEPLOYMENT')
    console.log(
      `[enrich-vocabulary][${requestId}] env endpointPresent=${Boolean(projectEndpoint)} keyPresent=${Boolean(apiKey)} deployment=${deployment ?? 'missing'}`,
    )

    if (!projectEndpoint || !apiKey || !deployment) {
      console.error(`[enrich-vocabulary][${requestId}] missing AI Foundry credentials`)
      return new Response(
        JSON.stringify({ error: 'Azure AI Foundry credentials not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const body: RequestBody = await req.json()
    const word = typeof body.word === 'string' ? body.word.trim() : ''
    const sourceContext = typeof body.sourceContext === 'string' ? body.sourceContext.trim() : ''
    console.log(
      `[enrich-vocabulary][${requestId}] parsed body wordLength=${word.length} contextLength=${sourceContext.length}`,
    )

    if (word.length === 0) {
      console.error(`[enrich-vocabulary][${requestId}] missing word field`)
      return new Response(
        JSON.stringify({ error: 'word field is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const userContent = sourceContext.length > 0
      ? `Word: "${word}"\nContext: "${sourceContext}"`
      : `Word: "${word}"\nContext: (none provided)`

    const messages = [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: userContent },
    ]

    const url = buildChatCompletionsUrl(projectEndpoint)
    console.log(`[enrich-vocabulary][${requestId}] outbound url=${url}`)

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: deployment,
        messages,
        max_tokens: 1000,
        temperature: 0.5,
      }),
    })
    console.log(`[enrich-vocabulary][${requestId}] foundry response status=${response.status} contentType=${response.headers.get('content-type')}`)

    if (!response.ok) {
      const errorBody = await response.text()
      console.error(`[enrich-vocabulary][${requestId}] foundry error status=${response.status} body=${errorBody.slice(0, 1500)}`)
      return new Response(
        JSON.stringify({ error: `AI Foundry error ${response.status}: ${errorBody}` }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const result = await response.json()
    const content: string = result.choices[0].message.content
    console.log(`[enrich-vocabulary][${requestId}] foundry success contentLength=${content?.length ?? 0}`)
    const parsed = JSON.parse(stripJsonCodeFence(content))
    console.log(
      `[enrich-vocabulary][${requestId}] parsed JSON normalizedWord=${parsed.normalizedWord ?? 'missing'} meaningLength=${parsed.meaning?.length ?? 0}`,
    )

    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error(`[enrich-vocabulary][${requestId}] unhandled error ${String(err)}`)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
