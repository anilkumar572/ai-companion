import { useEffect, useRef, useState } from 'react';

type Role = 'user' | 'companion';

interface ChatMessage {
  role: Role;
  content: string;
}

interface CompanionReply {
  reply: string;
  mood: 'positive' | 'negative' | 'curious' | 'neutral';
  userName: string | null;
  source: 'llm' | 'offline';
}

const MOOD_EMOJI: Record<CompanionReply['mood'], string> = {
  positive: '😊',
  negative: '💙',
  curious: '🤔',
  neutral: '🙂',
};

const WELCOME: ChatMessage = {
  role: 'companion',
  content: "Hi! I'm your AI companion. Tell me your name, or just say what's on your mind.",
};

export default function App() {
  const [messages, setMessages] = useState<ChatMessage[]>([WELCOME]);
  const [input, setInput] = useState('');
  const [isSending, setIsSending] = useState(false);
  const [mode, setMode] = useState<'llm' | 'offline' | 'unknown'>('unknown');
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    fetch('/api/health')
      .then((r) => r.json())
      .then((data: { mode?: 'llm' | 'offline' }) => setMode(data.mode ?? 'unknown'))
      .catch(() => setMode('unknown'));
  }, []);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' });
  }, [messages, isSending]);

  async function sendMessage() {
    const text = input.trim();
    if (!text || isSending) return;

    const history = messages.filter((m) => m !== WELCOME);
    const nextMessages = [...messages, { role: 'user', content: text } as ChatMessage];
    setMessages(nextMessages);
    setInput('');
    setIsSending(true);

    try {
      const res = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: text, history }),
      });
      const data = (await res.json()) as CompanionReply;
      setMessages((prev) => [...prev, { role: 'companion', content: data.reply }]);
      if (data.source) setMode(data.source);
    } catch {
      setMessages((prev) => [
        ...prev,
        { role: 'companion', content: 'Sorry, I had trouble reaching the server. Please try again.' },
      ]);
    } finally {
      setIsSending(false);
    }
  }

  function onKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      void sendMessage();
    }
  }

  return (
    <div className="app">
      <div className="chat">
        <header className="chat__header">
          <div className="chat__avatar" aria-hidden>
            ✨
          </div>
          <div className="chat__title">
            <h1>AI Companion</h1>
            <span className={`chat__mode chat__mode--${mode}`}>
              {mode === 'llm' ? 'LLM connected' : mode === 'offline' ? 'Offline engine' : 'Connecting…'}
            </span>
          </div>
        </header>

        <div className="chat__messages" ref={scrollRef}>
          {messages.map((m, i) => (
            <div key={i} className={`bubble bubble--${m.role}`}>
              {m.content}
            </div>
          ))}
          {isSending && (
            <div className="bubble bubble--companion bubble--typing">
              <span />
              <span />
              <span />
            </div>
          )}
        </div>

        <div className="chat__composer">
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={onKeyDown}
            placeholder="Type a message…"
            rows={1}
            aria-label="Message"
          />
          <button onClick={() => void sendMessage()} disabled={!input.trim() || isSending}>
            Send
          </button>
        </div>
        <p className="chat__hint">
          {MOOD_EMOJI.positive} Tries to read your mood · {MOOD_EMOJI.curious} answers questions ·
          remembers your name
        </p>
      </div>
    </div>
  );
}
