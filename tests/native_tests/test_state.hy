"Tests for talon.state module."

(import os tempfile json pathlib [Path])
(import tomllib)
(import pytest)


(defn _reload-state []
  "Force re-import of talon.state so module-level code re-runs."
  (import importlib)
  (import talon [state])
  (importlib.reload state)
  state)


(defn test-load-config-missing-file []
  "load-config returns empty dict for non-existent file."
  (let [state (_reload-state)]
    (assert (= {} (state.load-config "/nonexistent/path/client.toml")))))


(defn test-load-config-valid-toml [tmp-path]
  "load-config reads a TOML file and returns a dict."
  (let [config-file (str (/ tmp-path "config.toml"))
        f (open config-file "w")]
    (.write f "gateway-url = \"http://test:9999\"\n")
    (.write f "token = \"test-token\"\n")
    (.write f "agent = \"test-agent\"\n")
    (.close f)
    (let [state (_reload-state)
          cfg (state.load-config config-file)]
      (assert (= "http://test:9999" (get cfg "gateway-url")))
      (assert (= "test-token" (get cfg "token")))
      (assert (= "test-agent" (get cfg "agent"))))))


(defn test-load-config-invalid-format-raises [tmp-path]
  "load-config raises TOMLDecodeError for non-TOML files."
  (let [config-file (str (/ tmp-path "config.json"))
        f (open config-file "w")]
    (.write f "{\"gateway_url\": \"http://json:8888\"}")
    (.close f)
    (let [state (_reload-state)]
      (try
        (state.load-config config-file)
        (assert False "Should have raised")
        (except [e tomllib.TOMLDecodeError]
          (assert (isinstance e tomllib.TOMLDecodeError)))))))


(defn test-generate-session-id []
  "Session ID is deterministic: talon-<user> (agent not included)."
  (let [state (_reload-state)]
    (assert (isinstance state.session str))
    (assert (.startswith state.session "talon-"))
    (assert (not (= "" state.session)))
    ;; Agent name should not appear in the default session ID
    (assert (not (in state.agent state.session)))))





(defn test-ssl-verify-default []
  "ssl-verify defaults to True."
  (let [state (_reload-state)]
    (assert (= True state.ssl-verify))))


(defn test-ssl-cert-default []
  "ssl-cert defaults to None when not configured."
  (let [state (_reload-state)]
    (assert (is None state.ssl-cert))))


(defn test-model-default []
  "model defaults to None."
  (let [state (_reload-state)]
    (assert (is None state.model))))


(defn test-input-queue-type []
  "input-queue is an asyncio.Queue."
  (import asyncio)
  (let [state (_reload-state)]
    (assert (isinstance state.input-queue asyncio.Queue))))


(defn test-cancel-event-type []
  "cancel-event is an asyncio.Event."
  (import asyncio)
  (let [state (_reload-state)]
    (assert (isinstance state.cancel-event asyncio.Event))))


(defn test-streaming-default []
  "streaming defaults to False."
  (let [state (_reload-state)]
    (assert (= False state.streaming))))


(defn test-status-default []
  "status defaults to 'Ready'."
  (let [state (_reload-state)]
    (assert (= "Ready" state.status))))


(defn test-last-usage-default []
  "last-usage defaults to None."
  (let [state (_reload-state)]
    (assert (is None state.last-usage))))
