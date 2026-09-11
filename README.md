# ai-companion

A friendly, full-stack **AI Companion** chat app. It runs fully end-to-end with **no external
services or API keys** thanks to a built-in offline response engine, and transparently upgrades to
LLM-backed replies when an `OPENAI_API_KEY` is provided.

## Features

- Warm, context-aware chat companion
- Offline engine with lightweight heuristics: mood detection, name memory, empathetic replies
- Optional OpenAI integration (`OPENAI_API_KEY`), with automatic fallback to the offline engine
- Modern, responsive React chat UI

## Project structure

| Path | Description |
| --- | --- |
| `server/` | Express + TypeScript API (`GET /api/health`, `POST /api/chat`) and the companion engine |
| `client/` | Vite + React + TypeScript chat UI |
| `.cursor/environment.json` | Cloud Agent development environment configuration |

## Getting started

Requires Node.js 20+.

```bash
npm install
npm run dev
```

- Client: http://localhost:5173
- API: http://localhost:3001

`npm run dev` starts both the API server and the Vite client together. The Vite dev server proxies
`/api` requests to the API server.

### Optional: enable LLM replies

Copy `.env.example` to `.env` and set `OPENAI_API_KEY`. Without it, the app uses the offline engine.

## Scripts

| Command | Description |
| --- | --- |
| `npm run dev` | Run API + client dev servers together |
| `npm run build` | Type-check and build the server and client |
| `npm run start` | Run the built API server |
| `npm run lint` | Lint server and client |
| `npm run typecheck` | Type-check server and client |
| `npm test` | Run the companion engine unit tests |

## API

`POST /api/chat`

```json
{ "message": "Hi, my name is Sam", "history": [] }
```

Response:

```json
{
  "reply": "It's lovely to meet you, Sam! I'll remember that. What's on your mind today?",
  "mood": "neutral",
  "userName": "Sam",
  "source": "offline"
}
```
