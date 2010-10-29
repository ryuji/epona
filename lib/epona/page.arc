(load "tag.arc")

(= assets-ver* (+ ".v" (seconds) "."))

(def assets-ver (file)
  (if (re-match-pat "^https?://" file)
      file
      (re-replace "\\.([^.]*)$" file (+ assets-ver* "\\1"))))

(mac html5shim ()
  `(do (pr "<!--[if lt IE 9]>")
       (script (src "http://html5shim.googlecode.com/svn/trunk/html5.js"))
       (pr "<![endif]-->")))

(mac page (head . body)
  (= head (listtab:pair head))
  `(do (pr "<!DOCTYPE html>")
       (tag (html lang ,(head 'lang "ja") dir "ltr")
         (tag head
           (tag (meta charset "utf-8"))
           (tag title ,(head 'title "untitled"))
           (html5shim))
         ; TODO: css js meta link
         (tag body ,@body))))

(mac script (opts (o body ""))
  (awhen (pos 'src opts)
    (= (opts:++ it) (assets-ver opts.it)))
  `(tag (script ,@opts) ,body))

(mac img (src (o alt "") (o opts))
  (unless (headmatch "/" src)
          (= src (+ "/images/" src)))
  `(tag (img src ,(assets-ver src) alt ,alt ,@opts)))


