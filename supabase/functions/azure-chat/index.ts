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

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // AZURE_OPENAI_ENDPOINT should be your AI Foundry Project endpoint,
    // e.g. https://your-project.services.ai.azure.com
    const projectEndpoint = Deno.env.get('AZURE_OPENAI_ENDPOINT')
    const apiKey = Deno.env.get('AZURE_OPENAI_KEY')
    const deployment = Deno.env.get('AZURE_OPENAI_DEPLOYMENT')

    if (!projectEndpoint || !apiKey || !deployment) {
      return new Response(
        JSON.stringify({ error: 'Azure AI Foundry credentials not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const body: RequestBody = await req.json()
    const { conversationHistory, latestUserMessage } = body

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

    // Azure AI Foundry Models REST API (for third-party models like Grok)
    const endpointBase = projectEndpoint.replace(/\/$/, '')
    const url = `${endpointBase}/models/chat/completions?api-version=2024-05-01-preview`

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
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

    if (!response.ok) {
      const errorBody = await response.text()
      return new Response(
        JSON.stringify({ error: `AI Foundry error ${response.status}: ${errorBody}` }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const result = await response.json()
    const content: string = result.choices[0].message.content
    const parsed = JSON.parse(content)

    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
