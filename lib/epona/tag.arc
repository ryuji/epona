(mac tag (spec . body)
  (if body
    `(do ,(enclose-tag spec)
         ,(tag-body body)
         ,(enclose-tag (aif carif.spec it spec) "</"))
    `,(enclose-tag spec "<" ">")))
    ;`,(enclose-tag spec "<" " />")))

(def enclose-tag (spec (o start "<") (o end ">"))
  (if atom.spec
    `(pr ,start ',spec ,end)
    `(do (pr ,start ',car.spec)
         ,@(tag-opts car.spec (pair cdr.spec))
         (pr ,end))))

(def tag-body (body)
  (if (atom carif.body)
    `(pr ,carif.body)
    `(do ,@body)))

(def tag-opts (spec opts)
  (if (no opts)
    '()
    (let ((opt val) . rest) opts
      (if val
        (cons (tag-opt opt val) (tag-opts spec rest))
        (tag-opts spec rest)))))

(def tag-opt (key val)
  `(aif ,val (pr " " ',key "=\"" it #\")))

; TODO: escape
