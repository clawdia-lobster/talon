"Tests for talon.openclaw module."

(import json)


(defn _reload-openclaw []
  "Force re-import of talon.openclaw so module-level code re-runs."
  (import importlib)
  (import talon [state])
  (importlib.reload state)
  (import talon.openclaw)
  (importlib.reload talon.openclaw)
  talon.openclaw)


;; * build-input tests
;; -----------------------------------------------------------------------------

(defn test-build-input-empty []
  "build-input returns empty list for empty messages."
  (let [oc (_reload-openclaw)]
    (assert (= [] (oc.build-input [])))))


(defn test-build-input-single-message []
  "build-input converts a single message dict to OpenResponses format."
  (let [oc (_reload-openclaw)
        msgs [{"role" "user" "content" "hello world"}]]
    (let [result (oc.build-input msgs)]
      (assert (= 1 (len result)))
      (assert (= "message" (:type (get result 0))))
      (assert (= "user" (:role (get result 0))))
      (assert (= "hello world" (:content (get result 0)))))))


(defn test-build-input-multiple-messages []
  "build-input converts multiple messages."
  (let [oc (_reload-openclaw)
        msgs [{"role" "user" "content" "hi"}
              {"role" "assistant" "content" "hello"}]]
    (let [result (oc.build-input msgs)]
      (assert (= 2 (len result)))
      (assert (= "user" (:role (get result 0))))
      (assert (= "assistant" (:role (get result 1)))))))


;; * build-request tests
;; -----------------------------------------------------------------------------

(defn test-build-request-empty-messages-raises []
  "build-request raises ValueError when messages is empty."
  (let [oc (_reload-openclaw)]
    (try
      (oc.build-request [])
      (assert False "Should have raised")
      (except [e ValueError]
        (assert (in "No messages" (str e)))))))


(defn test-build-request-without-agent []
  "build-request uses 'openclaw' model when no agent is given."
  (let [oc (_reload-openclaw)
        msgs [{"role" "user" "content" "test"}]]
    (let [body (oc.build-request msgs)]
      (assert (= "openclaw" (:model body)))
      (assert (= True (:stream body)))
      (assert (= 1 (len (:input body))))
      (assert (= "message" (:type (get (:input body) 0)))))))


(defn test-build-request-with-agent []
  "build-request uses 'openclaw/<agent>' model when agent is given."
  (let [oc (_reload-openclaw)
        msgs [{"role" "user" "content" "test"}]]
    (let [body (oc.build-request msgs :agent "main")]
      (assert (= "openclaw/main" (:model body))))))


(defn test-build-request-with-session []
  "build-request includes user field when session is given."
  (let [oc (_reload-openclaw)
        msgs [{"role" "user" "content" "test"}]]
    (let [body (oc.build-request msgs :session "my-session")]
      (assert (= "my-session" (:user body))))))


(defn test-build-request-only-sends-last-message []
  "build-request only sends the last message in the list."
  (let [oc (_reload-openclaw)
        msgs [{"role" "user" "content" "first"}
              {"role" "assistant" "content" "second"}
              {"role" "user" "content" "third"}]]
    (let [body (oc.build-request msgs)]
      (assert (= 1 (len (:input body))))
      (assert (= "third" (:content (get (:input body) 0)))))))


;; * build-headers tests
;; -----------------------------------------------------------------------------

(defn test-build-headers-no-token []
  "build-headers returns Content-Type without Authorization when no token."
  (let [oc (_reload-openclaw)]
    (let [headers (oc.build-headers)]
      (assert (= "application/json" (get headers "Content-Type")))
      (assert (not (in "Authorization" headers))))))


(defn test-build-headers-with-token []
  "build-headers includes Authorization Bearer when token is given."
  (let [oc (_reload-openclaw)]
    (let [headers (oc.build-headers :token "secret-token")]
      (assert (= "Bearer secret-token" (get headers "Authorization"))))))


(defn test-build-headers-with-model-override []
  "build-headers includes x-openclaw-model when state.model is set."
  (let [oc (_reload-openclaw)]
    (import talon [state])
    (setv state.model "gpt-4o")
    (let [headers (oc.build-headers)]
      (assert (= "gpt-4o" (get headers "x-openclaw-model"))))))


(defn test-build-headers-without-model-override []
  "build-headers omits x-openclaw-model when state.model is None."
  (import importlib)
  (import talon [state])
  (importlib.reload state)
  (setv state.model None)
  (let [oc (_reload-openclaw)]
    (let [headers (oc.build-headers)]
      (assert (not (in "x-openclaw-model" headers))))))


