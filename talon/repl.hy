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
(import talon.openclaw [stream connection-info check-connection])
(import talon.ptk-app [app
                                  output-text
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
          (match (:type action "chat")
            "chat"
            (await (handle-chat (:content action)))
            "file"
            (await (handle-file (:path action))))))
      (except [e [Exception]]
        (output-text f"\n❌ Error: {e}\n\n")))))

(defn :async handle-chat [text]
  "Handle a chat message: send to Gateway, stream response."
  ;; Reset cancellation
  (state.cancel-event.clear)
  ;; Add user message to display
  (setv state.streaming True)
  (status-text "Sending...")
  (.append state.messages {"role" "user" "content" text})
  (output-text f"\n{text}\n")
  
  ;; Stream response
  (status-text "Streaming...")
  (output-text "\n────────────────────────────────────────\n")
  (let [chunks []
        response-text (try
                         (for [:async chunk (stream state.messages)]
                           (.append chunks chunk)
                           (output-text chunk)
                           ;; Check for cancellation
                           (when (state.cancel-event.is_set)
                             (raise (asyncio.CancelledError))))
                         (.join "" chunks)
                         (except [asyncio.CancelledError]
                           "\n[Cancelled]")
                         (except [e [Exception]]
                           (output-text f"\n❌ Error: {e}\n")
                           ""))]
    ;; Save complete response
    (.append state.messages {"role" "assistant" "content" response-text})
    (output-text "\n────────────────────────────────────────\n")
    (setv state.streaming False)
    (state.save-history)
    (let [usage-str (if state.last-usage
                       (let [u state.last-usage]
                         f" · {(:input_tokens u 0)}→{(:output_tokens u 0)} tok")
                       "")]
      (status-text f"Ready{usage-str}"))
    (title-text)))

(defn :async handle-file [path]
  "Handle a file attachment request."
  (try
    (let [content (with [f (open path "rb")]
                    (.read f))]
      (.append state.messages {"role" "user" "content" [{"type" "input_file"
                                                           "source" {"type" "base64"
                                                                     "data" (base64.b64encode content)
                                                                     "filename" (os.path.basename path)}}]})
      (output-text f"\n[Attached: {path}]\n\n")
      (status-text f"File attached: {(os.path.basename path)}"))
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
  ;; Load previous history
  (setv state.messages (state.load-history))
  (when state.messages
    (for [m state.messages]
      (let [role (:role m)
            content (:content m)]
        (if (= role "user")
          (output-text f"\n{content}\n")
          (do
            (output-text "\n────────────────────────────────────────\n")
            (output-text content)))))
    (output-text "\n────────────────────────────────────────\n"))
  (title-text)
  (await (asyncio.gather (repl-loop)
                         (app.run-async))))

(defn run []
  "Run the input and output tasks."
  (sys.exit
    (try
      (asyncio.run (main-loop))
      (except [CancelledError]))))
