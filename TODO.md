# Talon — TODO

## Render Tables Better

**Issue:** Tables from the assistant appear as raw markdown (`| col1 | col2 |`) in the output. The TextArea + PygmentsLexer setup colours markdown syntax but doesn't render tables as aligned columns.

**Current state:**
- Syntax highlighting works (PygmentsLexer)
- Bold/italic/lists/code blocks show as raw markdown (acceptable)
- Tables are the main readability issue

**Blocker:** No lightweight HTML→ANSI library with table support that integrates cleanly with prompt_toolkit's async streaming.

**Options explored:**
- `rich` — handles tables well, but async integration is painful
- `markdown` + custom HTML→ANSI — tables require significant custom code
- `html2text` — produces markdown, not terminal formatting

**Decision:** Keep current setup. Revisit if a better solution emerges.

---
*Written: 2026-05-03*
