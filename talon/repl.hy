"
The main REPL event loop.

Reads user input, sends to OpenClaw Gateway, streams response to UI.
"



(import asyncio)
(import asyncio [CancelledError])
(import sys)

(import talon [state])
(import talon.openclaw [stream connection-info])
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
            (await (handle-chat (:content action))))))
      (except [e [Exception]]
        (output-text f"\n❌ Error: {e}\n\n")))))

(defn :async handle-chat [text]
  "Handle a chat message: send to Gateway, stream response."
  ;; Add user message to display
  (setv state.streaming True)
  (status-text "Sending...")
  (.append state.messages {"role" "user" "content" text})
  (output-text f"\n**user**\n{text}\n\n")
  
  ;; Stream response
  (status-text "Streaming...")
  (output-text "**assistant**\n")
  (let [chunks []
        response-text (try
                         (for [:async chunk (stream state.messages)]
                           (.append chunks chunk)
                           (output-text chunk))
                         (.join "" chunks)
                         (except [e [Exception]]
                           (output-text f"\n❌ Error: {e}\n")
                           ""))]
    ;; Save complete response
    (.append state.messages {"role" "assistant" "content" response-text})
    (output-text "\n\n")
    (setv state.streaming False)
    (status-text "Ready")
    (title-text)))

(defn :async main-loop []
  "Run the REPL and UI together."
  (output-text (+ "\n" (connection-info) "\n"))
  (await (asyncio.gather (repl-loop)
                         (app.run-async))))

(defn run []
  "Run the input and output tasks."
  (sys.exit
    (try
      (asyncio.run (main-loop))
      (except [CancelledError]))))
