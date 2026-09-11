import cors from 'cors';
import express from 'express';
import type { ChatMessage } from './companion.js';
import { generateOfflineReply } from './companion.js';
import { generateLlmReply } from './llm.js';

const app = express();
const PORT = Number(process.env.PORT ?? 3001);

app.use(cors());
app.use(express.json());

app.get('/api/health', (_req, res) => {
  res.json({
    status: 'ok',
    mode: process.env.OPENAI_API_KEY ? 'llm' : 'offline',
    time: new Date().toISOString(),
  });
});

app.post('/api/chat', async (req, res) => {
  const body = req.body as { message?: unknown; history?: unknown };
  const message = typeof body.message === 'string' ? body.message : '';
  const history = sanitizeHistory(body.history);

  if (!message.trim()) {
    return res.status(400).json({ error: 'A non-empty "message" field is required.' });
  }

  const llmReply = await generateLlmReply(message, history);
  const reply = llmReply ?? generateOfflineReply(message, history);
  return res.json(reply);
});

function sanitizeHistory(value: unknown): ChatMessage[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter(
      (item): item is ChatMessage =>
        !!item &&
        typeof item === 'object' &&
        (item.role === 'user' || item.role === 'companion') &&
        typeof item.content === 'string',
    )
    .map((item) => ({ role: item.role, content: item.content }));
}

app.listen(PORT, () => {
  const mode = process.env.OPENAI_API_KEY ? 'LLM (OpenAI)' : 'offline';
  console.log(`AI companion server listening on http://localhost:${PORT} [${mode} mode]`);
});
