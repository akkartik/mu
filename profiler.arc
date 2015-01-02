; A simple call-counting profiler.
; https://bitbucket.org/fallintothis/profiler

(= profiles* (table) originals* (table))

; avoid infinite loops & other badness in profiled fn, e.g. (profile +)
(with (orig-+ +
       orig-is is
       orig-err err
       orig-type type
       orig-sref sref
       orig-apply apply
       orig-atomic-invoke atomic-invoke)

(mac profiled (f)
  ; (= (profiles* f) 0)
  `(profiled-as ',f ,f))

; Not sure I like the order of the arguments, but probably rarely use this.

(def profiled-as (name f (o profile-data profiles*))
  (if (orig-is (orig-is (orig-type f) 'fn) nil)
      (orig-err "Can only profile functions:" f))
  (fn args
    (orig-atomic-invoke
      (fn () (orig-sref profile-data
                        (orig-+ (profile-data name 0) 1)
                        name)))
    (orig-apply f args)))

; Have to be careful here.  (= profiles* (table)) won't work, since profiled-as
; has the table passed in as an arg: after a (= ...), old closed-over
; references from profiled-as will fail to update the profiles* table.
;   (= glob* (table))
;   (def foo ((o y glob*)) (fn (x) (= (y x) t)))
;   (= bar (foo))
;   (bar 5)           ; glob* = #hash((5 . t))
;   (= glob* (table)) ; glob* = #hash()
;   (bar 5)           ; glob* = #hash(), still

(def reset-profiles ((o fns))
  (each f (or fns (keys profiles*))
    (orig-atomic-invoke
      (fn () (orig-sref profiles*
                        nil
                        f))))
  'ok)

)

(mac profile (f)
  `(do
     (= (originals* ',f) ,f)
     (= ,f (profiled ,f))
     (warn (+ ,(string f)
              " is being profiled; "
              "do not redefine it until you (unprofile " ,(string f) ")"))
     t))

(mac unprofile (f)
  `(= ,f (originals* ',f ,f)
      (originals* ',f) nil
      (profiles* ',f) nil))

(def profiles ((o profiler-data profiles*))
  (withs (data   ; avoid counting stuff from the current call to (profiles)
                 (with (atomic-invokes (profiler-data 'atomic-invoke)
                        tables (profiler-data 'table)
                        srefs (profiler-data 'sref)
                        new (table))
                   (maptable (fn (k v) (= (new k) v)) profiler-data)
                   (= (new 'atomic-invoke) atomic-invokes
                      (new 'table) tables
                      (new 'sref) srefs)
                   new)
          lhead  "Function"
          rhead  "Call Count"
          lwidth (apply max (map len:tostring:disp (cons lhead (keys data))))
          prnrow (fn (l r) 
                   (w/bars
                     (do (pr l) (sp (- lwidth (len l))))
                     (prn r))))
    (prn)
    (prnrow lhead rhead)
    (each (f call-count) (sortable data)
      (prnrow (tostring:disp f) call-count))
    (prn)))

(mac profiling-just (fns . bod)
  (unless (acons fns)
    (zap list fns))
  (w/uniq (profiles profiled)
    (let originals (map [uniq] fns)
      `(with (,profiles (table)
              ,profiled profiled-as
              ,@(mappend list originals fns))
         ; ,@(map (fn (f) `(= (,profiles ',f) 0)) fns)
         ,@(map (fn (f o) `(= ,f (,profiled ',f ,o ,profiles)))
                fns
                originals)
         (after (do ,@bod)
           (= ,@(apply + nil (map list fns originals)))
           (if (> (,profiles 'protect 0) 1) ; from (after ...)
               (-- (,profiles 'protect))
               (wipe (,profiles 'protect)))
           (profiles ,profiles))))))

(def all-fns ()
  (let xdefs '(apply cons car cdr is err + - * / mod expt sqrt > < len annotate
               type rep uniq ccc infile outfile instring outstring inside
               stdout stdin stderr call-w/stdout call-w/stdin readc readb peekc
               writec writeb write disp sread coerce open-socket socket-accept
               setuid new-thread kill-thread break-thread current-thread sleep
               system pipe-from table protect rand dir file-exists dir-exists
               rmfile mvfile macex macex1 eval on-err details scar scdr sref
               bound newstring trunc exact msec current-process-milliseconds
               current-gc-milliseconds seconds client-ip atomic-invoke dead
               flushout ssyntax ssexpand quit close force-close memory declare
               timedate sin cos tan asin acos atan log)
    (+ xdefs (keep [isa (eval _) 'fn] (keys sig*)))))

(mac profile-all ()
  (with (fns (all-fns) orig-atomic-invoke (uniq) orig-sref (uniq))
    `(with (,orig-sref sref
            ,orig-atomic-invoke atomic-invoke)
       (do ,@(map (fn (f) `(profile ,f)) fns)
           ,@(map (fn (f) `(,orig-atomic-invoke
                             (fn () (,orig-sref profiles* nil ',f))))
                  fns)
           t))))

(mac unprofile-all ()
  `(do ,@(map (fn (f) `(unprofile ,f)) (keys originals*))))

(mac profiling code
  `(profiling-just ,(all-fns) ,@code))

(mac profile-here (marker . code)
  ; (= (profiles* marker) 0)
  `(do1 (do ,@code)
        (++ (profiles* ',marker 0))))
