(= sysdir* (env "SYS_DIR") appdir* (env "APP_DIR"))

(push-loadpath (+ sysdir* "/lib/epona"))
(load "epona.arc")
(push-loadpath appdir*)
(load "app.arc")

(serve)
