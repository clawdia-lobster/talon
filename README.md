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

Type messages and press Enter. The client streams responses from the Gateway in real-time.

## Commands

Type these in the input field:

| Command | Description |
|---------|-------------|
| `/agent NAME` | Switch to a different OpenClaw agent |
| `/session KEY` | Set a session key for continuity |
| `/url URL` | Change the Gateway URL |
| `/clear` | Clear the output window |
| `/quit` or `/exit` | Exit the client |

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+Q` | Exit |
| `Shift+Tab` | Toggle focus between input and output |
| `Home` | Scroll output to start |
| `End` | Scroll output to end |
| `Page Up` / `Page Down` | Scroll output |

## Configuration

Create `~/.config/talon/client.toml`:

```toml
gateway-url = "http://localhost:18789"
token = "your-gateway-token"
agent = "main"

# Session key for continuity across restarts.
# If unset, the Gateway creates a new session per run.
# session = "my-session"

# SSL settings for self-signed certificates or reverse proxies.
# ssl-verify = true           # Set to false to disable certificate verification
# ssl-cert = "/path/to/ca.crt"  # Path to custom CA certificate
```

Or pass a `client.toml` in the working directory.

## Requirements

- Python >= 3.11
- Hy >= 1.0
- An OpenClaw Gateway running with the OpenResponses endpoint enabled

## Install

```bash
pip install git+https://github.com/clawdia-lobster/talon.git
```

Or clone and install in development mode:

```bash
git clone https://github.com/clawdia-lobster/talon.git
cd talon
pip install -e .
```
