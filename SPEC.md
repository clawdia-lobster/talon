# Specification: Talon Markdown Rendering

Replace the syntax-highlighting-only output field with proper GitHub-Flavoured Markdown (GFM) rendering in the terminal, so code blocks, tables, horizontal rules, and other markdown elements display correctly instead of as raw text.

## Problem

### Context
Talon is a terminal chat client for OpenClaw. The assistant returns markdown-formatted responses — code blocks with language tags, tables, horizontal rules, bold/italic text, and lists. These are displayed in a prompt_toolkit `TextArea` with a `PygmentsLexer MarkdownLexer` for syntax highlighting.

### Symptoms
- Code blocks show raw backticks and language tags instead of formatted code
- Tables display as pipe-separated text with no alignment
- Horizontal rules (`---`) appear as literal dashes
- Bold/italic markers (`**text**`, `_text_`) remain visible
- The output is syntax-highlighted markdown source, not rendered markdown

### Impact
Responses are harder to read than they should be. Code blocks — the most common structured output from LLMs — are particularly poor: the user sees `` ```python `` and closing backticks instead of just the code with appropriate colouring. This undermines talon's utility as a daily-driver terminal client.

### Current Workaround
Users mentally parse the markdown syntax. There is no rendering step.

### Success Criteria
- Code blocks render with language-appropriate syntax highlighting and no visible backticks
- Tables render with aligned columns and borders
- Horizontal rules display as visual separators
- Bold/italic text displays with terminal formatting (bold/underline attributes)
- Lists render with proper indentation and bullets
- Performance remains acceptable for conversations up to 10,000 tokens

## Solution

### Approach
Pre-render markdown to ANSI escape sequences before appending to the output buffer. The output field becomes a plain text area (no lexer) that receives already-formatted ANSI content. Rendering happens per-message at append time.

### Key Concepts

- **Markdown-to-HTML**: Convert GFM markdown to HTML using a standard library (`markdown` with extensions, or `mistune`).
- **HTML-to-ANSI**: Convert HTML to terminal-ready ANSI escape sequences. Handles `<strong>`, `<em>`, `<code>`, `<pre>`, `<table>`, `<hr>`, and nested structures.
- **ANSI TextArea**: prompt_toolkit's `TextArea` with `ANSI` content class, or manual ANSI parsing into styled text fragments.

### Mental Model
Think of talon's output as a terminal pager that receives pre-rendered content. Markdown comes in, formatted text comes out. The rendering pipeline is invisible to the user.

### Boundaries

**In scope:**
- GFM markdown rendering in the output field
- Code block syntax highlighting via Pygments (reused from current lexer)
- Table rendering with column alignment
- Horizontal rule, list, bold, italic, link rendering
- Incremental rendering (per message, not full re-render)

**Out of scope:**
- Image rendering (terminal limitation)
- Math/LaTeX rendering
- Interactive widgets inside markdown
- HTML sanitisation (input is trusted, from the Gateway)
- Markdown editing or WYSIWYG mode

### Alternatives Considered

1. **Full terminal UI framework** (e.g. `rich` console)
   - Rejected: Would replace prompt_toolkit entirely. Too invasive.

2. **Markdown-to-plaintext** (strip formatting)
   - Rejected: Loses the structure that makes markdown useful. Worse than current state.

3. **Browser-based rendering** (embedded web view)
   - Rejected: Violates "terminal client" constraint. Adds heavy dependencies.

4. **Custom markdown parser**
   - Rejected: `markdown` + `mistune` are mature and well-tested. Reinventing is error-prone.

## Contract

### Interface

```
render-markdown [text] -> str
  Convert markdown TEXT to ANSI escape sequences.
  Returns a string with embedded ANSI codes.

output-text [text]
  Append TEXT to the output field. If TEXT contains markdown,
  it is rendered to ANSI before appending.
```

### Constraints

- `render-markdown` MUST handle code blocks with language tags and apply Pygments highlighting.
- `render-markdown` MUST render tables with aligned columns.
- `render-markdown` MUST convert horizontal rules to visual separators (e.g. `─` repeated).
- `render-markdown` SHOULD preserve nested markdown structures (lists inside blockquotes, etc.).
- `output-text` MUST NOT re-render previously appended content (incremental only).
- The rendering pipeline MUST complete in < 100ms for a 4,000-token response.

### Errors

| Condition | Behaviour |
|-----------|-----------|
| Malformed markdown | Render as plain text (no crash) |
| Unknown code block language | Render as plain text (no Pygments highlighting) |
| Missing HTML-to-ANSI dependency | Graceful fallback to plain text |
| Table too wide for terminal | Wrap or truncate columns, never crash |

## Verification

### Examples

**Code block:**
```markdown
```python
def hello():
    return "world"
```
```
Renders as:
```
def hello():          ← coloured via Pygments
    return "world"
```
(No visible backticks or `python` tag.)

**Table:**
```markdown
| Name  | Value |
|-------|-------|
| Alice | 42    |
| Bob   | 99    |
```
Renders as aligned columns with borders.

**Horizontal rule:**
```markdown
---
```
Renders as `────────────────────────` across the terminal width.

### Acceptance Criteria

- [ ] A code block with `python` tag renders with Pygments syntax highlighting and no visible backticks
- [ ] A table renders with aligned columns and border characters
- [ ] A horizontal rule renders as a line of box-drawing characters
- [ ] Bold text renders with terminal bold attribute (`**text**` → `text` in bold)
- [ ] Italic text renders with terminal underline attribute (`_text_` → `text` underlined)
- [ ] A nested list renders with proper indentation
- [ ] A 4,000-token markdown response renders in < 100ms
- [ ] Malformed markdown does not crash the renderer

---

*Version: 1.0 | Updated: 2026-05-03*
