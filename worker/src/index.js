const EMOTIONS = new Set([
  "neutral", "happy", "excited", "love", "shy", "sad", "angry", "annoyed",
  "confused", "surprised", "curious", "sleepy", "tired", "embarrassed",
  "proud", "worried", "playful", "caring", "jealous", "thinking",
]);

const ANIMATIONS = new Set([
  "idle", "blink", "double_blink", "look_left", "look_right", "look_up",
  "look_down", "look_away", "happy", "excited", "love", "shy", "sad",
  "angry", "confused", "surprised", "sleep", "wake_up", "think", "nod",
  "shake", "bounce", "listen", "speak",
]);

const SOUNDS = new Set([
  "idle", "blink", "wake", "listen", "think", "happy", "sad", "angry",
  "surprised", "cute", "shy", "love", "sleep", "wake_from_sleep",
  "charging", "success", "error", "movement", "none",
]);

const EYE_DIRS = new Set(["center", "left", "right", "up", "down", "away"]);
const rateLimitMap = new Map();

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return cors(new Response(null, { status: 204 }));
    }

    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return cors(json({
        ok: true,
        service: "buddy-ai-worker",
        features: ["chat", "tts", "stt", "stt-stream"],
      }));
    }

    if (request.method === "GET" && url.pathname === "/debug/ai") {
      return cors(await handleDebugAi(env));
    }

    if (request.headers.get("Upgrade") === "websocket" && url.pathname === "/stt/ws") {
      return handleSttWebSocket(request, env, url);
    }

    if (request.method === "POST" && url.pathname === "/stt") {
      try {
        return cors(await handleSttRest(request, env));
      } catch (err) {
        console.error(err);
        return cors(json({ error: "STT failed" }, 500));
      }
    }

    if (request.method === "POST" && url.pathname === "/chat") {
      try {
        return cors(await handleChat(request, env));
      } catch (err) {
        console.error(err);
        return cors(json({ error: "Internal error" }, 500));
      }
    }

    if (request.method === "POST" && url.pathname === "/tts") {
      try {
        return await handleTts(request, env);
      } catch (err) {
        console.error(err);
        return cors(json({ error: "TTS failed" }, 500));
      }
    }

    return cors(json({ error: "Not found" }, 404));
  },
};

function buildSarvamWsUrl(env, languageCode, model, mode) {
  const sarvamUrl = new URL("https://api.sarvam.ai/speech-to-text/ws");
  sarvamUrl.searchParams.set("language-code", languageCode);
  sarvamUrl.searchParams.set("model", model);
  sarvamUrl.searchParams.set("mode", mode);
  sarvamUrl.searchParams.set("sample_rate", "16000");
  sarvamUrl.searchParams.set("high_vad_sensitivity", "true");
  sarvamUrl.searchParams.set("vad_signals", "true");
  sarvamUrl.searchParams.set("flush_signal", "true");
  sarvamUrl.searchParams.set("input_audio_codec", "pcm_s16le");
  return sarvamUrl;
}

async function connectSarvamWebSocket(env, languageCode, model, mode) {
  const apiKey = env.SARVAM_API_KEY;
  if (!apiKey) {
    throw new Error("Sarvam STT is not configured");
  }

  const sarvamUrl = buildSarvamWsUrl(env, languageCode, model, mode);
  const upstreamResponse = await fetch(sarvamUrl.toString(), {
    headers: {
      Upgrade: "websocket",
      Connection: "Upgrade",
      "Api-Subscription-Key": apiKey,
    },
  });

  if (upstreamResponse.status !== 101 || !upstreamResponse.webSocket) {
    const detail = await upstreamResponse.text().catch(() => "");
    throw new Error(
      `Sarvam WebSocket handshake failed (${upstreamResponse.status})${detail ? `: ${detail.slice(0, 120)}` : ""}`
    );
  }

  const upstream = upstreamResponse.webSocket;
  upstream.accept({ allowHalfOpen: true });
  return upstream;
}

