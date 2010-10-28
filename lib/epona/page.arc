(load "tag.arc")

(= html-lang* "ja")

(def html5shim ()
  (pr "<!--[if lt IE 9]>")
  (tag (script src "http://html5shim.googlecode.com/svn/trunk/html5.js") "")
  (pr "<![endif]-->"))

(mac page (head . body)
  (= head (listtab:pair head))
  `(do (pr "<!DOCTYPE html>")
       (tag (html lang html-lang* dir "ltr")
         (tag head
           (tag (meta charset "utf-8"))
           (tag title ,(aif head!title it "untitled"))
           (html5shim))
         ; TODO: css js meta link
         (tag body ,@body))))
