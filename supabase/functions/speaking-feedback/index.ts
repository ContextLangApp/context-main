import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const workerStartedAt = Date.now()

interface RequestBody {
  transcript: string
  stream?: boolean
}

const SYSTEM_PROMPT = `You are a friendly German tutor giving feedback on what a learner just said in German.
Reply briefly. Correct the major mistakes, explain them in simple English, and give one improved German version of what they tried to say.
Be encouraging and concise.

You MUST respond with valid JSON in exactly this format, with no additional text:
{
  "feedback": "your short feedback here, including the corrections, a simple English explanation, and one improved German version"
}

Return ONLY the raw JSON object. Do not wrap it in markdown code fences and do not add any other text.`

// Streaming mode emits plain feedback text (no JSON envelope) so it can render
// token-by-token in the client.
const STREAM_SYSTEM_PROMPT = `You are a friendly German tutor giving feedback on what a learner just said in German.
Reply briefly in plain text. Correct the major mistakes, explain them in simple English, and give one improved German version of what they tried to say. Be encouraging and concise.
Output only the feedback text. No JSON, no markdown, no code fences.`

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

// Transforms Foundry's OpenAI-style SSE (`data: {chunk}` lines) into a plain
// UTF-8 text stream of just the content deltas. Logs server-side TTFT.
function sseToTextStream(
  source: ReadableStream<Uint8Array>,
  requestId: string,
  tag: string,
): ReadableStream<Uint8Array> {
  const reader = source.getReader()
  const decoder = new TextDecoder()
  const encoder = new TextEncoder()
  const startedAt = Date.now()
  let firstDeltaAt = 0

  return new ReadableStream({
    async start(controller) {
      let buffer = ''
      try {
        outer: while (true) {
          const { done, value } = await reader.read()
          if (done) break
          buffer += decoder.decode(value, { stream: true })
          const lines = buffer.split('\n')
          buffer = lines.pop() ?? ''
          for (const line of lines) {
            const trimmed = line.trim()
            if (!trimmed.startsWith('data:')) continue
            const data = trimmed.slice(5).trim()
            if (data === '[DONE]') break outer
            try {
              const json = JSON.parse(data)
              const delta = json.choices?.[0]?.delta?.content
              if (typeof delta === 'string' && delta.length > 0) {
                if (firstDeltaAt === 0) {
                  firstDeltaAt = Date.now()
                  console.log(`[${tag}][${requestId}] first delta ttftMs=${firstDeltaAt - startedAt}`)
                }
                controller.enqueue(encoder.encode(delta))
              }
            } catch (_) {
              // Ignore keepalives / non-JSON data lines.
            }
          }
        }
      } catch (err) {
        console.error(`[${tag}][${requestId}] stream pump error ${String(err)}`)
      } finally {
        console.log(
          `[${tag}][${requestId}] stream complete totalMs=${Date.now() - startedAt} ttftMs=${firstDeltaAt ? firstDeltaAt - startedAt : -1}`,
        )
        controller.close()
      }
    },
    cancel(reason) {
      reader.cancel(reason)
    },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const requestId = crypto.randomUUID()
  const requestStart = Date.now()
  const elapsed = () => Date.now() - requestStart
  console.log(
    `[speaking-feedback][${requestId}] start ts=${new Date().toISOString()} workerAgeMs=${Date.now() - workerStartedAt} method=${req.method} contentType=${req.headers.get('content-type')} contentLength=${req.headers.get('content-length')}`,
  )

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

    const parseBodyStart = Date.now()
    const body: RequestBody = await req.json()
    const transcript = typeof body.transcript === 'string' ? body.transcript.trim() : ''
    console.log(
      `[speaking-feedback][${requestId}] parsed body transcriptLength=${transcript.length} parseBodyMs=${Date.now() - parseBodyStart} totalMs=${elapsed()}`,
    )

    if (transcript.length === 0) {
      console.error(`[speaking-feedback][${requestId}] missing transcript field`)
      return new Response(
        JSON.stringify({ error: 'transcript field is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const wantStream = body.stream === true
    const messages = [
      { role: 'system', content: wantStream ? STREAM_SYSTEM_PROMPT : SYSTEM_PROMPT },
      { role: 'user', content: `The learner said: "${transcript}"` },
    ]

    const url = buildChatCompletionsUrl(projectEndpoint)
    console.log(`[speaking-feedback][${requestId}] outbound url=${url} stream=${wantStream}`)

    const foundryRequestBody = JSON.stringify({
      model: deployment,
      messages,
      max_tokens: 500,
      temperature: 0.5,
      stream: wantStream,
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
      `[speaking-feedback][${requestId}] foundry response status=${response.status} foundryMs=${Date.now() - foundryStart} requestBytes=${foundryRequestBytes} totalMs=${elapsed()} contentType=${response.headers.get('content-type')}`,
    )

    if (!response.ok) {
      const errorReadStart = Date.now()
      const errorBody = await response.text()
      console.error(
        `[speaking-feedback][${requestId}] foundry error status=${response.status} errorReadMs=${Date.now() - errorReadStart} totalMs=${elapsed()} body=${errorBody.slice(0, 1500)}`,
      )
      return new Response(
        JSON.stringify({ error: `AI Foundry error ${response.status}: ${errorBody}` }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    if (wantStream && response.body) {
      console.log(`[speaking-feedback][${requestId}] streaming response to client`)
      return new Response(sseToTextStream(response.body, requestId, 'speaking-feedback'), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/plain; charset=utf-8',
          'Cache-Control': 'no-cache',
        },
      })
    }

    const responseParseStart = Date.now()
    const result = await response.json()
    const responseParseMs = Date.now() - responseParseStart
    const content: string = result.choices[0].message.content
    console.log(
      `[speaking-feedback][${requestId}] foundry success contentLength=${content?.length ?? 0} responseParseMs=${responseParseMs} totalMs=${elapsed()}`,
    )
    const contentParseStart = Date.now()
    const parsed = JSON.parse(stripJsonCodeFence(content))
    console.log(
      `[speaking-feedback][${requestId}] parsed JSON feedbackLength=${parsed.feedback?.length ?? 0} contentParseMs=${Date.now() - contentParseStart} totalMs=${elapsed()}`,
    )

    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error(`[speaking-feedback][${requestId}] unhandled error totalMs=${elapsed()} error=${String(err)}`)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
