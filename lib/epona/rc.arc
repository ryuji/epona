(= epona-dir*  (env "EPONA_DIR")
   app-dir*    (env "APP_DIR"))

(push epona-dir* libpaths*)
(push app-dir* libpaths*)

(load "epona.arc")
