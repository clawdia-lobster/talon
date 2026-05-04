"
The main REPL event loop.

Reads user input, sends to OpenClaw Gateway, streams response to UI.
"


(import asyncio)
(import asyncio [CancelledError])
(import base64)
(import os)
(import sys)

(import talon [state])
(import talon.openclaw [stream connection-info check-connection fetch-history])
(import talon.ptk-app [app
                                  output-text
                                  output-clear
                                  status-text
                                  title-text])


;; * Event loop
;; -----------------------------------------------------------------------------

(defn :async repl-loop []
  "Main loop: read input, stream response, update UI."
  (while True
    (try
      (let [action (await (.get state.input-queue))]
        (when action
          (let [action-type (.get action "type" "chat")]
            (cond
              (= action-type "chat")
              (await (handle-chat (:content action)))
              (= action-type "file")
              (await (handle-file (:path action)))
              (= action-type "switch")
              (await (handle-switch))))))
      (except [e [Exception]]
        (output-text f"\n❌ Error: {e}\n\n")))))

(defn :async stream-response [messages callback * [quiet False] [raise-errors False]]
  "Stream a response from the Gateway, calling CALLBACK with each chunk.

  Returns the full response text. If QUIET is True, CALLBACK is not called
  during streaming (used for buffered output modes).
  If RAISE-ERRORS is True, exceptions propagate instead of being caught."
  (let [chunks []]
    (try
      (for [:async chunk (stream messages)]
        (.append chunks chunk)
        (when (and callback (not quiet))
          (callback chunk))
        ;; Check for cancellation
        (when (state.cancel-event.is_set)
          (raise (asyncio.CancelledError))))
      (.join "" chunks)
      (except [asyncio.CancelledError]
        ;; Distinguish user-initiated vs external cancellation
        (if (state.cancel-event.is_set)
          (.join "" chunks)
          (raise)))
      (except [e [Exception]]
        (when callback
          (callback f"\n❌ Error: {e}\n"))
        (when raise-errors
          (raise e))
        ""))))

(defn :async handle-switch []
  "Handle agent/session switch: clear output and load server-side history."
  (output-clear)
  (setv state.messages [])
  (try
    (let [history (await (fetch-history))]
      (setv state.messages history)
      (when history
        (for [m history]
          (let [role (:role m)
                content (:content m)]
            (if (= role "user")
              ;; User message: content may be string or list of blocks
              (if (isinstance content str)
                (output-text f"\n{content}\n\n")
                ;; List content: check block type
                (let [block (get content 0)
                      block-type (:type block "")]
                  (if (= block-type "input_file")
                    ;; File attachment
                    (let [filename (or (.get (:source block {}) "filename") "file")]
                      (output-text f"\n[Attached: {filename}]\n\n"))
                    ;; Text or other blocks — extract text
                    (let [text (or (:text block) "")]
                      (output-text f"\n{text}\n\n")))))
              ;; Assistant message: content is already normalized to string
              (output-text f"{content}\n\n────────────────────────────────────────\n"))))
        (title-text)))
    (except [e [Exception]]
      (output-text f"\n⚠️ Could not load history: {e}\n\n"))))

(defn :async handle-chat [text]
  "Handle a chat message: send to Gateway, stream response.

  When TEXT is None, the message is already in state.messages
  (used by handle-file for combined file+text messages)."
  ;; Reset cancellation
  (state.cancel-event.clear)
  ;; Add user message to display
  (setv state.streaming True)
  (status-text "Sending...")
  (when text
    (.append state.messages {"role" "user" "content" text})
    (output-text f"\n{text}\n\n"))
  
  ;; Stream response
  (status-text "Streaming...")
  (let [response-text (await (stream-response state.messages output-text))]
    ;; Save complete response
    (.append state.messages {"role" "assistant" "content" response-text})
    (output-text "\n\n────────────────────────────────────────\n")
    (setv state.streaming False)
    (let [usage-str (if state.last-usage
                       (let [u state.last-usage]
                         f" · {(:input_tokens u 0)}→{(:output_tokens u 0)} tok")
                       "")]
      (status-text f"Ready{usage-str}"))
    (title-text)))

(defn :async handle-file [path]
  "Handle a file attachment request.

  Combines the file and a text marker into a single user message
  so build-request sends the attachment to the Gateway."
  (try
    (let [content (with [f (open path "rb")]
                    (.read f))
          b64-data (.decode (base64.b64encode content) "utf-8")
          filename (os.path.basename path)]
      (.append state.messages
               {"role" "user"
                "content" [{"type" "input_file"
                           "source" {"type" "base64"
                                     "data" b64-data
                                     "filename" filename}}
                          {"type" "input_text"
                           "text" "[File attached above]"}]})
      (output-text f"\n[Attached: {path}]\n\n")
      (status-text f"File attached: {filename}")
      ;; Stream the response for this combined message
      (await (handle-chat None)))
    (except [e [Exception]]
      (output-text f"\n❌ Failed to attach file: {e}\n\n"))))

(defn :async main-loop []
  "Run the REPL and UI together."
  ;; Check connectivity
  (let [connected (await (check-connection))]
    (if connected
      (status-text "Connected")
      (status-text "⚠️ Gateway unreachable")))
  (output-text (+ "\n" (connection-info) "\n"))
  ;; Load server-side history for current agent/session
  (await (handle-switch))
  (await (asyncio.gather (repl-loop)
                         (app.run-async))))

(defn run []
  "Run the input and output tasks."
  (sys.exit
    (try
      (asyncio.run (main-loop))
      (except [CancelledError]))))
