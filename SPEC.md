# Specification: Talon CLI & Terminal Integration

Extend Talon from an interactive-only terminal client into a composable CLI tool that works both as a chat interface and as a pipeable command for shell scripting, automation, and terminal integration.

## Problem

### Context
Talon is a minimal terminal client for OpenClaw's OpenResponses API. It currently launches an interactive prompt_toolkit REPL where the user types messages and receives streaming responses. All interaction happens inside the TUI.

### Symptoms
- Talon cannot be used in shell scripts, Makefiles, or CI pipelines — there is no non-interactive mode.
- Common terminal workflows require leaving the chat: reviewing a diff, summarising a file, asking a quick question from the shell prompt, or piping output through the model.
- Users must open a separate Talon session for each distinct task (code review, research question, file summary), rather than asking from wherever they happen to be in the terminal.
- No way to capture model output programmatically (no JSON mode, no structured output).

### Impact
Talon remains a nice-to-have chat window rather than a first-class terminal tool. It cannot integrate into existing workflows — git hooks, editor pipelines, shell aliases, or automation scripts. This severely limits its utility as a daily driver.

### Current Workaround
Users can:
- Use `curl` against the Gateway API directly (cumbersome, no streaming, no session management).
- Open a separate Talon window for each query (context-switching cost).
- Use other OpenClaw clients (web UI, rosa-desktop) for non-terminal workflows.

None of these provide a seamless "ask the model from the shell" experience.

### Success Criteria
- Users can ask the model a question from any shell prompt and get a response without leaving their workflow.
- Talon output can be piped, captured, or composed with other CLI tools.
- Interactive mode remains the default and primary UX; non-interactive modes are opt-in.
- Session continuity works across interactive and non-interactive invocations.

## Solution

### Approach
Add non-interactive operating modes to the existing Talon binary, gated behind CLI flags. The core API client, session management, and streaming infrastructure are shared; only the input/output layer changes. Interactive mode remains the default (no flags = REPL).

### Key Concepts

- **Interactive mode** — the existing prompt_toolkit REPL. Default when no flags are given.
- **Command mode** (`-c` / `--command`) — take a single message string from the CLI, send it, print the response, exit.
- **Stdin mode** (`-` / `--stdin`) — read the message from standard input, send it, print the response, exit.
- **Pipe mode** — a combination of stdin mode and output formatting, designed for use in shell pipelines.
- **Session pinning** — non-interactive invocations can attach to a named session so conversation history persists across calls.

### Mental Model

Talon is a Swiss-army knife: run it bare for a chat window, flag it for a one-shot query, pipe it into workflows. The same session, agent, and model configuration applies across all modes.

### Boundaries

**In scope:**
- Non-interactive command mode (`talon -c "what is X?"`)
- Stdin mode (`echo "text" | talon` / `talon < file.txt`)
- Structured output (`--json` for machine-readable responses)
- Session pinning from CLI (`--session my-project`)
- Quiet mode (`--quiet` — suppress streaming, print only final response)
- Agent/model override from CLI (`--agent`, `--model`)

**Out of scope:**
- GUI or desktop integration (rosa-desktop covers this)
- Multi-turn conversation in non-interactive mode (one request, one response, exit)
- File attachment from CLI (use stdin or reference paths in the message)
- Plugin system or extensible command registry
- Background/daemon mode

### Alternatives Considered

1. **Separate binary** (e.g. `talon-query` for non-interactive)
   - Rejected: duplicates code, splits configuration, adds maintenance burden. One binary with flags is simpler.

2. **Environment variable mode switch** (e.g. `TALON_MODE=cli`)
   - Rejected: flags are more discoverable, composable, and standard for CLI tools.

3. **Full REPL with heredoc** (`talon << EOF ... EOF`)
   - Considered as a natural consequence of stdin mode, not a separate feature.

## Contract

### Interface

```
talon [OPTIONS]

Mode selection (mutually exclusive; default = interactive):
  -c, --command MSG     Send MSG as a single message and exit
  --stdin               Read message from stdin, send, and exit

Output formatting:
  --json                Output response as JSON (message field only)
  --quiet               Suppress streaming; print only final response text

Session:
  --session KEY         Pin to a named session key (persists across invocations)

Agent/Model override:
  --agent NAME          Override the agent (default: from config)
  --model PROVIDER/MODEL  Override the model (default: from config)

Connection:
  --url URL             Override the Gateway URL (default: from config)
  --token TOKEN         Override the auth token (default: from config)

Interactive-only (ignored in non-interactive modes):
  --no-stream           Disable streaming in interactive mode (wait for full response)

General:
  --help                Show help
  --version             Show version
```

