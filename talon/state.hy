"
Manage the client's shared state.
"

(import asyncio [Queue])
(import os)
(import pathlib [Path])
(import tomllib)


;; * Config loading
;; -----------------------------------------------------------------------------

(defn load-config [config-file]
  "Load a TOML config file, returning a dict."
  (try
    (with [f (open config-file "rb")]
      (tomllib.load f))
    (except [FileNotFoundError]
      {})))

;; look for ~/.config/talon/client.toml
;; or default to $pwd/client.toml
(let [p (Path (os.path.expanduser "~/.config/talon/client.toml"))]
  (if (.exists p)
    (setv config-file (str p))
    (setv config-file "client.toml")))

(setv cfg (load-config config-file))

;; OpenClaw connection settings
;; Note: hyphenated TOML keys must use (.get cfg "key" default) not (:key cfg)
;; because Hy mangles hyphens to underscores in keywords.
(setv gateway-url (.get cfg "gateway-url" "http://localhost:18789"))
(setv token (.get cfg "token" ""))
(setv agent (.get cfg "agent" "main"))

;; Deterministic session ID based on hostname + agent
;; This gives continuity across restarts without config.
(setv session (or (.get cfg "session" None)
                   (+ "talon-"
                      (os.path.basename (os.path.expanduser "~"))
                      "-"
                      agent)))

;; SSL settings for self-signed certs / reverse proxies
(setv ssl-verify (.get cfg "ssl-verify" True))
(let [cert (.get cfg "ssl-cert" None)]
  (setv ssl-cert (when cert (os.path.expanduser cert))))

;; Model override (None = use agent default)
(setv model (.get cfg "model" None))

;; Display state
(setv messages [])           ; local message history for display
(setv streaming False)       ; whether we're currently receiving a stream
(setv status "Ready")        ; connection status
(setv last-usage None)       ; token usage from last response

;; * Queues
;; -----------------------------------------------------------------------------

(setv input-queue (Queue))
