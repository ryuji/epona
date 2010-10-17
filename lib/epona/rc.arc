(= sysdir* (env "SYS_DIR")
   appdir* (env "APP_DIR"))

(push (+ sysdir* "/lib/epona") libpaths*)
(load "epona.arc")

(push appdir* libpaths*)
(load "app.arc")

(serve)
