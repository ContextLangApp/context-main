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
  console.log(`[azure-stt][${requestId}] start method=${req.method} contentType=${req.headers.get('content-type')} contentLength=${req.headers.get('content-length')}`)

  try {
    const speechKey = Deno.env.get('AZURE_SPEECH_KEY')
    const speechRegion = Deno.env.get('AZURE_SPEECH_REGION')
    console.log(`[azure-stt][${requestId}] env speechKeyPresent=${Boolean(speechKey)} speechRegion=${speechRegion ?? 'missing'}`)

    if (!speechKey || !speechRegion) {
      console.error(`[azure-stt][${requestId}] missing Azure Speech credentials`)
      return new Response(
        JSON.stringify({ error: 'Azure Speech credentials not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const audioBytes = await req.arrayBuffer()
    console.log(`[azure-stt][${requestId}] received audioBytes=${audioBytes.byteLength}`)

    const sttUrl =
      `https://${speechRegion}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=de-DE&format=detailed`

    const response = await fetch(sttUrl, {
      method: 'POST',
      headers: {
        'Ocp-Apim-Subscription-Key': speechKey,
        'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
      },
      body: audioBytes,
    })
    console.log(`[azure-stt][${requestId}] azure response status=${response.status} contentType=${response.headers.get('content-type')}`)

    if (!response.ok) {
      const errorBody = await response.text()
      console.error(`[azure-stt][${requestId}] azure error status=${response.status} body=${errorBody.slice(0, 1000)}`)
      return new Response(
        JSON.stringify({ error: `Azure STT error ${response.status}: ${errorBody}` }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const result = await response.json()
    const transcript: string = result.DisplayText ?? ''
    console.log(`[azure-stt][${requestId}] success recognitionStatus=${result.RecognitionStatus ?? 'unknown'} transcriptLength=${transcript.length}`)

    return new Response(JSON.stringify({ transcript }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error(`[azure-stt][${requestId}] unhandled error ${String(err)}`)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
