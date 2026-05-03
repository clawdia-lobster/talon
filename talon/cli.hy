"""
Non-interactive CLI mode for talon.

Provides command-mode, stdin-mode, JSON output, quiet mode,
and session pinning for shell scripting and automation.
"""


(import asyncio)
(import json)
(import sys)

(import talon [state])
(import talon.openclaw [stream check-connection])
(import talon.repl [stream-response])


;; * CLI runner
;; -----------------------------------------------------------------------------

(defn :async run-command [message args]
  "Send a single MESSAGE and print the response.

  ARGS is a dict of parsed CLI arguments.
  Returns exit code (0 for success, 1 on error)."
  (let [response-text None
        success False]
    (try
      ;; Load history if session is pinned
      (when args.session
        (setv state.session args.session)
        (setv state.messages (state.load-history)))

      ;; Add user message
      (.append state.messages {"role" "user" "content" message})

      ;; Stream response
      (setv response-text (await (stream-response
                                   state.messages
                                   (fn [chunk]
                                     (when (not (or args.quiet args.json))
                                       (print chunk :end "" :flush True)))
                                   :quiet (or args.quiet args.json)
                                   :raise-errors True)))
      (setv success True)

      (except [e [Exception]]
        (print f"talon: {e}" :file sys.stderr)
        (when args.session
          (state.save-history)))

      (else
        ;; Save history with assistant response on success
        (when args.session
          (.append state.messages {"role" "assistant" "content" response-text})
          (state.save-history))

        ;; Output based on format
        (cond
          args.json
          (print (json.dumps {"text" response-text
                              "session" (or args.session state.session)}))

          args.quiet
          (print response-text))))

    ;; Return appropriate exit code
    (if success 0 1)))


(defn run [args]
  "Run the CLI mode with parsed ARGS."
  (sys.exit (asyncio.run (run-command args.message args))))
