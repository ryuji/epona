(load "tag.arc")

(= html-lang* "ja")

(mac page (title head . body)
  `(do (prn "<!DOCTYPE html>")
       (tag (html lang html-lang*)
         (tag head
           (tag (meta charset "utf-8"))
           (tag title ,title)
           ,@head)
         (tag body ,@body))))
