; TODO: まとめる
(mac tag (spec . body)
  (if body
    `(do ,(enclose-tag spec)
         ,(tag-body body)
         ,(enclose-tag (aif carif.spec it spec) "</"))
    `,(enclose-tag spec)))

; TODO: まとめる
(mac tagx (spec . body)
  (if body
    `(do ,(enclose-tag spec)
         ,(tag-body body)
         ,(enclose-tag (aif carif.spec it spec) "</"))
    `,(enclose-tag spec "<" " />")))

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

; XXX: 使い方間違ってるかも?
(mac gentag (spec (o type 'xml))
  (w/uniq (gs ga go gb)
    (let gs string.spec
      `(mac ,spec ,ga
         (withs (,go (and (acons:car ,ga)
                          (is (caar ,ga) '@)
                          (cdr:car ,ga))
                 ,gb (if ,go (cdr ,ga) ,ga))
               `(tag (,,gs ,@,go) ,@,gb))))))

; XXX: 使い方間違ってるかも?
(def deftags (tags)
  (map [eval `(gentag ,_)] tags))
