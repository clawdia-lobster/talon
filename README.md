# talon

A minimal terminal client for OpenClaw's OpenResponses API.

Forked from [chatthy](https://github.com/atisharma/chatthy), stripped to essentials:
- No client/server architecture — connects directly to OpenClaw Gateway
- No personality/prompt system — uses OpenClaw agents
- No ZMQ transport — plain HTTP with SSE streaming
- No LaTeX rendering — clean markdown output

## Usage

```bash
talon
```

Type messages and press Enter. Use slash commands:

- `/agent NAME` — switch to a different OpenClaw agent
- `/session KEY` — set a session key for continuity
- `/url URL` — change the Gateway URL
- `/clear` — clear the output window
- `/quit` — exit

## Configuration

Create `~/.config/talon/client.toml`:

```toml
gateway-url = "http://localhost:18789"
token = "your-gateway-token"
agent = "main"
```

Or pass a `client.toml` in the working directory.

## Requirements

- Python >= 3.11
- Hy >= 1.0
- An OpenClaw Gateway running with the OpenResponses endpoint enabled
