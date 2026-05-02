"
OpenClaw OpenResponses API client.

Provides streaming chat via the Gateway's /v1/responses endpoint.
"

(require hyrule [-> ->> unless])

(import json)
(import httpx)

(import talon.client [state])


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
  "Build request headers with optional auth."
  (let [headers {"Content-Type" "application/json"}]
    (when token
      (setv (get headers "Authorization") f"Bearer {token}"))
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


;; * Streaming client
;; -----------------------------------------------------------------------------

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
        client (httpx.AsyncClient :timeout 120)]
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
                (let [delta (extract-text-delta event)]
                  (when delta
                    (.append chunks delta)
                    (yield delta))))))
          (.join "" chunks)))
      (finally
        (await (.aclose client))))))
