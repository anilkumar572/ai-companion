import { describe, expect, it } from 'vitest';
import {
  detectMood,
  extractName,
  findKnownName,
  generateOfflineReply,
  type ChatMessage,
} from './companion.js';

describe('extractName', () => {
  it('detects "my name is X"', () => {
    expect(extractName('Hi, my name is Sam')).toBe('Sam');
  });

  it('detects "I\'m X"', () => {
    expect(extractName("I'm Alex")).toBe('Alex');
  });

  it('detects "call me X"', () => {
    expect(extractName('You can call me Riley')).toBe('Riley');
  });

  it('ignores emotional statements like "I am tired"', () => {
    expect(extractName('I am tired')).toBeNull();
  });

  it('returns null when no name is present', () => {
    expect(extractName('What is the weather today?')).toBeNull();
  });
});

describe('detectMood', () => {
  it('flags negative sentiment', () => {
    expect(detectMood('I feel so sad and lonely')).toBe('negative');
  });

  it('flags positive sentiment', () => {
    expect(detectMood('I am so happy today')).toBe('positive');
  });

  it('flags questions as curious', () => {
    expect(detectMood('How does this work?')).toBe('curious');
  });

  it('defaults to neutral', () => {
    expect(detectMood('The meeting is at noon')).toBe('neutral');
  });

  it('prioritizes negative sentiment over a trailing question mark', () => {
    expect(detectMood('why am I so stressed?')).toBe('negative');
  });
});

describe('findKnownName', () => {
  it('finds the most recent name in history', () => {
    const history: ChatMessage[] = [
      { role: 'user', content: 'my name is Sam' },
      { role: 'companion', content: 'Nice to meet you Sam' },
      { role: 'user', content: 'actually call me Sammy' },
    ];
    expect(findKnownName(history)).toBe('Sammy');
  });

  it('returns null when no name was shared', () => {
    const history: ChatMessage[] = [{ role: 'user', content: 'hello there' }];
    expect(findKnownName(history)).toBeNull();
  });
});

describe('generateOfflineReply', () => {
  it('greets and remembers a newly shared name', () => {
    const result = generateOfflineReply('Hi, my name is Sam');
    expect(result.userName).toBe('Sam');
    expect(result.source).toBe('offline');
    expect(result.reply).toContain('Sam');
  });

  it('responds empathetically to negative sentiment', () => {
    const result = generateOfflineReply('I feel really stressed and tired');
    expect(result.mood).toBe('negative');
    expect(result.reply.toLowerCase()).toContain('sorry');
  });

  it('uses a known name from history in its reply', () => {
    const history: ChatMessage[] = [{ role: 'user', content: 'my name is Riley' }];
    const result = generateOfflineReply('I had a great day!', history);
    expect(result.userName).toBe('Riley');
    expect(result.reply).toContain('Riley');
    expect(result.mood).toBe('positive');
  });

  it('acknowledges gratitude', () => {
    const result = generateOfflineReply('thank you so much');
    expect(result.reply.toLowerCase()).toContain('welcome');
  });

  it('handles a farewell', () => {
    const result = generateOfflineReply('goodbye for now');
    expect(result.reply.toLowerCase()).toContain('take care');
  });
});
