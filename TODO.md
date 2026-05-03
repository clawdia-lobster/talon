# Talon — TODO

## Markdown Rendering: GFM Support

**Issue:** The output field uses `PygmentsLexer MarkdownLexer` for syntax highlighting, which colours markdown keywords but does not render markdown elements. Code blocks get Pygments treatment, but horizontal rules (`---`), tables, and other GFM features appear as raw text.

**Location:** `ptk_app.hy`, line ~135:

```hy
(setv output-field (TextArea :text ""
                             :wrap-lines True
                             :lexer (PygmentsLexer MarkdownLexer)
                             :read-only True))
```

**Root cause:** `PygmentsLexer` with `MarkdownLexer` is a syntax highlighter, not a renderer. It treats the output as plain text with markdown syntax coloring. No markdown-to-HTML conversion is happening.

**Proposed fix:** Replace the lexer-based approach with actual markdown rendering:

1. Convert markdown to HTML using a GFM-capable library (`markdown` with `fenced_code` + `tables` extensions, or `mistune` with GFM enabled).
2. Convert HTML to ANSI for terminal display (prompt_toolkit has HTML rendering capabilities, or use an HTML-to-ANSI converter).
3. Append the rendered ANSI text to the output buffer.

**Change points:**

- **`ptk_app.hy` ~line 135:** Remove `:lexer (PygmentsLexer MarkdownLexer)` from `output-field` (output will be pre-rendered ANSI, not raw markdown).
- **`ptk_app.hy` ~line 155 (`output-text` function):** Instead of appending raw markdown text:

  ```hy
  ;; Current:
  (setv new-text (+ output-field.text output))

  ;; Target:
  (import markdown)
  (setv html (markdown.markdown output :extensions ['fenced_code' 'tables']))
  (setv ansi (html-to-ansi html))  ;; HTML-to-ANSI converter needed
  (setv new-text (+ output-field.text ansi))
  ```

**Open questions:**

- Best HTML-to-ANSI converter? Options: prompt_toolkit's built-in HTML rendering, `html2text`, `rich` HTML renderer.
- Whether to render incrementally (per message) or batch-render the full output on update.
- Performance implications of markdown-to-HTML-to-ANSI pipeline on long conversations.

**Dependencies:** `markdown` library (with GFM extensions), HTML-to-ANSI converter.

---
*Written: 2026-05-02 by Nereus (test session)
Updated: 2026-05-03 — removed separator placement and streaming responses (solved)
Do not edit concurrently with the main Talon development session.*
