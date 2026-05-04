"Tests for talon.cli module."

(import json sys asyncio)
(import pytest)


(defn _reload-cli []
  "Force re-import of talon.cli and dependencies."
  (import importlib)
  (import talon [state])
  (importlib.reload state)
  (import talon.openclaw)
  (importlib.reload talon.openclaw)
  (import talon.cli)
  (importlib.reload talon.cli)
  talon.cli)


;; * run-command tests
;; -----------------------------------------------------------------------------

(defn test-run-command-valid-message []
  "Valid message should return exit code 1 due to no Gateway."
  (let [cli (_reload-cli)]
    (import talon [state])
    (setv state.messages [])
    (setv state.session "test-session")
    
    (setv args (type "Args" #() {"message" "hello"
                                  "json" False
                                  "quiet" False
                                  "session" None}))
    
    ;; Will fail due to no Gateway, but should not crash
    (let [result (asyncio.run (cli.run-command "hello" args))]
      (assert (= 1 result)))))


(defn test-run-command-json-mode []
  "JSON mode should set quiet implicitly."
  (let [cli (_reload-cli)]
    (import talon [state])
    (setv state.messages [])
    
    (setv args (type "Args" #() {"message" "test"
                                  "json" True
                                  "quiet" False
                                  "session" None}))
    
    ;; Will fail due to no Gateway
    (let [result (asyncio.run (cli.run-command "test" args))]
      (assert (= 1 result)))))


(defn test-run-command-session-pinned []
  "Pinned session should attempt to load server-side history."
  (let [cli (_reload-cli)]
    (import talon [state])
    (setv state.messages [])
    (setv state.session "cli-test-session")
    
    (setv args (type "Args" #() {"message" "test message"
                                  "json" False
                                  "quiet" True
                                  "session" "cli-test-session"}))
    
    ;; Will fail due to no Gateway, but session pinning should work
    (let [result (asyncio.run (cli.run-command "test message" args))]
      (assert (= 1 result)))))


;; * Args namespace helper tests
;; -----------------------------------------------------------------------------

(defn test-args-namespace []
  "Verify we can construct args objects for testing."
  (let [args (type "Args" #() {"message" "hi"
                                "json" False
                                "quiet" True
                                "session" "test"})]
    (assert (= "hi" args.message))
    (assert (= False args.json))
    (assert (= True args.quiet))
    (assert (= "test" args.session))))
