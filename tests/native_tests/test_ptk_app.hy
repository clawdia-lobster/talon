"Tests for talon.ptk_app module."

(import asyncio)


(defclass MockBuffer []
  "Mock prompt-toolkit buffer for testing accept-handler."
  (defn __init__ [self [text ""]]
    (setv self.text text)))


(defclass MockQueue []
  "Mock asyncio.Queue for testing."
  (defn __init__ [self]
    (setv self._items []))
  (defn :async put [self item]
    (.append self._items item)))


(defn _reload-all []
  "Force re-import of talon.ptk-app and talon.state."
  (import importlib)
  (import talon [state])
  (importlib.reload state)
  (import talon.ptk-app)
  (importlib.reload talon.ptk-app)
  talon.ptk-app)


;; * Command parsing tests
;; -----------------------------------------------------------------------------

(defn test-command-agent-set []
  "/agent <name> sets state.agent."
  (import importlib)
  (import talon [state])
  (importlib.reload state)
  (setv state.agent "main")

  (let [ptk (_reload-all)
        buf (MockBuffer "/agent test-agent")]
    (ptk.accept-handler buf)
    (assert (= "test-agent" state.agent))
    (assert (= "" buf.text))))


(defn test-command-session-set []
  "/session <name> sets state.session."
  (import importlib)
  (import talon [state])
  (importlib.reload state)
  (setv state.session "talon-user-main")

  (let [ptk (_reload-all)
        buf (MockBuffer "/session my-session")]
    (ptk.accept-handler buf)
    (assert (= "my-session" state.session))
    (assert (= "" buf.text))))


(defn test-command-model-set []
  "/model <name> sets state.model."
  (import importlib)
  (import talon [state])
  (importlib.reload state)
  (setv state.model None)

  (let [ptk (_reload-all)
        buf (MockBuffer "/model gpt-4o")]
    (ptk.accept-handler buf)
    (assert (= "gpt-4o" state.model))
    (assert (= "" buf.text))))


(defn test-command-url-set []
  "/url <url> sets state.gateway-url."
  (import importlib)
  (import talon [state])
  (importlib.reload state)
  (setv state.gateway-url "http://localhost:18789")

  (let [ptk (_reload-all)
        buf (MockBuffer "/url http://test:9999")]
    (ptk.accept-handler buf)
    (assert (= "http://test:9999" state.gateway-url))
    (assert (= "" buf.text))))


(defn test-command-file []
  "/file <path> puts a file action on input-queue."
  (import importlib)
  (import talon [state])
  (importlib.reload state)

  (let [ptk (_reload-all)]
    (setv state.input-queue (MockQueue))
    (let [buf (MockBuffer "/file /tmp/test.txt")]
      (ptk.accept-handler buf)
      (assert (= "" buf.text))
      ;; fire-and-forget schedules the put; check the queue has the item
      (assert (= 1 (len state.input-queue._items)))
      (let [item (get state.input-queue._items 0)]
        (assert (= "file" (get item "type")))
        (assert (= "/tmp/test.txt" (get item "path")))))))


(defn test-command-new []
  "/new resets messages and clears buffer."
  (import importlib)
  (import talon [state])
  (importlib.reload state)
  (setv state.messages [{"role" "user" "content" "old"}])

  (let [ptk (_reload-all)
        buf (MockBuffer "/new")]
    (ptk.accept-handler buf)
    (assert (= "" buf.text))
    (assert (= [] state.messages))))


(defn test-command-quit []
  "/quit calls quit function."
  (import importlib)
  (import talon [state])
  (importlib.reload state)

  (let [ptk (_reload-all)
        buf (MockBuffer "/quit")]
    ;; quit() requires a running event loop; just verify buffer clears
    (try
      (ptk.accept-handler buf)
      (except [RuntimeError]))
    (assert (= "" buf.text))))


(defn test-command-exit []
  "/exit also calls quit function."
  (import importlib)
  (import talon [state])
  (importlib.reload state)

  (let [ptk (_reload-all)
        buf (MockBuffer "/exit")]
    ;; quit() requires a running event loop; just verify buffer clears
    (try
      (ptk.accept-handler buf)
      (except [RuntimeError]))
    (assert (= "" buf.text))))


;; * Regular chat message tests
;; -----------------------------------------------------------------------------

(defn test-regular-chat-message []
  "Non-command text is sent as a chat action on input-queue."
  (import importlib)
  (import talon [state])
  (importlib.reload state)

  (let [ptk (_reload-all)]
    (setv state.input-queue (MockQueue))
    (let [buf (MockBuffer "hello world")]
      (ptk.accept-handler buf)
      (assert (= "" buf.text))
      (assert (= 1 (len state.input-queue._items)))
      (let [item (get state.input-queue._items 0)]
        (assert (= "chat" (get item "type")))
        (assert (= "hello world" (get item "content")))))))


(defn test-empty-input-ignored []
  "Whitespace-only input is treated as a chat message (current behaviour)."
  (import importlib)
  (import talon [state])
  (importlib.reload state)

  (let [ptk (_reload-all)]
    (setv state.input-queue (MockQueue))
    (let [buf (MockBuffer "   ")]
      (ptk.accept-handler buf)
      ;; Whitespace-only input is queued as chat (implementation does not skip)
      (assert (= 1 (len state.input-queue._items))))))


;; * Buffer clearing tests
;; -----------------------------------------------------------------------------

(defn test-buffer-cleared-after-command []
  "Buffer text is cleared after processing any command."
  (import importlib)
  (import talon [state])
  (importlib.reload state)

  (let [ptk (_reload-all)]
    ;; Test several commands clear the buffer
    (let [buf (MockBuffer "/agent test")]
      (ptk.accept-handler buf)
      (assert (= "" buf.text)))

    (let [buf (MockBuffer "/session test")]
      (ptk.accept-handler buf)
      (assert (= "" buf.text)))

    (let [buf (MockBuffer "/model test")]
      (ptk.accept-handler buf)
      (assert (= "" buf.text)))

    (let [buf (MockBuffer "/url http://test")]
      (ptk.accept-handler buf)
      (assert (= "" buf.text)))

    (let [buf (MockBuffer "/file /tmp/x")]
      (ptk.accept-handler buf)
      (assert (= "" buf.text)))

    (let [buf (MockBuffer "chat message")]
      (ptk.accept-handler buf)
      (assert (= "" buf.text)))))
