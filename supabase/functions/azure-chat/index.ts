import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

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
{"waiterResponse": "your German response here", "tip": "English learning tip here"}`

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
  console.log(`[azure-chat][${requestId}] start method=${req.method} contentType=${req.headers.get('content-type')} contentLength=${req.headers.get('content-length')}`)

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

    const body: RequestBody = await req.json()
    const { conversationHistory, latestUserMessage } = body
    console.log(
      `[azure-chat][${requestId}] parsed body historyCount=${conversationHistory?.length ?? 0} latestLength=${latestUserMessage?.length ?? 0}`,
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

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: deployment,
        messages,
        response_format: { type: 'json_object' },
        max_tokens: 400,
        temperature: 0.7,
      }),
    })
    console.log(`[azure-chat][${requestId}] foundry response status=${response.status} contentType=${response.headers.get('content-type')}`)

    if (!response.ok) {
      const errorBody = await response.text()
      console.error(`[azure-chat][${requestId}] foundry error status=${response.status} body=${errorBody.slice(0, 1500)}`)
      return new Response(
        JSON.stringify({ error: `AI Foundry error ${response.status}: ${errorBody}` }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const result = await response.json()
    const content: string = result.choices[0].message.content
    console.log(`[azure-chat][${requestId}] foundry success contentLength=${content?.length ?? 0}`)
    const parsed = JSON.parse(content)
    console.log(
      `[azure-chat][${requestId}] parsed JSON waiterLength=${parsed.waiterResponse?.length ?? 0} tipLength=${parsed.tip?.length ?? 0}`,
    )

    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error(`[azure-chat][${requestId}] unhandled error ${String(err)}`)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