async function handleSttWebSocket(request, env, url) {
  const installationId = String(url.searchParams.get("installationId") || "").slice(0, 80);
  if (!installationId) {
    return cors(json({ error: "installationId is required" }, 400));
  }

  const rateLimit = Number(env.RATE_LIMIT_PER_MINUTE || 30);
  if (!allowRequest(`${installationId}:stt`, rateLimit)) {
    return cors(json({ error: "Rate limit exceeded" }, 429));
  }

  const languageCode = String(
    url.searchParams.get("language_code") ||
      env.SARVAM_LANGUAGE_CODE ||
      "unknown"
  ).slice(0, 16);

  const model = String(url.searchParams.get("model") || env.SARVAM_MODEL || "saaras:v3");
  const mode = String(url.searchParams.get("mode") || env.SARVAM_MODE || "transcribe");

  let upstream;
  try {
    upstream = await connectSarvamWebSocket(env, languageCode, model, mode);
  } catch (err) {
    console.error("Sarvam WS connect failed", err);
    return cors(json({
      error: "Failed to connect to Sarvam STT",
      detail: String(err?.message || err),
    }, 502));
  }

  const pair = new WebSocketPair();
  const [client, server] = Object.values(pair);
  server.accept({ allowHalfOpen: true });

  const closeBoth = (code = 1000, reason = "closed") => {
    try { server.close(code, reason); } catch (_) {}
    try { upstream.close(code, reason); } catch (_) {}
  };

  server.addEventListener("message", (event) => {
    try {
      upstream.send(event.data);
    } catch (err) {
      console.error("Forward to Sarvam failed", err);
      closeBoth(1011, "forward failed");
    }
  });

  upstream.addEventListener("message", (event) => {
    try {
      server.send(event.data);
    } catch (err) {
      console.error("Forward to client failed", err);
      closeBoth(1011, "forward failed");
    }
  });

  server.addEventListener("close", () => closeBoth());
  upstream.addEventListener("close", () => closeBoth());
  server.addEventListener("error", () => closeBoth(1011, "client error"));
  upstream.addEventListener("error", () => closeBoth(1011, "upstream error"));

  return new Response(null, { status: 101, webSocket: client });
}

