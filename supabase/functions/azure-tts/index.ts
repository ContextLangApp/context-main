import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const requestId = crypto.randomUUID()
  console.log(`[azure-tts][${requestId}] start method=${req.method} contentType=${req.headers.get('content-type')} contentLength=${req.headers.get('content-length')}`)

  try {
    const speechKey = Deno.env.get('AZURE_SPEECH_KEY')
    const speechRegion = Deno.env.get('AZURE_SPEECH_REGION')
    console.log(`[azure-tts][${requestId}] env speechKeyPresent=${Boolean(speechKey)} speechRegion=${speechRegion ?? 'missing'}`)

    if (!speechKey || !speechRegion) {
      console.error(`[azure-tts][${requestId}] missing Azure Speech credentials`)
      return new Response(
        JSON.stringify({ error: 'Azure Speech credentials not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const { text } = await req.json()
    console.log(`[azure-tts][${requestId}] parsed body textType=${typeof text} textLength=${typeof text === 'string' ? text.length : 0}`)

    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      console.error(`[azure-tts][${requestId}] missing text field`)
      return new Response(
        JSON.stringify({ error: 'text field is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const escaped = text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;')

    const ssml = `<speak version='1.0' xml:lang='de-DE'>
  <voice name='de-DE-KatjaNeural'>
    <prosody rate='0.9'>${escaped}</prosody>
  </voice>
</speak>`

    const ttsUrl = `https://${speechRegion}.tts.speech.microsoft.com/cognitiveservices/v1`

    const response = await fetch(ttsUrl, {
      method: 'POST',
      headers: {
        'Ocp-Apim-Subscription-Key': speechKey,
        'Content-Type': 'application/ssml+xml',
        'User-Agent': 'ContextGermanLearningApp',
        'X-Microsoft-OutputFormat': 'audio-16khz-32kbitrate-mono-mp3',
      },
      body: ssml,
    })
    console.log(`[azure-tts][${requestId}] azure response status=${response.status} contentType=${response.headers.get('content-type')}`)

    if (!response.ok) {
      const errorBody = await response.text()
      console.error(`[azure-tts][${requestId}] azure error status=${response.status} body=${errorBody.slice(0, 1000)}`)
      return new Response(
        JSON.stringify({ error: `Azure TTS error ${response.status}: ${errorBody}` }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const audioBytes = await response.arrayBuffer()
    console.log(`[azure-tts][${requestId}] success audioBytes=${audioBytes.byteLength}`)

    return new Response(audioBytes, {
      headers: {
        ...corsHeaders,
        'Content-Type': 'audio/mpeg',
      },
    })
  } catch (err) {
    console.error(`[azure-tts][${requestId}] unhandled error ${String(err)}`)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