### Behaviour

- **Default (no flags):** Launch interactive REPL (current behaviour, unchanged).
- **`-c "message"`:** Send one message, stream or print response, exit with code 0 on success, 1 on error.
- **`--stdin`:** Read all of stdin as the message. Exit after response completes.
- **`-c` and `--stdin` are mutually exclusive.** If both given, error with usage message.
- **`--json`:** Output a JSON object: `{"text": "<response>", "session": "<key>"}`. No ANSI, no streaming.
- **`--quiet`:** Do not stream tokens to stdout. Wait for response completion, then print the full text. Useful in pipelines where partial output corrupts the pipe.
- **`--session KEY`:** Use the given session key for the request. Response history persists for subsequent invocations with the same key.
- **Without `--session`:** Non-interactive mode uses an ephemeral session (no continuity).
- **Exit codes:** 0 = success, 1 = error (network, auth, API error). Error messages go to stderr.

### Constraints

- Non-interactive modes MUST complete and exit after the response finishes.
- Non-interactive modes MUST NOT launch the prompt_toolkit event loop.
- `--json` output MUST be valid JSON parseable by `jq`.
- `--quiet` MUST buffer the full response before printing (no partial output on stdout).
- Interactive mode MUST remain unchanged — no flags alter the REPL behaviour except `--no-stream`.
- Configuration file resolution (client.toml) MUST work identically across all modes.

### Errors

| Condition | Behaviour |
|-----------|-----------|
| Both `-c` and `--stdin` given | Print usage to stderr, exit 1 |
| `-c` with empty message | Print error to stderr, exit 1 |
| `--stdin` with empty input | Print error to stderr, exit 1 |
| Gateway unreachable | Print error to stderr, exit 1 |
| Auth failure | Print error to stderr, exit 1 |
| API error (non-200) | Print error body to stderr, exit 1 |
| `--json` with streaming enabled | Streaming disabled implicitly; full response returned as JSON |

## Verification

### Examples

**Quick query from shell:**
```bash
$ talon -c "What files are in the current directory?"
I can see you're in a project directory. Let me check...
```

**Pipe a file through:**
```bash
$ talon -c "Summarise this:" < README.md
Talon is a minimal terminal client for OpenClaw's OpenResponses API...
```

**Structured output for scripting:**
```bash
$ talon -c "What is 2+2?" --json --quiet
{"text": "2 + 2 = 4", "session": "ephemeral-abc123"}
```

**Continuation across calls:**
```bash
$ talon -c "Remember: the project uses Hy and prompt_toolkit" --session my-project
Noted.
$ talon -c "What language does the project use?" --session my-project
The project uses Hy (a Lisp dialect compiled to Python) with prompt_toolkit for the TUI.
```

**In a pipeline:**
```bash
$ git diff --cached | talon --stdin --quiet "Review this diff:"
The changes look good. One suggestion: consider extracting the...
```

**With jq:**
```bash
$ talon -c "List Python files" --json --quiet | jq -r '.text'
I found the following Python files...
```

### Acceptance Criteria

- [ ] `talon -c "hello"` sends a message, prints the response, and exits with code 0
- [ ] `echo "hello" | talon --stdin` reads from stdin, sends, prints response, exits 0
- [ ] `talon -c "x" --json --quiet` outputs valid JSON parseable by `jq`
- [ ] `talon -c "x" --session foo` followed by `talon -c "y" --session foo` maintains conversation continuity
- [ ] `talon` with no flags launches the interactive REPL (unchanged behaviour)
- [ ] `talon -c ""` exits with code 1 and prints an error to stderr
- [ ] `talon -c "x" --stdin` exits with code 1 (mutually exclusive modes)
- [ ] Network errors in non-interactive mode print to stderr and exit 1
- [ ] `--quiet` produces no partial output on stdout (full response only)
- [ ] Configuration from `client.toml` is respected in all modes

---

*Version: 1.0 | Updated: 2026-05-03*