async function handleSttRest(request, env) {
  const apiKey = env.SARVAM_API_KEY;
  if (!apiKey) {
    return json({ error: "Sarvam STT is not configured" }, 503);
  }

  const contentType = request.headers.get("content-type") || "";
  if (!contentType.includes("application/json")) {
    return json({ error: "Content-Type must be application/json" }, 415);
  }

  const raw = await request.text();
  if (raw.length > 8_000_000) {
    return json({ error: "Request too large" }, 413);
  }

  let body;
  try {
    body = JSON.parse(raw);
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const installationId = String(body.installationId || "").slice(0, 80);
  const audioBase64 = String(body.audioBase64 || "").trim();
  if (!installationId || !audioBase64) {
    return json({ error: "installationId and audioBase64 are required" }, 400);
  }

  const rateLimit = Number(env.RATE_LIMIT_PER_MINUTE || 30);
  if (!allowRequest(`${installationId}:stt`, rateLimit)) {
    return json({ error: "Rate limit exceeded" }, 429);
  }

  const languageCode = String(
    body.language_code || env.SARVAM_LANGUAGE_CODE || "unknown"
  ).slice(0, 16);
  const model = String(body.model || env.SARVAM_MODEL || "saaras:v3");
  const mode = String(body.mode || env.SARVAM_MODE || "transcribe");

  let audioBytes;
  try {
    audioBytes = Uint8Array.from(atob(audioBase64), (c) => c.charCodeAt(0));
  } catch {
    return json({ error: "Invalid audioBase64 payload" }, 400);
  }

  if (audioBytes.length === 0) {
    return json({ error: "Empty audio payload" }, 400);
  }

  const form = new FormData();
  form.append("file", new Blob([audioBytes], { type: "audio/wav" }), "audio.wav");
  form.append("model", model);
  form.append("mode", mode);
  if (languageCode && languageCode !== "unknown") {
    form.append("language_code", languageCode);
  }

  const sarvamRes = await fetch("https://api.sarvam.ai/speech-to-text", {
    method: "POST",
    headers: {
      "api-subscription-key": apiKey,
    },
    body: form,
  });

  const sarvamData = await sarvamRes.json().catch(() => ({}));
  if (!sarvamRes.ok) {
    const message = sarvamData?.message || sarvamData?.error || `Sarvam STT HTTP ${sarvamRes.status}`;
    return json({ error: message, status: sarvamRes.status }, 502);
  }

  const transcript = String(sarvamData.transcript || "").trim();
  if (!transcript) {
    return json({ error: "Sarvam returned an empty transcript" }, 502);
  }

  return json({
    transcript,
    language_code: sarvamData.language_code || languageCode,
    request_id: sarvamData.request_id || null,
  });
}

async function handleDebugAi(env) {
  try {
    const probe = [{
      role: "user",
      content: 'Reply with exactly: {"reply":"pong","emotion":"happy","animation":"idle","sound":"cute","eyeDirection":"center","speak":true,"language":"en-IN"}',
    }];
    const googleKey = env.GOOGLE_AI_API_KEY || env.GEMINI_API_KEY;
    if (!googleKey) {
      return json({ ok: false, error: "Set GOOGLE_AI_API_KEY for Gemini chat" }, 500);
    }
    const model = env.GOOGLE_AI_MODEL || "gemini-3.5-flash-lite";
    const extracted = await callGemini(env, probe, googleKey);
    return json({ ok: true, provider: "gemini", model, extracted });
  } catch (err) {
    return json({ ok: false, error: String(err?.message || err) }, 500);
  }
}

async function handleChat(request, env) {
  const maxChars = Number(env.MAX_MESSAGE_CHARS || 1200);
  const maxTurns = Number(env.MAX_CONTEXT_TURNS || 8);
  const rateLimit = Number(env.RATE_LIMIT_PER_MINUTE || 30);
  const contentType = request.headers.get("content-type") || "";
  if (!contentType.includes("application/json")) {
    return json({ error: "Content-Type must be application/json" }, 415);
  }

  const raw = await request.text();
  if (raw.length > 40000) return json({ error: "Request too large" }, 413);

  let body;
  try {
    body = JSON.parse(raw);
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const installationId = String(body.installationId || "").slice(0, 80);
  const message = String(body.message || "").trim();
  if (!installationId || !message) {
    return json({ error: "installationId and message are required" }, 400);
  }
  if (message.length > maxChars) return json({ error: "Message too long" }, 400);
  if (!allowRequest(installationId, rateLimit)) {
    return json({ error: "Rate limit exceeded. Slow down a bit." }, 429);
  }

  const language = String(body.language || "auto").slice(0, 16);
  const personality = String(body.personality || "friendly").slice(0, 32);
  const robotName = String(body.robotName || "Nova").slice(0, 32);
  const webSearchEnabled = body.webSearchEnabled !== false;
  const traits = body.personalityTraits && typeof body.personalityTraits === "object"
    ? body.personalityTraits
    : {};
  const memoryNotes = Array.isArray(body.memoryNotes)
    ? body.memoryNotes.map((n) => String(n).slice(0, 120)).slice(0, 12)
    : [];
  const context = Array.isArray(body.conversationContext)
    ? body.conversationContext.slice(-maxTurns).map((t) => ({
        role: t.role === "assistant" ? "assistant" : "user",
        content: String(t.content || "").slice(0, maxChars),
      }))
    : [];

  let searchNotes = "";
  if (webSearchEnabled && needsWebSearch(message)) {
    searchNotes = await runWebSearch(message, env);
  }

  const system = buildSystemPrompt({
    robotName,
    personality,
    traits,
    language,
    memoryNotes,
    searchNotes,
  });

  const messages = [
    { role: "system", content: system },
    ...context,
    { role: "user", content: message },
  ];

  let modelText = "";
  try {
    modelText = await callBuddyAi(env, messages);
  } catch (err) {
    console.error("AI error", err);
    const detail = err?.message ? String(err.message).slice(0, 160) : "unknown";
    return json(sanitizeResponse({
      reply: `My brain hiccuped for a second (${detail}). Try again?`,
      emotion: "confused",
      animation: "confused",
      sound: "error",
      eyeDirection: "center",
      speak: true,
      language: language === "auto" ? "en-IN" : language,
    }));
  }

  const parsed = parseModelJson(modelText, language);
  return json(sanitizeResponse(parsed));
}

function buildSystemPrompt({ robotName, personality, traits, language, memoryNotes, searchNotes }) {
  return `You are ${robotName}, a warm and helpful voice companion (not human).
Personality: ${personality}. Traits: ${JSON.stringify(traits)}.

LANGUAGE: Reply in the user's language (en/hi/te/ta/kn/ml/mr/bn/gu/pa/or). Match their language naturally. Never announce language detection.

VOICE / TTS RULES (critical — "reply" is read aloud by text-to-speech):
- Write exactly 1 to 3 short, complete sentences with correct grammar.
- Each sentence must be a full thought. End every sentence with . ? or !
- Use natural spoken phrasing, as if talking to a friend — not essay or chatbot style.
- Use periods between sentences. Use commas only inside a sentence, never to join separate ideas.
- Maximum about 35 words total in "reply".
- No bullet points, numbered lists, markdown, symbols, URLs, or JSON in "reply".
- No emojis, asterisks, hashtags, or parenthetical stage directions.
- No semicolons, colons introducing lists, or long run-on sentences.
- Prefer simple everyday words over jargon or overly formal phrasing.
- Never put beep/boop/whirr/buzz/SFX words or emotion labels in "reply".
- Put robot SFX only in "sound". Put mood only in "emotion".

GOOD "reply" examples:
- "Good morning. I am doing well. How can I help you today?"
- "The weather is sunny today. The temperature is around 32 degrees."

BAD "reply" examples (never do this):
- "Good morning, I am doing well, how can I help" (comma run-on)
- "Here are options: call, reminder, search" (list style)
- "Sure! **happy** beep boop" (markdown / SFX in reply)

${memoryNotes.length ? `Memory:\n- ${memoryNotes.join("\n- ")}` : ""}
${searchNotes ? `Current info:\n${searchNotes}` : ""}

Return ONLY JSON:
{"reply":"string","emotion":"happy|caring|curious|shy|playful|confused|surprised|sad|angry|sleepy|thinking|neutral","animation":"idle|bounce|look_away|think|confused|speak","sound":"cute|happy|shy|think|error|none","eyeDirection":"center|left|right|up|down|away","speak":true,"language":"en-IN|hi-IN|te-IN"}`;
}

const GEMINI_REPLY_SCHEMA = {
  type: "object",
  properties: {
    reply: {
      type: "string",
      description: "One to three short, grammatically correct spoken sentences.",
    },
    emotion: { type: "string" },
    animation: { type: "string" },
    sound: { type: "string" },
    eyeDirection: { type: "string" },
    speak: { type: "boolean" },
    language: { type: "string" },
  },
  required: ["reply", "emotion", "animation", "sound", "eyeDirection", "speak", "language"],
};

async function callBuddyAi(env, messages) {
  const googleKey = env.GOOGLE_AI_API_KEY || env.GEMINI_API_KEY;
  if (!googleKey) {
    const last = messages[messages.length - 1]?.content || "";
    return JSON.stringify({
      reply: inventLocalFallback(last),
      emotion: "curious",
      animation: "idle",
      sound: "cute",
      eyeDirection: "center",
      speak: true,
      language: guessLanguage(last),
    });
  }

  const text = await callGemini(env, messages, googleKey);
  if (!text?.trim()) {
    throw new Error("Gemini returned an empty response");
  }
  return text;
}

async function callGemini(env, messages, apiKey) {
  const model = env.GOOGLE_AI_MODEL || "gemini-3.5-flash-lite";
  const systemParts = [];
  const contents = [];

  for (const msg of messages) {
    if (msg.role === "system") {
      systemParts.push(String(msg.content || ""));
      continue;
    }
    contents.push({
      role: msg.role === "assistant" ? "model" : "user",
      parts: [{ text: String(msg.content || "") }],
    });
  }

  if (contents.length === 0) throw new Error("Gemini request missing user content");
  if (contents[0].role !== "user") {
    contents.unshift({ role: "user", parts: [{ text: "Hello" }] });
  }

  const body = {
    contents,
    generationConfig: {
      temperature: 0.35,
      maxOutputTokens: 320,
      responseMimeType: "application/json",
      responseSchema: GEMINI_REPLY_SCHEMA,
    },
  };

  if (systemParts.length) {
    body.systemInstruction = { parts: [{ text: systemParts.join("\n\n") }] };
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify(body),
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = data?.error?.message || data?.message || `Gemini HTTP ${res.status}`;
    throw new Error(msg);
  }

  const text = extractGeminiText(data);
  if (!text) throw new Error("Gemini returned empty text");
  return text;
}

function extractGeminiText(data) {
  const parts = data?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return "";
  return parts.map((p) => (typeof p?.text === "string" ? p.text : "")).join("").trim();
}

function inventLocalFallback(message) {
  const lower = message.toLowerCase();
  if (lower.includes("tired")) return "Please take a moment to rest. I am here with you.";
  if (lower.includes("bored")) return "Shall we try a reminder, a call, or a quick search?";
  return "I am in local mode without an AI key, but I am still here with you.";
}

function guessLanguage(text) {
  if (/[\u0C00-\u0C7F]/.test(text)) return "te-IN";
  if (/[\u0900-\u097F]/.test(text)) return "hi-IN";
  if (/[\u0B80-\u0BFF]/.test(text)) return "ta-IN";
  return "en-IN";
}

function parseModelJson(text, languageHint) {
  const fallbackLang = languageHint === "auto" ? "en-IN" : languageHint;
  const cleaned = String(text || "")
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();

  const extracted = extractJsonObject(cleaned);
  if (extracted) {
    const unwrapped = unwrapReplyObject(extracted);
    if (unwrapped && typeof unwrapped.reply === "string" && unwrapped.reply.trim()) {
      return unwrapped;
    }
  }

  if (cleaned && !cleaned.startsWith("{") && !cleaned.startsWith("[")) {
    return {
      reply: cleaned.slice(0, 400),
      emotion: "neutral",
      animation: "idle",
      sound: "cute",
      eyeDirection: "center",
      speak: true,
      language: fallbackLang,
    };
  }

  return {
    reply: "Hmm, I got confused for a second. Say that again?",
    emotion: "confused",
    animation: "confused",
    sound: "error",
    eyeDirection: "center",
    speak: true,
    language: fallbackLang,
  };
}

function extractJsonObject(text) {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch (_) {
    return null;
  }
}

function unwrapReplyObject(obj, depth = 0) {
  if (!obj || typeof obj !== "object" || depth > 3) return null;
  if (typeof obj.reply === "string") {
    const reply = obj.reply.trim();
    if (reply.startsWith("{") && reply.includes('"reply"')) {
      const nested = extractJsonObject(reply);
      if (nested && typeof nested.reply === "string" && nested.reply.trim()) {
        return { ...obj, ...nested, reply: nested.reply.trim() };
      }
    }
    return { ...obj, reply };
  }

  for (const key of ["response", "result", "content", "message", "text"]) {
    const value = obj[key];
    if (typeof value === "string" && value.trim()) {
      const nested = extractJsonObject(value.trim());
      if (nested) {
        const unwrapped = unwrapReplyObject(nested, depth + 1);
        if (unwrapped) return unwrapped;
      }
      if (!value.trim().startsWith("{")) {
        return {
          reply: value.trim(),
          emotion: obj.emotion || "neutral",
          animation: obj.animation || "idle",
          sound: obj.sound || "cute",
          eyeDirection: obj.eyeDirection || "center",
          speak: obj.speak !== false,
          language: obj.language || "en-IN",
        };
      }
    }
    if (value && typeof value === "object") {
      const unwrapped = unwrapReplyObject(value, depth + 1);
      if (unwrapped) return unwrapped;
    }
  }
  return null;
}

function sanitizeResponse(input) {
  const emotion = EMOTIONS.has(input.emotion) ? input.emotion : "neutral";
  const animation = ANIMATIONS.has(input.animation) ? input.animation : "idle";
  const sound = SOUNDS.has(input.sound) ? input.sound : "cute";
  const eyeDirection = EYE_DIRS.has(input.eyeDirection) ? input.eyeDirection : "center";
  const language = typeof input.language === "string" && input.language.length <= 12
    ? input.language
    : "en-IN";
  const reply = cleanSpeakableReply(input.reply);
  return {
    reply,
    emotion,
    animation,
    sound,
    eyeDirection,
    speak: input.speak !== false,
    language,
  };
}

function normalizeForSpeech(text, maxSentences = 4) {
  let out = String(text || "").trim();
  if (!out) return "";

  out = out.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim();
  out = out.replace(/\*\*([^*]+)\*\*/g, "$1");
  out = out.replace(/\*([^*]+)\*/g, "$1");
  out = out.replace(/__([^_]+)__/g, "$1");
  out = out.replace(/_([^_]+)_/g, "$1");
  out = out.replace(/`([^`]+)`/g, "$1");
  out = out.replace(/\[([^\]]+)\]\([^)]+\)/g, "$1");
  out = out.replace(/https?:\/\/\S+/gi, "");
  out = out.replace(/^[-*•]\s+/gm, "");
  out = out.replace(/^\d+[.)]\s+/gm, "");
  out = out.replace(/[\u{1F300}-\u{1FAFF}]/gu, "");
  out = out.replace(/[\u{2600}-\u{27BF}]/gu, "");
  out = out.replace(/\n\s*\n+/g, ". ");
  out = out.replace(/\n+/g, ". ");
  out = out.replace(/;\s*/g, ". ");

  const latinHeavy = /[A-Za-z]/.test(out);
  if (latinHeavy) {
    out = out.replace(/,\s+(and|but|so|because|however|also|then|yet)\s+/gi, ". ");
  }

  out = out.replace(/\s*([,.!?])\s*/g, "$1 ");
  out = out.replace(/,{2,}/g, ",");
  out = out.replace(/\.{2,}/g, ".");
  out = out.replace(/\.\s*\./g, ".");
  out = out.replace(/,\s*\./g, ".");
  out = out.replace(/\s{2,}/g, " ");
  out = out.trim();

  const sentences = out
    .split(/(?<=[.!?])\s+/)
    .map((part) => part.trim())
    .filter(Boolean);

  if (sentences.length > maxSentences) {
    out = sentences.slice(0, maxSentences).join(" ");
  } else if (sentences.length > 0) {
    out = sentences.join(" ");
  }

  if (latinHeavy) {
    out = out.replace(/(^|[.!?]\s+)([a-z])/g, (match, prefix, letter) => `${prefix}${letter.toUpperCase()}`);
  }

  if (out && !/[.!?]$/.test(out)) {
    out = `${out}.`;
  }
  return out;
}

function cleanSpeakableReply(raw) {
  let text = String(raw || "").trim();
  if (!text) return "Hmm, I got confused for a second. Say that again?";
  if (text.startsWith("{") || text.startsWith("[")) {
    const nested = extractJsonObject(text);
    if (nested) {
      const unwrapped = unwrapReplyObject(nested);
      if (unwrapped?.reply) text = String(unwrapped.reply).trim();
    }
  }
  text = stripRobotFiller(text);
  text = normalizeForSpeech(text);
  if (!text || text.startsWith("{") || text.startsWith("[")) {
    return "Hmm, I got confused for a second. Say that again?";
  }
  return text.slice(0, 800);
}

function stripRobotFiller(text) {
  let out = String(text || "").trim();
  for (let i = 0; i < 4; i += 1) {
    const next = out
      .replace(
        /(?:\s*[.!…]?\s*)(?:\*+)?(?:beep(?:\s*boop)?|boop(?:\s*beep)?|whirr+|buzz+|bzz+|bleep|blorp)(?:\s*(?:beep|boop|whirr+|buzz+))*(?:\*+)?[.!…]*\s*$/i,
        ""
      )
      .replace(
        /\s*[(\[]\s*(?:happy|playful|cute|excited|caring|curious|shy|sad|angry|sleepy|thinking|neutral)\s*[)\]]\s*$/i,
        ""
      )
      .replace(/\s*(?:emotion|mood|sound)\s*[:=]\s*[a-z_-]+\s*$/i, "")
      .trim();
    if (next === out) break;
    out = next;
  }
  return out;
}

function needsWebSearch(message) {
  const m = message.toLowerCase();
  return [
    "weather", "news", "stock", "score", "match", "today", "latest",
    "current", "price", "ivala", "aaj", "repu", "temperature", "who won",
    "election", "release date",
  ].some((k) => m.includes(k));
}

async function runWebSearch(query, env) {
  const provider = (env.SEARCH_PROVIDER || "none").toLowerCase();
  if (provider === "none") {
    return "Search provider not configured. Be honest if current facts are needed.";
  }
  if (provider === "brave") {
    const key = env.BRAVE_API_KEY;
    if (!key) return "Brave API key missing. Could not retrieve current information.";
    try {
      const url = `https://api.search.brave.com/res/v1/web/search?q=${encodeURIComponent(query)}&count=5`;
      const res = await fetch(url, {
        headers: {
          Accept: "application/json",
          "X-Subscription-Token": key,
        },
      });
      if (!res.ok) return "Web search failed. Be honest that current info is unavailable.";
      const data = await res.json();
      const results = (data.web?.results || []).slice(0, 5).map((r, i) => {
        return `${i + 1}. ${r.title}: ${r.description || ""} (${r.url || ""})`;
      });
      return results.join("\n") || "No search results.";
    } catch (err) {
      console.error(err);
      return "Web search failed. Be honest that current info is unavailable.";
    }
  }
  return "Unknown search provider.";
}

