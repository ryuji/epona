(load "tag.arc")

(def html5shim ()
  (pr "<!--[if lt IE 9]>")
  (tag (script src "http://html5shim.googlecode.com/svn/trunk/html5.js") "")
  (pr "<![endif]-->"))

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
