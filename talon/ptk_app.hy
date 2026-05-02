"
Prompt-toolkit application for talon.

A minimal terminal UI for chatting with OpenClaw via the OpenResponses API.
"

(import asyncio)
(import shutil)

(import prompt-toolkit [ANSI])
(import prompt-toolkit.application [Application get-app-or-none])
(import prompt_toolkit.layout [WindowAlign])
(import prompt_toolkit.layout.dimension [Dimension])
(import prompt-toolkit.document [Document])
(import prompt-toolkit.key-binding [KeyBindings])
(import prompt_toolkit.key_binding.bindings.page_navigation [scroll_page_up scroll_page_down])
(import prompt-toolkit.layout.containers [HSplit VSplit Window])
(import prompt-toolkit.layout.layout [Layout])
(import prompt-toolkit.widgets [Label TextArea])

(import prompt-toolkit.styles.pygments [style-from-pygments-cls])
(import prompt-toolkit.lexers [PygmentsLexer])
(import pygments.lexers [MarkdownLexer])
(import pygments.styles [get-style-by-name])

(import talon [state])


;; * helpers
;; -----------------------------------------------------------------------------

(defn sync-await [coro]
  "Run an async coroutine from synchronous code."
  (let [loop (asyncio.get-event-loop)]
    (if (.is-running loop)
      (asyncio.run-coroutine-threadsafe coro loop)
      (.run-until-complete loop coro))))


;; * handlers
;; -----------------------------------------------------------------------------

(defn quit []
  "Gracefully quit - cancel all tasks."
  (state.save-history)
  (for [t (asyncio.all_tasks)]
    :if (not (is t (asyncio.current-task)))
    (t.cancel)))


(defn accept-handler [buffer]
  "Handle input submission."
  (when buffer.text
    (let [text (.strip buffer.text)]
      (cond
        ;; Command: /agent with value
        (.startswith text "/agent ")
        (do
          (setv buffer.text "")
          (let [agent (.strip (cut text 7 None))]
            (setv state.agent agent)
            (status-text f"Agent: {agent}")
            (title-text)))

        ;; Command: /agent (no args) — show current
        (= text "/agent")
        (do
          (setv buffer.text "")
          (status-text f"Current agent: {state.agent}"))

        ;; Command: /session with value
        (.startswith text "/session ")
        (do
          (setv buffer.text "")
          (let [session (.strip (cut text 9 None))]
            (setv state.session session)
            (status-text f"Session: {session}")
            (title-text)))

        ;; Command: /session (no args) — show current
        (= text "/session")
        (do
          (setv buffer.text "")
          (status-text f"Current session: {state.session}"))

        ;; Command: /model with value
        (.startswith text "/model ")
        (do
          (setv buffer.text "")
          (let [model (.strip (cut text 7 None))]
            (setv state.model model)
            (status-text f"Model: {model}")
            (title-text)))

        ;; Command: /model (no args) — show current
        (= text "/model")
        (do
          (setv buffer.text "")
          (let [m (or state.model "(default)")]
            (status-text f"Current model: {m}")))

        ;; Command: /url
        (.startswith text "/url ")
        (do
          (setv buffer.text "")
          (let [url (.strip (cut text 5 None))]
            (setv state.gateway-url url)
            (status-text f"Gateway: {url}")
            (title-text)))

        ;; Command: /file — attach a file
        (.startswith text "/file ")
        (do
          (setv buffer.text "")
          (let [path (.strip (cut text 6 None))]
            (sync-await (.put state.input-queue
                            {"type" "file"
                             "path" path}))))

        ;; Command: /clear
        (= text "/clear")
        (do
          (setv buffer.text "")
          (output-clear))

        ;; Command: /new — reset conversation
        (= text "/new")
        (do
          (setv buffer.text "")
          (setv state.messages [])
          (output-clear)
          (status-text "New conversation")
          (title-text))

        ;; Command: /quit or /exit
        (in text ["/quit" "/exit"])
        (do
          (setv buffer.text "")
          (quit))

        ;; Regular chat message
        :else
        (do
          (setv buffer.text "")
          (sync-await (.put state.input-queue
                           {"type" "chat"
                            "content" text}))))))
  None)


;; * text fields and app
;; -----------------------------------------------------------------------------

(setv kb (KeyBindings))