;; * parse-sse-line tests
;; -----------------------------------------------------------------------------

(defn test-parse-sse-line-valid-json []
  "parse-sse-line parses a valid JSON SSE line."
  (let [oc (_reload-openclaw)
        line "data: {\"type\": \"response.output_text.delta\", \"delta\": \"hello\"}"]
    (let [result (oc.parse-sse-line line)]
      (assert (isinstance result dict))
      (assert (= "response.output_text.delta" (:type result)))
      (assert (= "hello" (:delta result))))))


(defn test-parse-sse-line-done []
  "parse-sse-line returns None for [DONE]."
  (let [oc (_reload-openclaw)]
    (assert (is None (oc.parse-sse-line "data: [DONE]")))))


(defn test-parse-sse-line-no-data-prefix []
  "parse-sse-line returns None for lines without 'data: ' prefix."
  (let [oc (_reload-openclaw)]
    (assert (is None (oc.parse-sse-line "event: message")))
    (assert (is None (oc.parse-sse-line "")))))


(defn test-parse-sse-line-invalid-json []
  "parse-sse-line returns None for invalid JSON."
  (let [oc (_reload-openclaw)]
    (assert (is None (oc.parse-sse-line "data: {invalid json}")))))


;; * extract-text-delta tests
;; -----------------------------------------------------------------------------

(defn test-extract-text-delta-matching-type []
  "extract-text-delta returns delta when type matches."
  (let [oc (_reload-openclaw)
        event {"type" "response.output_text.delta" "delta" "world"}]
    (assert (= "world" (oc.extract-text-delta event)))))


(defn test-extract-text-delta-non-matching-type []
  "extract-text-delta returns None when type doesn't match."
  (let [oc (_reload-openclaw)
        event {"type" "response.completed"}]
    (assert (is None (oc.extract-text-delta event)))))


(defn test-extract-text-delta-missing-delta []
  "extract-text-delta returns empty string when delta key is missing."
  (let [oc (_reload-openclaw)
        event {"type" "response.output_text.delta"}]
    (assert (= "" (oc.extract-text-delta event)))))


;; * extract-usage tests
;; -----------------------------------------------------------------------------

(defn test-extract-usage-matching-type []
  "extract-usage returns usage dict when type matches."
  (let [oc (_reload-openclaw)
        event {"type" "response.completed"
               "response" {"usage" {"input_tokens" 10 "output_tokens" 20}}}]
    (let [usage (oc.extract-usage event)]
      (assert (isinstance usage dict))
      (assert (= 10 (get usage "input_tokens")))
      (assert (= 20 (get usage "output_tokens"))))))


(defn test-extract-usage-non-matching-type []
  "extract-usage returns None when type doesn't match."
  (let [oc (_reload-openclaw)
        event {"type" "response.output_text.delta" "delta" "x"}]
    (assert (is None (oc.extract-usage event)))))


(defn test-extract-usage-missing-response []
  "extract-usage returns None when response key is missing."
  (let [oc (_reload-openclaw)
        event {"type" "response.completed"}]
    (assert (is None (oc.extract-usage event)))))


;; * build-verify tests
;; -----------------------------------------------------------------------------

(defn test-build-verify-default []
  "build-verify returns True by default (ssl-verify=True, no cert)."
  (import importlib)
  (import talon [state])
  (importlib.reload state)
  (setv state.ssl-verify True)
  (setv state.ssl-cert None)
  (let [oc (_reload-openclaw)]
    (assert (= True (oc.build-verify)))))


(defn test-build-verify-disabled []
  "build-verify returns False when ssl-verify is False."
  (let [oc (_reload-openclaw)]
    (import talon [state])
    (setv state.ssl-verify False)
    (setv state.ssl-cert None)
    (assert (= False (oc.build-verify)))))


(defn test-build-verify-with-cert []
  "build-verify returns cert path when ssl-cert is set."
  (let [oc (_reload-openclaw)]
    (import talon [state])
    (setv state.ssl-verify True)
    (setv state.ssl-cert "/path/to/cert.pem")
    (assert (= "/path/to/cert.pem" (oc.build-verify)))))


(defn test-build-verify-cert-takes-precedence []
  "build-verify returns cert path even when ssl-verify is False."
  (let [oc (_reload-openclaw)]
    (import talon [state])
    (setv state.ssl-verify False)
    (setv state.ssl-cert "/path/to/cert.pem")
    (assert (= "/path/to/cert.pem" (oc.build-verify)))))
