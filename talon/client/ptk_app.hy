"
Prompt-toolkit application for chatclaw.

A minimal terminal UI for chatting with OpenClaw via the OpenResponses API.
"

(import asyncio)

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

(import talon.client [state])


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
  (for [t (asyncio.all_tasks)]
    :if (not (is t (asyncio.current-task)))
    (t.cancel)))


(defn accept-handler [buffer]
  "Handle input submission."
  (when buffer.text
    (let [text (.strip buffer.text)]
      (cond
        ;; Command: /agent
        (.startswith text "/agent ")
        (let [agent (.strip (cut text 7 None))]
          (setv state.agent agent)
          (status-text f"Agent set to: {agent}")
          (title-text))
        
        ;; Command: /session
        (.startswith text "/session ")
        (let [session (.strip (cut text 9 None))]
          (setv state.session session)
          (status-text f"Session set to: {session}")
          (title-text))
        
        ;; Command: /url
        (.startswith text "/url ")
        (let [url (.strip (cut text 5 None))]
          (setv state.gateway-url url)
          (status-text f"Gateway URL set to: {url}")
          (title-text))
        
        ;; Command: /clear
        (= text "/clear")
        (do
          (output-clear)
          (setv state.messages []))
        
        ;; Command: /quit or /exit
        (in text ["/quit" "/exit"])
        (quit)
        
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
(setv input-field (TextArea :multiline False
                            :height (Dimension :min 1 :max 3)
                            :wrap-lines True
                            :accept-handler accept-handler))


(defn invalidate []
  "Redraw the app."
  (let [app (get-app-or-none)]
    (when app
      (.invalidate app))))


;; * printing functions
;; -----------------------------------------------------------------------------

(defn title-text []
  "Show the title."
  (setv title-field.text
        f"talon - {state.agent} ({(len state.messages)} messages) ")
  (invalidate))

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
  ;; TODO: implement cancellation
  None)

(defn [(kb.add "home")] _ [event]
  "Scroll output to start."
  (event.app.layout.focus output-field.window)
  (setv output-field.document (Document :text output-field.text :cursor-position 0)))

(defn [(kb.add "end")] _ [event]
  "Scroll output to end."
  (event.app.layout.focus output-field.window)
  (setv output-field.document (Document :text output-field.text :cursor-position (len output-field.text))))

(defn [(kb.add "pageup")] _ [event]
  "Scroll output up."
  (event.app.layout.focus output-field.window)
  (scroll_page_up event))

(defn [(kb.add "pagedown")] _ [event]
  "Scroll output down."
  (event.app.layout.focus output-field.window)
  (scroll_page_down event))

(defn [(kb.add "s-tab")] _ [event]
  "Toggle focus between input and output."
  (if (is (event.app.layout.current_window) input-field.window)
    (event.app.layout.focus output-field.window)
    (event.app.layout.focus input-field.window)))


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