async function handleTts(request, env) {
  const apiKey = env.CARTESIA_API_KEY;
  if (!apiKey) {
    return cors(json({ error: "Cartesia TTS is not configured" }, 503));
  }

  const rateLimit = Number(env.RATE_LIMIT_PER_MINUTE || 30);
  const contentType = request.headers.get("content-type") || "";
  if (!contentType.includes("application/json")) {
    return cors(json({ error: "Content-Type must be application/json" }, 415));
  }

  const raw = await request.text();
  if (raw.length > 20000) return cors(json({ error: "Request too large" }, 413));

  let body;
  try {
    body = JSON.parse(raw);
  } catch {
    return cors(json({ error: "Invalid JSON" }, 400));
  }

  const installationId = String(body.installationId || "").slice(0, 80);
  const text = stripForSpeech(String(body.text || "").trim());
  if (!installationId || !text) {
    return cors(json({ error: "installationId and text are required" }, 400));
  }
  if (text.length > 1200) return cors(json({ error: "Text too long" }, 400));
  if (!allowRequest(`${installationId}:tts`, rateLimit)) {
    return cors(json({ error: "Rate limit exceeded" }, 429));
  }

  const languageCode = String(body.language || env.CARTESIA_LANGUAGE || "en-IN");
  const gender = String(body.gender || body.voiceGender || "female").toLowerCase();
  const voiceId = pickCartesiaVoiceId(env, gender, body.voiceId);
  const modelId = env.CARTESIA_MODEL || "sonic-3.6";
  const speed = clampNumber(Number(body.speed ?? env.CARTESIA_SPEED ?? 0.95), 0.6, 1.5, 0.95);

  const cartesiaBody = {
    model_id: modelId,
    transcript: text,
    voice: { id: voiceId },
    output_format: {
      container: "wav",
      encoding: "pcm_s16le",
      sample_rate: 44100,
    },
    generation_config: { speed, volume: 1 },
  };

  if (languageCode.includes("-") || languageCode.includes("_")) {
    cartesiaBody.locale = languageCode.replace("_", "-");
  } else {
    cartesiaBody.language = languageCode.toLowerCase().slice(0, 2);
  }

  const cartesiaRes = await fetch("https://api.cartesia.ai/tts/bytes", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Cartesia-Version": env.CARTESIA_VERSION || "2026-08-14",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(cartesiaBody),
  });

  if (!cartesiaRes.ok) {
    const errText = await cartesiaRes.text();
    console.error("Cartesia TTS error", cartesiaRes.status, errText);
    return cors(json({ error: "Cartesia TTS request failed", status: cartesiaRes.status }, 502));
  }

  const audio = await cartesiaRes.arrayBuffer();
  return cors(new Response(audio, {
    status: 200,
    headers: {
      "Content-Type": "audio/wav",
      "Cache-Control": "no-store",
    },
  }));
}

