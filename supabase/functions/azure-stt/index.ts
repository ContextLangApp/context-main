import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const workerStartedAt = Date.now()

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const requestId = crypto.randomUUID()
  const requestStart = Date.now()
  const elapsed = () => Date.now() - requestStart
  console.log(
    `[azure-stt][${requestId}] start ts=${new Date().toISOString()} workerAgeMs=${Date.now() - workerStartedAt} method=${req.method} contentType=${req.headers.get('content-type')} contentLength=${req.headers.get('content-length')}`,
  )

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

    const bodyReadStart = Date.now()
    const audioBytes = await req.arrayBuffer()
    console.log(
      `[azure-stt][${requestId}] received audioBytes=${audioBytes.byteLength} bodyReadMs=${Date.now() - bodyReadStart} totalMs=${elapsed()}`,
    )

    const sttUrl =
      `https://${speechRegion}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=de-DE&format=detailed`

    const azureStart = Date.now()
    const response = await fetch(sttUrl, {
      method: 'POST',
      headers: {
        'Ocp-Apim-Subscription-Key': speechKey,
        'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
      },
      body: audioBytes,
    })
    console.log(
      `[azure-stt][${requestId}] azure response status=${response.status} azureMs=${Date.now() - azureStart} totalMs=${elapsed()} contentType=${response.headers.get('content-type')}`,
    )

    if (!response.ok) {
      const errorReadStart = Date.now()
      const errorBody = await response.text()
      console.error(
        `[azure-stt][${requestId}] azure error status=${response.status} errorReadMs=${Date.now() - errorReadStart} totalMs=${elapsed()} body=${errorBody.slice(0, 1000)}`,
      )
      return new Response(
        JSON.stringify({ error: `Azure STT error ${response.status}: ${errorBody}` }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const parseStart = Date.now()
    const result = await response.json()
    const parseMs = Date.now() - parseStart
    const transcript: string = result.DisplayText ?? ''
    console.log(
      `[azure-stt][${requestId}] success recognitionStatus=${result.RecognitionStatus ?? 'unknown'} transcriptLength=${transcript.length} parseMs=${parseMs} totalMs=${elapsed()}`,
    )

    return new Response(JSON.stringify({ transcript }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error(`[azure-stt][${requestId}] unhandled error totalMs=${elapsed()} error=${String(err)}`)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
