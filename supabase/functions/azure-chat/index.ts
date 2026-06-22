import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const workerStartedAt = Date.now()

interface HistoryMessage {
  role: 'waiter' | 'user'
  text: string
}

interface RequestBody {
  conversationHistory: HistoryMessage[]
  latestUserMessage: string
}

const SYSTEM_PROMPT = `You are a friendly German restaurant waiter helping a language learner practice German conversation.
Respond naturally in German as a waiter would. Keep your response concise (1-3 sentences).
Also provide a brief learning tip in English about a German phrase, grammar point, or vocabulary word from the conversation.

You MUST respond with valid JSON in exactly this format, with no additional text:
{"waiterResponse": "your German response here", "tip": "English learning tip here"}

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
  const requestStart = Date.now()
  const elapsed = () => Date.now() - requestStart
  console.log(
    `[azure-chat][${requestId}] start ts=${new Date().toISOString()} workerAgeMs=${Date.now() - workerStartedAt} method=${req.method} contentType=${req.headers.get('content-type')} contentLength=${req.headers.get('content-length')}`,
  )

  try {
    // AZURE_OPENAI_ENDPOINT can be either:
    // - https://your-resource.services.ai.azure.com/openai/v1
    // - https://your-resource.services.ai.azure.com/openai/v1/chat/completions
    // - https://your-resource.openai.azure.com/openai/v1
    const projectEndpoint = Deno.env.get('AZURE_OPENAI_ENDPOINT')
    const apiKey = Deno.env.get('AZURE_OPENAI_KEY')
    const deployment = Deno.env.get('AZURE_OPENAI_DEPLOYMENT')
    console.log(
      `[azure-chat][${requestId}] env endpointPresent=${Boolean(projectEndpoint)} keyPresent=${Boolean(apiKey)} deployment=${deployment ?? 'missing'}`,
    )

    if (!projectEndpoint || !apiKey || !deployment) {
      console.error(`[azure-chat][${requestId}] missing AI Foundry credentials`)
      return new Response(
        JSON.stringify({ error: 'Azure AI Foundry credentials not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const parseBodyStart = Date.now()
    const body: RequestBody = await req.json()
    const parseBodyMs = Date.now() - parseBodyStart
    const { conversationHistory, latestUserMessage } = body
    console.log(
      `[azure-chat][${requestId}] parsed body historyCount=${conversationHistory?.length ?? 0} latestLength=${latestUserMessage?.length ?? 0} parseBodyMs=${parseBodyMs} totalMs=${elapsed()}`,
    )

    const messages: { role: string; content: string }[] = [
      { role: 'system', content: SYSTEM_PROMPT },
    ]

    for (const msg of conversationHistory) {
      messages.push({
        role: msg.role === 'waiter' ? 'assistant' : 'user',
        content: msg.text,
      })
    }

    messages.push({ role: 'user', content: latestUserMessage })

    // Grok deployments in Azure AI Foundry use the v1 OpenAI-compatible route.
    const url = buildChatCompletionsUrl(projectEndpoint)
    console.log(`[azure-chat][${requestId}] outbound url=${url} messageCount=${messages.length}`)

    const foundryRequestBody = JSON.stringify({
      model: deployment,
      messages,
      max_tokens: 800,
      temperature: 0.7,
    })
    const foundryRequestBytes = new TextEncoder().encode(foundryRequestBody).length
    const foundryStart = Date.now()
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: foundryRequestBody,
    })
    console.log(
      `[azure-chat][${requestId}] foundry response status=${response.status} foundryMs=${Date.now() - foundryStart} requestBytes=${foundryRequestBytes} totalMs=${elapsed()} contentType=${response.headers.get('content-type')}`,
    )

    if (!response.ok) {
      const errorReadStart = Date.now()
      const errorBody = await response.text()
      console.error(
        `[azure-chat][${requestId}] foundry error status=${response.status} errorReadMs=${Date.now() - errorReadStart} totalMs=${elapsed()} body=${errorBody.slice(0, 1500)}`,
      )
      return new Response(
        JSON.stringify({ error: `AI Foundry error ${response.status}: ${errorBody}` }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const responseParseStart = Date.now()
    const result = await response.json()
    const responseParseMs = Date.now() - responseParseStart
    const content: string = result.choices[0].message.content
    console.log(
      `[azure-chat][${requestId}] foundry success contentLength=${content?.length ?? 0} responseParseMs=${responseParseMs} totalMs=${elapsed()}`,
    )
    const contentParseStart = Date.now()
    const parsed = JSON.parse(stripJsonCodeFence(content))
    console.log(
      `[azure-chat][${requestId}] parsed JSON waiterLength=${parsed.waiterResponse?.length ?? 0} tipLength=${parsed.tip?.length ?? 0} contentParseMs=${Date.now() - contentParseStart} totalMs=${elapsed()}`,
    )

    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error(`[azure-chat][${requestId}] unhandled error totalMs=${elapsed()} error=${String(err)}`)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