function pickCartesiaVoiceId(env, gender, requestedVoiceId) {
  const explicit = String(requestedVoiceId || "").trim();
  if (explicit) return explicit;

  const maleId = String(env.CARTESIA_MALE_VOICE_ID || "").trim();
  const femaleId = String(
    env.CARTESIA_VOICE_ID || "f786b574-daa5-4673-aa0c-cbe3e8534c02"
  ).trim();

  if (gender === "male" && maleId) return maleId;
  return femaleId;
}

function stripForSpeech(text) {
  let cleaned = String(text || "").trim();
  if (cleaned.startsWith("{") || cleaned.startsWith("[")) {
    cleaned = cleanSpeakableReply(cleaned);
  }
  return normalizeForSpeech(cleaned);
}

function clampNumber(value, min, max, fallback) {
  if (!Number.isFinite(value)) return fallback;
  return Math.min(max, Math.max(min, value));
}

function allowRequest(installationId, limit) {
  const now = Date.now();
  const windowMs = 60000;
  const entry = rateLimitMap.get(installationId) || { count: 0, reset: now + windowMs };
  if (now > entry.reset) {
    entry.count = 0;
    entry.reset = now + windowMs;
  }
  entry.count += 1;
  rateLimitMap.set(installationId, entry);
  if (rateLimitMap.size > 5000) {
    for (const [key, value] of rateLimitMap) {
      if (now > value.reset) rateLimitMap.delete(key);
    }
  }
  return entry.count <= limit;
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function cors(response) {
  const headers = new Headers(response.headers);
  headers.set("Access-Control-Allow-Origin", "*");
  headers.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  return new Response(response.body, { status: response.status, headers });
}
