"
OpenClaw OpenResponses API client.

Provides streaming chat via the Gateway's /v1/responses endpoint.
"



(import json)
(import httpx)

(import talon [state])


;; * Request building
;; -----------------------------------------------------------------------------

(defn build-input [messages]
  "Convert a list of {role content} dicts to OpenResponses input items."
  (lfor m messages
    {"type" "message"
     "role" (:role m)
     "content" (:content m)}))

(defn build-request [messages * [agent None] [session None]]
  "Build the POST body for /v1/responses."
  (let [body {"model" (if agent
                        f"openclaw/{agent}"
                        "openclaw")
              "input" (build-input messages)
              "stream" True}]
    (when session
      (setv (get body "user") session))
    body))

(defn build-headers [* [token None]]
  "Build request headers with optional auth and model override."
  (let [headers {"Content-Type" "application/json"}]
    (when token
      (setv (get headers "Authorization") f"Bearer {token}"))
    (when state.model
      (setv (get headers "x-openclaw-model") state.model))
    headers))


;; * SSE parsing
;; -----------------------------------------------------------------------------

(defn parse-sse-line [line]
  "Parse a single SSE line. Returns [event-type data] or None."
  (when (.startswith line "data: ")
    (let [data (cut line 6 None)]
      (when (!= data "[DONE]")
        (try
          (json.loads data)
          (except [json.JSONDecodeError]
            None))))))

(defn extract-text-delta [event]
  "Extract text delta from an SSE event dict."
  (when (= (:type event) "response.output_text.delta")
    (:delta event "")))

(defn extract-usage [event]
  "Extract token usage from a response.completed event."
  (when (= (:type event) "response.completed")
    (:usage (:response event) None)))


;; * Streaming client
;; -----------------------------------------------------------------------------

(defn build-verify []
  "Build the SSL verify parameter for httpx.
  
  If ssl-cert is set, use that path.
  If ssl-verify is False, disable verification.
  Otherwise, use default (True)."
  (cond
    state.ssl-cert state.ssl-cert
    (not state.ssl-verify) False
    :else True))

(defn connection-info []
  "Return a human-readable string describing the connection setup."
  (+ f"Gateway: {state.gateway-url}\n"
     f"Agent: {state.agent}\n"
     f"SSL verify: {state.ssl-verify}\n"
     (if state.ssl-cert
       f"SSL cert: {state.ssl-cert}\n"
       "SSL cert: (none)\n")))

(defn :async stream [messages * [agent None] [session None] [token None] [url None]]
  "Stream a chat completion from the OpenClaw Gateway.
  
  Yields text chunks as they arrive.
  Returns the complete assistant message string."
  (let [url (or url state.gateway-url)
        token (or token state.token)
        agent (or agent state.agent)
        session (or session state.session)
        body (build-request messages :agent agent :session session)
        headers (build-headers :token token)
        verify (build-verify)
        client (httpx.AsyncClient :timeout 120 :verify verify)]
    (try
      (let [response (await (.post client
                                   (+ url "/v1/responses")
                                   :json body
                                   :headers headers))]
        (when (!= response.status_code 200)
          (raise (RuntimeError f"HTTP {response.status_code}: {response.text}")))
        (let [chunks []]
          (for [:async line (.aiter_lines response)]
            (let [event (parse-sse-line line)]
              (when event
                (let [delta (extract-text-delta event)
                      usage (extract-usage event)]
                  (when delta
                    (.append chunks delta)
                    (yield delta))
                  (when usage
                    (setv state.last-usage usage))))))
          (.join "" chunks)))
      (except [e [httpx.ConnectError]]
        (raise (RuntimeError
                 (+ f"Connection failed to {url}\n"
                    f"SSL verify: {verify}\n"
                    (if state.ssl-cert
                      f"SSL cert path: {state.ssl-cert}\n"
                      "")
                    f"Original error: {e}"))))
      (finally
        (await (.aclose client))))))
