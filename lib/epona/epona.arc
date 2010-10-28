; epona.arc

(load "util.arc")
(load "page.arc")
;(load "mongo.arc")

(= epona-ver*  "1.0a")

(deftem request
  meth  nil
  path  nil
  prtcl nil
  hds   nil
  bdy   nil
  op    nil
  qs    nil
  args  nil
  cooks nil
  ip    nil)

(defs arg  (req key) (alref req!args  key)
      hd   (req key) (alref req!hds   key)
      cook (req key) (alref req!cooks key))

(deftem response
  hds  (obj Server       (+ "epona/" epona-ver*)
            Content-Type mimetypes!html
            Connection   "close")
  code 200
  bdy  nil)

(def load-mimetypes (path)
  (let tb (load-table path)
    (def mimetypes (f)
      (or (tb (sym:downcase:last:tokens string.f #\.))
      ;(or (tb (sym:downcase (last (check (tokens f #\.) ~single))))
          (tb 'txt)))))

(def load-status-codes (path)
  (let tb (load-table path)
    (def http-status (code)
      (aif tb.code
           (string "HTTP/1.0 " code " " it)
           (string "HTTP/1.0 " code " Unknown Status Code")))))

(def load-conf (path)
  (= conf* (load-table (+ appdir* "/app.conf")))
  (fill-table conf* (list 'appdir appdir*
                          'pubdir (+ appdir* "/pub")
                          'tmpdir (+ appdir* "/tmp")
                          'logdir (+ appdir* "/log"))))

(def refresh-static-file-version ()
  (= static-file-version* (+ ".v" (seconds) ".")))

(def static-file (file)
  (re-replace "\\.(.*)$" file (+ static-file-version* "\\1")))

(def ensure-srvdirs ()
  (map ensure-dir (list conf*!logdir conf*!tmpdir)))

(def init-epona ()
  (load-mimetypes    (+ sysdir* "/etc/mime.types"))
  (load-status-codes (+ sysdir* "/etc/http-status"))
  (load-conf         (+ appdir* "/app.conf"))
  (refresh-static-file-version)
  (ensure-srvdirs))

(def serve ((o port 8080))
  (prn "epona/" epona-ver* " (" appdir* ")")
  (init-epona)
  (w/socket s port
    (prn "ready to serve port " port)
    (flushout)
    (= currsock* s)
    (while t
      (errsafe (handle-request s)))))

(= threadlife* 30)

(def handle-request (s)
  (let (i o ip) (socket-accept s)
    (with (th1 nil th2 nil)
      (= th1 (thread
               (after (handle-request-thread i o ip)
                      (close i o)
                      (kill-thread th2))))
      (= th2 (thread
               (sleep threadlife*)
               (unless (dead th1)
                 (prn "srv thread took too long for " ip))
               ; TODO: write log
               (break-thread th1)
               (force-close i o))))))

(def handle-request-thread (i o ip)
  (let req (readreq i ip)
    (or (respond-file o req)
        (respond-page o req)
        (respond-err o 404))))

; ----------------------------------------------------------------------------

(def file-exists-in-pubdir (file)
  (awhen (re-replace "\\.v\\d*\\." string.file ".")
    (or (file-exists (+ conf*!pubdir "/" it))
        (file-exists (+ sysdir* "/share/pub/" it)))))

(def respond-file (o req)
  (awhen (file-exists-in-pubdir req!op)
    (let res (inst 'response)
      (= res!hds!Content-Type   mimetypes.it
         res!hds!Content-Length file-size.it)
      (w/stdout o
        (respond-header res)
        (unless (is req!meth 'head)
          (w/infile i it
            (whilet b (readb i)
              (writeb b o)))))
      'respond)))

(def respond-page (o req)
  (awhen (find-op req!op)
    (it o req)
    'respond))

(def respond-header (res)
  (prrn (http-status res!code))
  (each (k v) res!hds (prrn k ": " v))
  (prrn))

(def respond (o res)
  (w/stdout o
    (respond-header res)
    (when res!bdy
      (prrn res!bdy))))

(def respond-redirect (o to (o code 302))
  (let res (inst 'response 'code code)
    (= res!hds!Location to)
    (respond o res)))

(def respond-err (o (o code 404) (o msg ""))
    ; TODO: response error page
    (respond o (inst 'response
                     'code code
                     'bdy (string code msg))))

; ----------------------------------------------------------------------------

(def readreq (i ip)
  (withs ((meth path prtcl) (tokens:readline i)
          (base qs)         (tokens path #\?)
           hds              (readhds i)
           bdy             (readbdy hds i))
    (inst 'request 'meth  (sym:downcase meth)
                   'path  path
                   'prtcl prtcl
                   'hds   hds
                   'bdy   bdy
                   'op    (sym:cut base 1)
                   'qs    qs
                   'args  (join (only.parseargs qs) (only.parsebdy hds bdy))
                   'cooks (only.parsecooks (alref hds "Cookie"))
                   'ip    ip)))

(def readhds (i)
  (accum a
    (whiler line readline.i blank
      (awhen (pos #\: line)
        (a (list (cut line 0 it)
                 (trim:cut line (+ it 1))))))))

(def readbdy (hds i)
  (aand (alref hds "Content-Length")
        (errsafe:int it)
        (string (map [coerce _ 'char] (readbs it i)))))

(def parseargs (s)
  (map [map urldecode (tokens _ #\=)] (tokens s #\&)))

(def parsecooks (s)
  (map [map [tokens (trim _) #\=] (tokens s #\;)]))

(def parsebdy (hds bdy)
  (when (findsubseq "x-www-form-urlencoded" (alref hds "Content-Type"))
    (parseargs bdy)))

; ----------------------------------------------------------------------------

(= epona-ops* (table) epona-opidxs* (list))

(mac redirect args
  `(_redirect '(,@args)))

(mac httperr args
  `(_httperr '(,@args)))

(mac defop (parm . body)
  (w/uniq (go gs gr ge)
    (let name (if atom.parm parm pop.parm)
      (when (is (type name) 'string)
        (push name epona-opidxs*))
      `(= (epona-ops* ',name)
          (fn (,go req)
            (withs (,gs nil
                    ,gr nil
                    ,ge (point _httperr
                          (= ,gr (point _redirect
                                   (= ,gs (tostring ,@body))))))
              (if ,gs (respond ,go (inst 'response 'bdy ,gs))
                  ,gr (apply respond-redirect ,go ,gr)
                  ,ge (apply respond-err ,go ,ge))))))))

(def find-op (op)
  (aif epona-ops*.op
       it
       (retrieve 1 [re-match (string "^" _ "/$") string.op] epona-opidxs*)
       (epona-ops* it.0)))
