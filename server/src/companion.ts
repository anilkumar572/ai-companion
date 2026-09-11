export type Role = 'user' | 'companion';

export interface ChatMessage {
  role: Role;
  content: string;
}

export interface CompanionReply {
  /** The companion's text response. */
  reply: string;
  /** A coarse read on the user's emotional tone. */
  mood: Mood;
  /** The user's name if the companion has learned it from the conversation. */
  userName: string | null;
  /** Whether an external LLM produced this reply (vs. the offline engine). */
  source: 'llm' | 'offline';
}

export type Mood = 'positive' | 'negative' | 'curious' | 'neutral';

const POSITIVE_WORDS = [
  'happy',
  'great',
  'good',
  'awesome',
  'love',
  'excited',
  'glad',
  'wonderful',
  'amazing',
  'fantastic',
  'thanks',
  'thank you',
];

const NEGATIVE_WORDS = [
  'sad',
  'tired',
  'angry',
  'upset',
  'stressed',
  'anxious',
  'worried',
  'lonely',
  'bad',
  'terrible',
  'hate',
  'depressed',
  'frustrated',
];

const GREETINGS = ['hi', 'hello', 'hey', 'yo', 'howdy', 'greetings'];
const FAREWELLS = ['bye', 'goodbye', 'see you', 'good night', 'goodnight', 'later'];

function normalize(text: string): string {
  return text.toLowerCase().trim();
}

function containsAny(text: string, words: string[]): boolean {
  return words.some((w) => new RegExp(`\\b${escapeRegExp(w)}\\b`).test(text));
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** Detects a name introduction such as "my name is Sam" or "I'm Sam". */
export function extractName(text: string): string | null {
  const patterns = [
    /\bmy name is\s+([a-z][a-z'-]*)/i,
    /\bi am\s+([a-z][a-z'-]*)/i,
    /\bi'm\s+([a-z][a-z'-]*)/i,
    /\bcall me\s+([a-z][a-z'-]*)/i,
  ];
  const stopWords = new Set([
    'not',
    'so',
    'very',
    'really',
    'feeling',
    'happy',
    'sad',
    'tired',
    'good',
    'fine',
    'ok',
    'okay',
    'here',
    'sorry',
    'a',
    'an',
    'the',
  ]);
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match) {
      const candidate = match[1];
      if (!stopWords.has(candidate.toLowerCase())) {
        return capitalize(candidate);
      }
    }
  }
  return null;
}

function capitalize(word: string): string {
  return word.charAt(0).toUpperCase() + word.slice(1);
}

export function detectMood(text: string): Mood {
  const normalized = normalize(text);
  const isQuestion = normalized.includes('?');
  if (containsAny(normalized, NEGATIVE_WORDS)) return 'negative';
  if (containsAny(normalized, POSITIVE_WORDS)) return 'positive';
  if (isQuestion) return 'curious';
  return 'neutral';
}

/** Finds the most recent name the user shared across the whole conversation. */
export function findKnownName(history: ChatMessage[]): string | null {
  for (let i = history.length - 1; i >= 0; i--) {
    if (history[i].role === 'user') {
      const name = extractName(history[i].content);
      if (name) return name;
    }
  }
  return null;
}

/**
 * The offline companion engine. Produces a warm, context-aware response using
 * lightweight heuristics so the app is fully functional without any API keys.
 */
export function generateOfflineReply(
  message: string,
  history: ChatMessage[] = [],
): CompanionReply {
  const normalized = normalize(message);
  const nameFromThisMessage = extractName(message);
  const userName = nameFromThisMessage ?? findKnownName(history);
  const mood = detectMood(message);
  const addressed = userName ? `, ${userName}` : '';

  let reply: string;

  if (nameFromThisMessage) {
    reply = `It's lovely to meet you, ${nameFromThisMessage}! I'll remember that. What's on your mind today?`;
  } else if (containsAny(normalized, GREETINGS) && normalized.length <= 25) {
    reply = `Hi there${addressed}! I'm your AI companion. How are you feeling right now?`;
  } else if (containsAny(normalized, FAREWELLS)) {
    reply = `Take care${addressed}. I'm here whenever you'd like to talk again.`;
  } else if (containsAny(normalized, ['thank', 'thanks'])) {
    reply = `You're very welcome${addressed}. I'm always happy to help.`;
  } else if (mood === 'negative') {
    reply = `I'm sorry you're feeling this way${addressed}. That sounds hard. Do you want to tell me more about what's going on?`;
  } else if (mood === 'positive') {
    reply = `That's wonderful to hear${addressed}! What made it feel that way?`;
  } else if (mood === 'curious') {
    reply = `That's a great question${addressed}. Here's how I see it: I don't have all the answers, but I'm glad to think it through with you. What's prompting it?`;
  } else if (normalized.length === 0) {
    reply = `I'm listening${addressed}. Feel free to share whatever is on your mind.`;
  } else {
    reply = `Thanks for sharing that${addressed}. Tell me more — what feels most important about it to you?`;
  }

  return { reply, mood, userName, source: 'offline' };
}
