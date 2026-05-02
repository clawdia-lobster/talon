# talon

A minimal terminal client for OpenClaw's OpenResponses API.

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
| `/model PROVIDER/MODEL` | Override the backend model for this agent |
| `/session KEY` | Set a session key for continuity |
| `/url URL` | Change the Gateway URL |
| `/file PATH` | Attach a file to the next message |
| `/clear` | Clear the output window |
| `/new` | Reset the conversation (keeps config) |
| `/quit` or `/exit` | Exit the client |

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+Q` | Exit |
| `Ctrl+C` | Cancel current generation |
| `Alt+M` | Toggle multi-line input |
| `Home` | Scroll output to start |
| `End` | Scroll output to end |
| `Page Up` / `Page Down` | Scroll output by page |

## Configuration

Create `$XDG_CONFIG_HOME/talon/client.toml` (falls back to `~/.config/talon/client.toml`):

```toml
gateway-url = "http://localhost:18789"
token = "your-gateway-token"
agent = "main"

# Session key for continuity across restarts.
# If unset, talon generates a deterministic session from your username and agent.
# session = "my-session"

# SSL settings for self-signed certificates or reverse proxies.
# ssl-verify = true           # Set to false to disable certificate verification
# ssl-cert = "/path/to/ca.crt"  # Path to custom CA certificate
```

Or pass a `client.toml` in the working directory.

## State

Conversation history is automatically saved to `$XDG_STATE_HOME/talon/` (falls back to `~/.local/state/talon/`) and restored on restart.

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
