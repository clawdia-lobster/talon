# Plan: Talon Markdown Rendering

## Status
Ready to implement. Waiting for Ati's manual style edits before starting.

## Branch
`feature/markdown-rendering` (to be created)

## Approach

1. **Replace output TextArea with FormattedTextControl Window**
   - `ptk_app.hy`: Change `output-field` from `TextArea` to `Window(content=FormattedTextControl(...))`
   - Update `output-text`, `output-clear` to work with FormattedTextControl
   - Add style definitions for markdown classes (`class:b`, `class:i`, `class:code`, `class:pre`, `class:hr`, etc.)

2. **Add markdown rendering pipeline**
   - New `render.hy` module:
     - `markdown` library with `fenced_code`, `tables` extensions → HTML
     - `pygments` for code block syntax highlighting (already used)
     - Return HTML string for prompt_toolkit's `HTML()`
   - Dependencies: add `markdown` to `pyproject.toml`

3. **Store rendered messages**
   - `state.hy`: Add `rendered-messages` list (parallel to `messages`)
   - Each entry: `{"role": "user"|"assistant", "html": HTML(...)}`

4. **Stream raw, render on complete**
   - `repl.hy` `handle-chat`:
     - Stream raw chunks to display (current behaviour) — user sees markdown source during generation
     - On completion: render full response to HTML, store in `rendered-messages`, rebuild display
   - `repl.hy` `main-loop` history replay:
     - Render all loaded messages to HTML, build display

5. **Rebuild display function**
   - `ptk_app.hy`: `rebuild-output` — concatenate all rendered messages with separators
   - Called after each message completes and on history load

## Key Design Decisions

- **No rich library** — use prompt_toolkit's native `HTML` + `FormattedTextControl`
- **HTML as intermediary** — `markdown` library produces predictable HTML, converted to prompt_toolkit style tuples
- **Incremental rendering** — only re-render the message that just completed, not all history
- **Raw during stream** — user sees markdown source while streaming, formatted result after completion

## Files to Touch

| File | Change |
|------|--------|
| `talon/render.hy` | **New** — markdown → HTML pipeline |
| `talon/ptk_app.hy` | Replace output TextArea with FormattedTextControl Window; add styles; rebuild function |
| `talon/repl.hy` | Render on complete; rebuild display; history load rendering |
| `talon/state.hy` | Add `rendered-messages` list |
| `pyproject.toml` | Add `markdown` dependency |
| `tests/native_tests/test_render.hy` | **New** — rendering tests |

## Acceptance Criteria (from SPEC.md)

- [ ] Code blocks render with Pygments syntax highlighting, no visible backticks
- [ ] Tables render with aligned columns and borders
- [ ] Horizontal rules display as visual separators
- [ ] Bold/italic text uses terminal formatting
- [ ] Lists render with proper indentation
- [ ] 4,000-token response renders in < 100ms
- [ ] Malformed markdown does not crash

## Notes

- Ati is making manual style edits before implementation starts
- Feature branch: `feature/markdown-rendering`
- Current base: `master` (after CLI mode + PgUp fixes)
