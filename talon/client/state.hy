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
(setv gateway-url (:gateway-url cfg "http://localhost:18789"))
(setv token (:token cfg ""))
(setv agent (:agent cfg "main"))
(setv session (:session cfg None))

;; SSL settings for self-signed certs / reverse proxies
(setv ssl-verify (:ssl-verify cfg True))
(setv ssl-cert (:ssl-cert cfg None))

;; Display state
(setv messages [])           ; local message history for display
(setv streaming False)       ; whether we're currently receiving a stream
(setv status "Ready")        ; connection status

;; * Queues
;; -----------------------------------------------------------------------------

(setv input-queue (Queue))