(setv status-field (Label :text "" :align WindowAlign.RIGHT :style "class:reverse"))
(setv title-field (Label :text "" :align WindowAlign.LEFT :style "class:reverse"))
(setv output-field (TextArea :text ""
                             :wrap-lines True
                             :lexer (PygmentsLexer MarkdownLexer)
                             :read-only True))
(defn input-prompt [n wrap-count]
  "Return the prompt prefix for the input line.
  
  prompt-toolkit passes (line_number, wrap_count)."
  "❯ ")

(setv input-field (TextArea :multiline False
                            :height (Dimension :min 1 :max 3)
                            :wrap-lines True
                            :get-line-prefix input-prompt
                            :accept-handler accept-handler))
;; Custom attribute for tracking multiline mode
(setv input-field.multiline False)
;; Buffer multiline is a Condition reading our custom attribute
(import prompt-toolkit.filters [Condition])
(setv input-field.buffer.multiline (Condition (fn [] input-field.multiline)))


(defn invalidate []
  "Redraw the app."
  (let [app (get-app-or-none)]
    (when app
      (.invalidate app))))


;; * printing functions
;; -----------------------------------------------------------------------------

(defn title-text []
  "Show the title."
  (let [model-str (if state.model
                    f" · {state.model}"
                    "")]
    (setv title-field.text
          f"talon — {state.agent}{model-str} · {state.session} · {(len state.messages)} msgs ")
    (invalidate)))

(defn output-text [output]
  "Append output to output buffer."
  (let [new-text (+ output-field.text output)
        tabbed-text (.replace new-text "\t" "    ")]
    (setv output-field.document (Document :text tabbed-text :cursor-position (len tabbed-text))))
  (invalidate))

(defn output-clear []
  "Clear the output window."
  (setv output-field.text ""))

(defn status-text [text]
  "Set the status field text."
  (setv status-field.text (ANSI text))
  (invalidate))


;; * key bindings
;; -----------------------------------------------------------------------------

(defn [(kb.add "c-q")] _ [event]
  "Pressing Ctrl-q will exit."
  (event.app.exit)
  (quit))

(defn [(kb.add "c-c")] _ [event]
  "Pressing Ctrl-c will cancel the current generation."
  (state.cancel-event.set))

(defn [(kb.add "escape" "m" :filter input-field.buffer.multiline)] _ [event]
  "Pressing Alt-m toggles multi-line input off."
  (setv input-field.window.height (Dimension :min 1 :max 3))
  (setv input-field.multiline False))

(defn [(kb.add "escape" "m" :filter (Condition (fn [] (not input-field.multiline))))] _ [event]
  "Pressing Alt-m toggles multi-line input on."
  (let [term (.get-terminal-size shutil)]
    (setv input-field.window.height (Dimension (// term.lines 2)))
    (setv input-field.multiline True)))

(defn [(kb.add "home")] _ [event]
  "Scroll output to start."
  (setv output-field.document (Document :text output-field.text :cursor-position 0)))

(defn [(kb.add "end")] _ [event]
  "Scroll output to end."
  (setv output-field.document (Document :text output-field.text :cursor-position (len output-field.text))))

(defn [(kb.add "pageup")] _ [event]
  "Scroll output up."
  (event.app.layout.focus output-field)
  (scroll_page_up event))

(defn [(kb.add "pagedown")] _ [event]
  "Scroll output down."
  (event.app.layout.focus output-field)
  (scroll_page_down event))

(defn [(kb.add "tab")] _ [event]
  "Pressing Tab focuses the input field."
  (event.app.layout.focus input-field))


;; * app class
;; -----------------------------------------------------------------------------

(defclass REPLApp [Application]

  (defn __init__ [self]
    "Set up the full-screen application."
    (let [ptk-style (style-from-pygments-cls (get-style-by-name "friendly_grayscale"))
          padding (Window :width 2)]
      (setv container (HSplit [(VSplit [title-field status-field])
                               (VSplit [padding output-field padding])
                               input-field]))
      (title-text)
      (status-text "Ready")
      (.__init__ (super) :layout (Layout container :focused-element input-field)
                         :key-bindings kb
                         :mouse-support True
                         :full-screen True))))


;; * instantiate
;; -----------------------------------------------------------------------------

(setv app (REPLApp))
