import type { ChatMessage, CompanionReply } from './companion.js';
import { detectMood, findKnownName } from './companion.js';

const SYSTEM_PROMPT =
  'You are a warm, supportive AI companion. Keep replies concise (1-3 sentences), ' +
  'empathetic, and conversational. Ask a gentle follow-up question when appropriate.';

/**
 * Attempts to generate a reply using OpenAI when OPENAI_API_KEY is configured.
 * Returns null when no key is set or the request fails, so the caller can fall
 * back to the offline engine.
 */
export async function generateLlmReply(
  message: string,
  history: ChatMessage[] = [],
): Promise<CompanionReply | null> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return null;

  const model = process.env.OPENAI_MODEL ?? 'gpt-4o-mini';
  const messages = [
    { role: 'system', content: SYSTEM_PROMPT },
    ...history.map((m) => ({
      role: m.role === 'companion' ? 'assistant' : 'user',
      content: m.content,
    })),
    { role: 'user', content: message },
  ];

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({ model, messages, temperature: 0.8, max_tokens: 200 }),
    });

    if (!response.ok) {
      console.warn(`LLM request failed with status ${response.status}; using offline engine.`);
      return null;
    }

    const data = (await response.json()) as {
      choices?: { message?: { content?: string } }[];
    };
    const reply = data.choices?.[0]?.message?.content?.trim();
    if (!reply) return null;

    return {
      reply,
      mood: detectMood(message),
      userName: findKnownName([...history, { role: 'user', content: message }]),
      source: 'llm',
    };
  } catch (error) {
    console.warn('LLM request errored; using offline engine.', error);
    return null;
  }
}
