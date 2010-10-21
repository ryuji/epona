; epona.arc

(load "util.arc")

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
  code 200)

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

(def ensure-srvdirs ()
  (map ensure-dir (list conf*!logdir conf*!tmpdir)))

(def init-epona ()
  (load-mimetypes    (+ sysdir* "/etc/mime.types"))
  (load-status-codes (+ sysdir* "/etc/http-status"))
  (load-conf         (+ appdir* "/app.conf"))
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
        ;TODO: 404
        )))

(def file-exists-in-pubdir (file)
  (awhen string.file
    (file-exists (+ conf*!pubdir "/" it))))

(def respond-header (res)
  (prrn (http-status res!code))
  (each (k v) res!hds (prrn k ": " v))
  (prrn))

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
      res)))

; XXX
(def respond-page (o req)
  (awhen (find-op req!op)
    (let res (inst 'response)
      ; FIXME: this is dummy code!
      ;(= res!bdy (tostring (prn "<html><body><pre>" req "</pre></body></html>")))
      (= res!bdy (it o req))
;      (w/stdout o
;        (respond-header res)
;        (prrn res!bdy))
      res)))

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

#|
(mac defop-raw (name parms . body)
  (w/uniq t1
    `(= (srvops* ',name) 
        (fn ,parms 
          (let ,t1 (msec)
            (do1 (do ,@body)
                 (save-optime ',name (- (msec) ,t1))))))))

(mac defop (name parm . body)
  (w/uniq gs
    `(do (wipe (redirector* ',name))
         (defop-raw ,name (,gs ,parm) 
           (w/stdout ,gs (prn) ,@body)))))
|#

(mac redirect args
  `(REDIRECT '(,@args)))

(mac httperr args
  `(HTTPERR '(,@args)))

(def respond-redirect (to (o code 302))
  (prrn (http-status code))
  (prrn "Location: " to)
  (prrn))

(mac defop (name parm . body)
  (w/uniq (go gs gr ge)
    (when (is (type name) 'string)
    (push name epona-opidxs*))
;  `(= (epona-ops* ',name) (fn ,parm ,@body)))
  `(= (epona-ops* ',name)
      (fn (,go ,parm)
        (withs (,gs nil
                ,gr nil
                ,ge (point httperr
                      (= ,gr (point REDIRECT
                               (= ,gs (tostring ,@body))))))
          (w/stdout ,go
            (if ,gs ,gs
                ,gr (apply respond-redirect ,gr)
                ,ge (respond-err ,ge))))))))

(def find-op (op)
  (aif epona-ops*.op
       it
       (retrieve 1 [re-match (string #\^ _ #\$) string.op] epona-opidxs*)
       (epona-ops* it.0)))
