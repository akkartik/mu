;; what happens when our virtual machine starts up
(= initialization-fns* (queue))
(def reset ()
  (each f (as cons initialization-fns*)
    (f)))

(mac on-init body
  `(enq (fn () ,@body)
        initialization-fns*))

(mac init-fn (name . body)
  `(enq (fn ()
;?           (prn ',name)
          (= (function* ',name) (convert-names:convert-braces:insert-code ',body ',name)))
        initialization-fns*))

;; persisting and checking traces for each test
(= traces* (queue))
(= trace-dir* ".traces/")
(ensure-dir trace-dir*)
(= curr-trace-file* nil)
(on-init
  (awhen curr-trace-file*
    (tofile (+ trace-dir* it)
      (each (label trace) (as cons traces*)
        (pr label ": " trace))))
  (= curr-trace-file* nil)
  (= traces* (queue)))

(def new-trace (filename)
;?   (prn "new-trace " filename)
;?   )
  (= curr-trace-file* filename))

(= dump-trace* nil)
(def trace (label . args)
  (when (or (is dump-trace* t)
            (and dump-trace* (is label "-"))
            (and dump-trace* (pos label dump-trace*!whitelist))
            (and dump-trace* (no dump-trace*!whitelist) (~pos label dump-trace*!blacklist)))
    (apply prn label ": " args))
  (enq (list label (apply tostring:prn args))
       traces*))

(redef tr args  ; why am I still returning to prn when debugging? Will this help?
  (do1 nil
       (apply trace "-" args)))

(def tr2 (msg arg)
  (tr msg arg)
  arg)

(def check-trace-contents (msg expected-contents)
  (unless (trace-contents-match expected-contents)
    (prn "F - " msg)
    (prn "  trace contents")
    (print-trace-contents-mismatch expected-contents)))

(def trace-contents-match (expected-contents)
  (each (label msg) (as cons traces*)
    (when (and expected-contents
               (is label expected-contents.0.0)
               (posmatch expected-contents.0.1 msg))
      (pop expected-contents)))
  (no expected-contents))

(def print-trace-contents-mismatch (expected-contents)
  (each (label msg) (as cons traces*)
    (whenlet (expected-label expected-msg)  expected-contents.0
      (if (and (is label expected-label)
               (posmatch expected-msg msg))
        (do (pr "  * ")
            (pop expected-contents))
        (pr "    "))
      (pr label ": " msg)))
  (prn "  couldn't find")
  (each (expected-label expected-msg)  expected-contents
    (prn "  ! " expected-label ": " expected-msg)))

;; virtual machine state

; things that a future assembler will need separate memory for:
;   code; types; args channel
(def clear ()
  (= types* (table))
  (= memory* (table))
  (= function* (table))
  )
(enq clear initialization-fns*)

(on-init
  (= types* (obj
              ; Each type must be scalar or array, sum or product or primitive
              type (obj size 1)  ; implicitly scalar and primitive
              type-address (obj size 1  address t  elem 'type)
              type-array (obj array t  elem 'type)
              type-array-address (obj size 1  address t  elem 'type-array)
              location (obj size 1  address t  elem 'location)  ; assume it points to an atom
              integer (obj size 1)
              boolean (obj size 1)
              boolean-address (obj size 1  address t  elem 'boolean)
              byte (obj size 1)
              byte-address (obj  size 1  address t  elem 'byte)
              string (obj array t  elem 'byte)  ; inspired by Go
              string-address (obj size 1  address t  elem 'string)
              character (obj size 1)  ; int32 like a Go rune
              character-address (obj size 1  address t  elem 'character)
              ; isolating function calls
              scope  (obj array t  elem 'location)  ; by convention index 0 points to outer scope
              scope-address  (obj size 1  address t  elem 'scope)
              ; arrays consist of an integer length followed by the right number of elems
              integer-array (obj array t  elem 'integer)
              integer-array-address (obj size 1  address t  elem 'integer-array)
              integer-address (obj size 1  address t  elem 'integer)  ; pointer to int
              ; records consist of a series of elems, corresponding to a list of types
              integer-boolean-pair (obj size 2  record t  elems '(integer boolean)  fields '(int bool))
              integer-boolean-pair-address (obj size 1  address t  elem 'integer-boolean-pair)
              integer-boolean-pair-array (obj array t  elem 'integer-boolean-pair)
              integer-boolean-pair-array-address (obj size 1  address t  elem 'integer-boolean-pair-array)
              integer-integer-pair (obj size 2  record t  elems '(integer integer))
              integer-point-pair (obj size 2  record t  elems '(integer integer-integer-pair))
              ; tagged-values are the foundation of dynamic types
              tagged-value (obj size 2  record t  elems '(type location)  fields '(type payload))
              tagged-value-address (obj size 1  address t  elem 'tagged-value)
              tagged-value-array (obj array t  elem 'tagged-value)
              tagged-value-array-address (obj size 1  address t  elem 'tagged-value-array)
              tagged-value-array-address-address (obj size 1  address t  elem 'tagged-value-array-address)
              ; heterogeneous lists
              list (obj size 2  record t  elems '(tagged-value list-address)  fields '(car cdr))
              list-address (obj size 1  address t  elem 'list)
              list-address-address (obj size 1  address t  elem 'list-address)
              ; parallel routines use channels to synchronize
              channel (obj size 3  record t  elems '(integer integer tagged-value-array-address)  fields '(first-full first-free circular-buffer))
              channel-address (obj size 1  address t  elem 'channel)
              ; editor
              line (obj array t  elem 'character)
              line-address (obj size 1  address t  elem 'line)
              line-address-address (obj size 1  address t  elem 'line-address)
              screen (obj array t  elem 'line-address)
              screen-address (obj size 1  address t  elem 'screen)
              )))

;; managing concurrent routines

; routine = runtime state for a serial thread of execution
(def make-routine (fn-name . args)
  (annotate 'routine (obj call-stack (list
      (obj fn-name fn-name  pc 0  args args  caller-arg-idx 0)))))

(defextend empty (x)  (isa x 'routine)
  (no rep.x!call-stack))

(def stack (routine)
  ((rep routine) 'call-stack))

(mac push-stack (routine op)
  `(push (obj fn-name ,op  pc 0  caller-arg-idx 0)
         ((rep ,routine) 'call-stack)))

(mac pop-stack (routine)
  `(pop ((rep ,routine) 'call-stack)))

(def top (routine)
  stack.routine.0)

(def body (routine (o idx 0))
  (function* stack.routine.idx!fn-name))

(mac pc (routine (o idx 0))  ; assignable
  `((((rep ,routine) 'call-stack) ,idx) 'pc))

(mac caller-arg-idx (routine (o idx 0))  ; assignable
  `((((rep ,routine) 'call-stack) ,idx) 'caller-arg-idx))

(mac caller-args (routine)  ; assignable
  `((((rep ,routine) 'call-stack) 0) 'args))

(mac results (routine)  ; assignable
  `((((rep ,routine) 'call-stack) 0) 'results))

(def waiting-for-exact-cycle? (routine)
  (is 'literal rep.routine!sleep.1))

(def ready-to-wake-up (routine)
  (assert no.routine*)
  (if (is 'literal rep.routine!sleep.1)
    (> curr-cycle* rep.routine!sleep.0)
    (~is rep.routine!sleep.1 (memory* rep.routine!sleep.0))))

(on-init
  (= running-routines* (queue))  ; simple round-robin scheduler
  ; set of sleeping routines; don't modify routines while they're in this table
  (= sleeping-routines* (table))
  (= completed-routines* nil)  ; audit trail
  (= routine* nil)
  (= abort-routine* (parameter nil))
  (= curr-cycle* 0)
  (= scheduling-interval* 500)
  (= scheduler-switch-table* nil)  ; hook into scheduler for tests
  )

; like arc's 'point' but you can also call ((abort-routine*)) in nested calls
(mac routine-mark body
  (w/uniq (g p)
    `(ccc (fn (,g)
            (parameterize abort-routine* (fn ((o ,p)) (,g ,p))
              ,@body)))))

(def run fn-names
  (freeze-functions)
  (= traces* (queue))
  (each it fn-names
    (enq make-routine.it running-routines*))
  (while (~empty running-routines*)
    (= routine* deq.running-routines*)
    (trace "schedule" top.routine*!fn-name)
    (routine-mark
      (run-for-time-slice scheduling-interval*))
    (update-scheduler-state)
;?     (tr "after run iter " running-routines*)
;?     (tr "after run iter " empty.running-routines*)
    ))

; prepare next iteration of round-robin scheduler
;
; state before: routine* running-routines* sleeping-routines*
; state after: running-routines* (with next routine to run at head) sleeping-routines*
;
; responsibilities:
;   add routine* to either running-routines* or sleeping-routines* or completed-routines*
;   wake up any necessary sleeping routines (either by time or on a location)
;   detect deadlock: kill all sleeping routines when none can be woken
(def update-scheduler-state ()
;?   (trace "schedule" curr-cycle*)
  (when routine*
    (if
        rep.routine*!sleep
          (do (trace "schedule" "pushing " top.routine*!fn-name " to sleep queue")
              (set sleeping-routines*.routine*))
        (~empty routine*)
          (do (trace "schedule" "scheduling " top.routine*!fn-name " for further processing")
              (enq routine* running-routines*))
        :else
          (do (trace "schedule" "done with routine")
              (push routine* completed-routines*)))
    (= routine* nil))
  (each (routine _) canon.sleeping-routines*
    (when (ready-to-wake-up routine)
      (trace "schedule" "waking up " top.routine!fn-name)
      (wipe sleeping-routines*.routine)  ; do this before modifying routine
      (wipe rep.routine!sleep)
      (++ pc.routine)
      (enq routine running-routines*)))
  (when (empty running-routines*)
    (whenlet exact-sleeping-routines (keep waiting-for-exact-cycle? keys.sleeping-routines*)
      (let next-wakeup-cycle (apply min (map [rep._!sleep 0] exact-sleeping-routines))
        (= curr-cycle* (+ 1 next-wakeup-cycle))
        (trace "schedule" "skipping to cycle " curr-cycle*)
        (update-scheduler-state))))
  (detect-deadlock))

(def detect-deadlock ()
  (when (and (empty running-routines*)
             (~empty sleeping-routines*)
             (~some 'literal (map (fn(_) rep._!sleep.1)
                                  keys.sleeping-routines*)))
    (each (routine _) sleeping-routines*
      (wipe sleeping-routines*.routine)
      (= rep.routine!error "deadlock detected")
      (push routine completed-routines*))))

(def die (msg)
  (= rep.routine*!error msg)
  (= rep.routine*!stack-trace rep.routine*!call-stack)
  (wipe rep.routine*!call-stack)
  ((abort-routine*)))

;; running a single routine
(def nondummy (operand)  ; precondition for helpers below
  (~is '_ operand))

(mac v (operand)  ; for value
  `(,operand 0))

(def metadata (operand)
  cdr.operand)

(def ty (operand)
  operand.1)  ; assume type is always first bit of metadata, and it's always present

(def typeinfo (operand)
  (or (types* ty.operand)
      (err "unknown type @(tostring prn.operand)")))

(def sz (operand)
  (trace "sz" operand)
  (if (is 'literal ty.operand)
        'literal
      (pos 'deref metadata.operand)
        (do (assert typeinfo.operand!address "tried to deref non-address @operand")
            (sz (list (m `(,(v operand) location))
                      typeinfo.operand!elem)))
      (let-or it typeinfo.operand (err "no such type: @operand")
        (if it!array
          array-len.operand
          it!size))))
(defextend sz (typename) (isa typename 'sym)
  (or types*.typename!size
      (err "type @typename doesn't have a size: " (tostring:pr types*.typename))))

(def addr (loc)
  (trace "addr" loc)
  (ret result v.loc
    (trace "addr" "initial result: " result)
    (unless (pos 'global metadata.loc)
;?       (tr "aa " routine*)
      (whenlet base rep.routine*!call-stack.0!default-scope
        (if (< result memory*.base)
          (do (trace "addr" "incrementing by " base)
              (++ result base))
          (die "addr: no room for var @result"))))
;?     (tr "mm")
    (when (pos 'deref metadata.loc)
      (trace "addr" "deref " result " => " memory*.result)
      (zap memory* result))
;?     (tr "zz")
    ))

(def addrs (n sz)
  (accum yield
    (repeat sz
      (yield n)
      (++ n))))

(def m (loc)  ; read memory, respecting metadata
  (point return
    (if (in ty.loc 'literal 'offset)
      (return v.loc))
    (when (is v.loc 'default-scope)
      (return rep.routine*!call-stack.0!default-scope))
    (trace "m" loc)
    (assert (isa v.loc 'int) "addresses must be numeric (problem in convert-names?) @loc")
    (with (n  sz.loc
           addr  addr.loc)
;?       (trace "m" "reading " n " locations starting at " addr)
      (if (is 1 n)
            (memory* addr)
          :else
            (annotate 'record
                      (map memory* (addrs addr n)))))))

(def setm (loc val)  ; set memory, respecting metadata
  (point return
    (when (is v.loc 'default-scope)
      (assert (is 1 sz.loc) "can't store compounds in default-scope @loc")
      (= rep.routine*!call-stack.0!default-scope val)
      (return))
    (assert (isa v.loc 'int) "can't store to non-numeric address (problem in convert-names?)")
    (trace "setm" loc " <= " val)
    (with (n  sz.loc
           addr  addr.loc)
      (trace "setm" "size of " loc " is " n)
      (assert n "setm: can't compute type of @loc")
      (assert addr "setm: null pointer @loc")
      (if (is 1 n)
        (do (assert (~isa val 'record) "setm: record of size 1 @(tostring prn.val)")
            (trace "setm" loc ": setting " addr " to " val)
            (= (memory* addr) val))
        (do (assert (isa val 'record) "setm: non-record of size >1 @val")
            (each (dest src) (zip (addrs addr n)
                                  (rep val))
              (trace "setm" loc ": setting " dest " to " src)
              (= (memory* dest) src)))))))

; (operand field-offset) -> (base-addr field-type)
; operand can be a deref address
; operand can be scope-based
; base-addr returned is always global
(def record-info (operand field-offset)
  (trace "record-info" operand " " field-offset)
  (assert (is 'offset (ty field-offset)) "record index @field-offset must have type 'offset'")
  (with (base  addr.operand
         basetype  typeinfo.operand
         idx  (v field-offset))
    (trace "record-info" "initial base " base " type " canon.basetype)
    (when (pos 'deref metadata.operand)
      (assert basetype!address "@operand requests deref, but it's not an address of a record")
      (= basetype (types* basetype!elem))
      (trace "record-info" operand " requests deref => " canon.basetype))
    (assert basetype!record "get on non-record @operand")
    (assert (< -1 idx (len basetype!elems)) "@idx is out of bounds of record @operand")
    (list (+ base (apply + (map sz (firstn idx basetype!elems))))
          basetype!elems.idx)))

(def array-info (operand offset)
  (trace "array-info" operand " " offset)
  (with (base  addr.operand
         basetype  typeinfo.operand
         idx  (m offset))
    (trace "array-info" "initial base " base " type " canon.basetype)
    (when (pos 'deref metadata.operand)
      (assert basetype!address "@operand requests deref, but it's not an address of an array")
      (= basetype (types* basetype!elem))
      (trace "array-info" operand " requests deref => " canon.basetype))
    (assert basetype!array "index on non-array @operand")
    (let array-len array-len.operand
      (trace "array-info" "array-len of " operand " is " array-len)
      (assert array-len "can't compute array-len of @operand")
      (unless (< -1 idx array-len)
        (die "@idx is out of bounds of array @operand")))
    (list (+ base
             1  ; for array size
             (* idx (sz basetype!elem)))
          basetype!elem)))

(def array-len (operand)
  (trace "array-len" operand)
  (if typeinfo.operand!array
        (m `(,v.operand integer))
      (and typeinfo.operand!address (pos 'deref metadata.operand))
        (m `(,v.operand integer-address ,@(cut operand 2)))
      :else
        (err "can't take len of non-array @operand")))

(def parse-instr (instr)
  (iflet delim (pos '<- instr)
    (list (cut instr 0 delim)  ; oargs
          (instr (+ delim 1))  ; op
          (cut instr (+ delim 2)))  ; args
    (list nil instr.0 cdr.instr)))

($:require "charterm/main.rkt")

(def run-for-time-slice (time-slice)
  (point return
    (for ninstrs 0 (< ninstrs time-slice) (++ ninstrs)
      (if (empty body.routine*) (err "@stack.routine*.0!fn-name not defined"))
      (while (>= pc.routine* (len body.routine*))
        (pop-stack routine*)
        (if empty.routine* (return ninstrs))
        (++ pc.routine*))
      (++ curr-cycle*)
      (trace "run" "-- " int-canon.memory*)
      (trace "run" curr-cycle* " " top.routine*!fn-name " " pc.routine* ": " (body.routine* pc.routine*))
;?       (trace "run" routine*)
      (when (atom (body.routine* pc.routine*))  ; label
        (when (aand scheduler-switch-table*
                    (alref it (body.routine* pc.routine*)))
          (++ pc.routine*)
          (trace "run" "context-switch forced " abort-routine*)
          ((abort-routine*)))
        (++ pc.routine*)
        (continue))
      (let (oarg op arg)  (parse-instr (body.routine* pc.routine*))
        (let results
              (case op
                ; arithmetic
                add
                  (do (trace "add" (m arg.0) " " (m arg.1))
                  (+ (m arg.0) (m arg.1))
                  )
                sub
                  (- (m arg.0) (m arg.1))
                mul
                  (* (m arg.0) (m arg.1))
                div
                  (/ (real (m arg.0)) (m arg.1))
                idiv
                  (list (trunc:/ (m arg.0) (m arg.1))
                        (mod (m arg.0) (m arg.1)))

                ; boolean
                and
                  (and (m arg.0) (m arg.1))
                or
                  (or (m arg.0) (m arg.1))
                not
                  (not (m arg.0))

                ; comparison
                eq
                  (is (m arg.0) (m arg.1))
                neq
                  (do (trace "neq" (m arg.0) " " (m arg.1))
                  (~is (m arg.0) (m arg.1))
                  )
                lt
                  (< (m arg.0) (m arg.1))
                gt
                  (> (m arg.0) (m arg.1))
                le
                  (<= (m arg.0) (m arg.1))
                ge
                  (>= (m arg.0) (m arg.1))

                ; control flow
                jump
                  (do (= pc.routine* (+ 1 pc.routine* (v arg.0)))
                      (trace "jump" "jumping to " pc.routine*)
                      (continue))
                jump-if
                  (let flag (m arg.0)
                    (trace "jump" "checking that " flag " is t")
                    (when (is t flag)
                      (= pc.routine* (+ 1 pc.routine* (v arg.1)))
                      (trace "jump" "jumping to " pc.routine*)
                      (continue)))
                jump-unless  ; convenient helper
                  (let flag (m arg.0)
                    (trace "jump" "checking that " flag " is not t")
                    (unless (is t flag)
                      (= pc.routine* (+ 1 pc.routine* (v arg.1)))
                      (trace "jump" "jumping to " pc.routine*)
                      (continue)))

                ; data management: scalars, arrays, records
                copy
                  (m arg.0)
                get
                  (let (addr type)  (record-info arg.0 arg.1)
                    (trace "get" arg.0 " " arg.1 " => " addr " " type)
                    (m `(,addr ,type global)))
                get-address
                  (let (addr _)  (record-info arg.0 arg.1)
                    (trace "get-address" arg.0 " " arg.1 " => " addr)
                    addr)
                index
                  (let (addr type)  (array-info arg.0 arg.1)
                    (trace "index" arg.0 " " arg.1 " => " addr " " type)
                    (m `(,addr ,type global)))
                index-address
                  (let (addr _)  (array-info arg.0 arg.1)
                    (trace "index-address" arg.0 " " arg.1 " => " addr)
                    addr)
                new
                  (if (isa arg.0 'string)
                    ; special-case: allocate space for a literal string
                    (new-string arg.0)
                    (let type (v arg.0)
                      (assert (is 'literal (ty arg.0)) "new: second arg @arg.0 must be literal")
                      (if (no types*.type)  (err "no such type @type"))
                      ; todo: initialize memory. currently racket does it for us
                      (if types*.type!array
                        (new-array type (m arg.1))
                        (new-scalar type))))
                sizeof
                  (sizeof (m arg.0))
                len
                  (let base arg.0
                    (if (or typeinfo.base!array typeinfo.base!address)
                      array-len.base
                      -1))

                ; tagged-values require one primitive
                save-type
                  (annotate 'record `(,(ty arg.0) ,(m arg.0)))

                ; multiprocessing
                run
                  (run (v arg.0))
                fork
                  (enq (apply make-routine (v car.arg) (map m cdr.arg)) running-routines*)
                ; todo: errors should stall a process and let its parent
                ; inspect it
                assert
                  (assert (m arg.0))
                sleep
                  (let operand arg.0
                    ; store sleep as either (<cycle number> literal) or (<location> <current value>)
                    (if (is ty.operand 'literal)
                      (let delay v.operand
                        (trace "run" "sleeping until " (+ curr-cycle* delay))
                        (= rep.routine*!sleep `(,(+ curr-cycle* delay) literal)))
                      (do
;?                         (tr "blocking on " operand " -> " (addr operand))
                        (= rep.routine*!sleep `(,addr.operand ,m.operand))))
                    ((abort-routine*)))

                ; text interaction
                cls
                  (do1 nil ($.charterm-clear-screen))
                cll
                  (do1 nil ($.charterm-clear-line))
                cursor
                  (do1 nil ($.charterm-cursor (m arg.0) (m arg.1)))
                print-primitive
                  (do1 nil ((if ($.current-charterm) $.charterm-display pr) (m arg.0)))
                getc
                  (and ($.charterm-byte-ready?) ($.charterm-read-key))
                bold-mode
                  (do1 nil ($.charterm-bold))
                non-bold-mode
                  (do1 nil ($.charterm-normal))
                console-on
                  (do1 nil (if (no ($.current-charterm)) ($.open-charterm)))
                console-off
                  (do1 nil (if ($.current-charterm) ($.close-charterm)))

                ; user-defined functions
                arg
                  (let idx (if arg
                             (do (assert (is 'literal (ty arg.0)))
                                 (v arg.0))
                             (do1 caller-arg-idx.routine*
                                (++ caller-arg-idx.routine*)))
                    (trace "arg" arg " " idx " " caller-args.routine*)
                    (if (len> caller-args.routine* idx)
                      (list caller-args.routine*.idx t)
                      (list nil nil)))
                prepare-reply
                  (prepare-reply arg)
                reply
                  (do (when arg
                        (prepare-reply arg))
                      (let results results.routine*
                        (pop-stack routine*)
                        (if empty.routine* (return ninstrs))
                        (let (caller-oargs _ _)  (parse-instr (body.routine* pc.routine*))
                          (trace "reply" arg " " caller-oargs)
                          (each (dest val)  (zip caller-oargs results)
                            (when nondummy.dest
                              (trace "reply" val " => " dest)
                              (setm dest val))))
                        (++ pc.routine*)
                        (while (>= pc.routine* (len body.routine*))
                          (pop-stack routine*)
                          (when empty.routine* (return ninstrs))
                          (++ pc.routine*))
                        (continue)))
                ; else try to call as a user-defined function
                  (do (if function*.op
                        (let callee-args (accum yield
                                           (each a arg
                                             (yield (m a))))
                          (push-stack routine* op)
                          (= caller-args.routine* callee-args))
                        (err "no such op @op"))
                      (continue))
                )
              ; opcode generated some 'results'
              ; copy to output args
              (if (acons results)
                (each (dest val) (zip oarg results)
                  (unless (is dest '_)
                    (trace "run" val " => " dest)
                    (setm dest val)))
                (when oarg  ; must be a list
                  (trace "run" results " => " oarg.0)
                  (setm oarg.0 results)))
              )
        (++ pc.routine*)))
    (return time-slice)))

(def prepare-reply (args)
  (= results.routine*
     (accum yield
       (each a args
         (yield (m a))))))

(enq (fn () (= Memory-in-use-until 1000))
     initialization-fns*)

(def new-scalar (type)
  (ret result Memory-in-use-until
    (++ Memory-in-use-until sizeof.type)))

(def new-array (type size)
;?   (prn "new array: @type @size")
  (ret result Memory-in-use-until
    (++ Memory-in-use-until (+ 1 (* (sizeof types*.type!elem) size)))
    (= (memory* result) size)))

(def new-string (literal-string)
  (ret result Memory-in-use-until
    (= memory*.Memory-in-use-until len.literal-string)
    (++ Memory-in-use-until)
    (each c literal-string
      (= memory*.Memory-in-use-until c)
      (++ Memory-in-use-until))))

(def sizeof (type)
  (trace "sizeof" type)
  (assert types*.type "sizeof: no such type @type")
  (if (~or types*.type!record types*.type!array)
        types*.type!size
      types*.type!record
        (sum idfn
          (accum yield
            (each elem types*.type!elems
              (yield sizeof.elem))))
      :else
        (err "sizeof can't handle @type (arrays require a specific variable)")))

;; desugar structured assembly based on blocks

(def convert-braces (instrs)
  (let locs ()  ; list of information on each brace: (open/close pc)
    (let pc 0
      (loop (instrs instrs)
        (each instr instrs
          (if (or atom.instr (~is 'begin instr.0))  ; label or regular instruction
                (do
                  (trace "c{0" pc " " instr " -- " locs)
                  (++ pc))
                ; hack: racket replaces curlies with parens, so we need the
                ; keyword 'begin' to delimit blocks.
                ; ultimately there'll be no nesting and curlies will just be
                ; in an instr by themselves.
              :else  ; brace
                (do
                  (push `(open ,pc) locs)
                  (recur cdr.instr)
                  (push `(close ,pc) locs))))))
    (zap rev locs)
    (with (pc  0
           stack  ())  ; elems are pcs
      (accum yield
        (loop (instrs instrs)
          (each instr instrs
            (point continue
            (when (atom instr)  ; label
              (yield instr)
              (++ pc)
              (continue))
            (let delim (or (pos '<- instr) -1)
              (with (oarg  (if (>= delim 0)
                             (cut instr 0 delim))
                     op  (instr (+ delim 1))
                     arg  (cut instr (+ delim 2)))
                (trace "c{1" pc " " op " " oarg)
                (case op
                  begin
                    (do
                      (push pc stack)
                      (assert (is oarg nil) "begin: can't take oarg @instr")
                      (recur arg)
                      (pop stack)
                      (continue))
                  break
                    (do
                      (assert (is oarg nil) "break: can't take oarg @instr")
                      (assert (is arg nil) "break: can't take arg @instr")
                      (yield `(jump (,(close-offset pc locs) offset))))
                  break-if
                    (do
                      (assert (is oarg nil) "break-if: can't take oarg @instr")
                      (yield `(jump-if ,arg.0 (,(close-offset pc locs) offset))))
                  break-unless
                    (do
                      (assert (is oarg nil) "break-unless: can't take oarg @instr")
                      (yield `(jump-unless ,arg.0 (,(close-offset pc locs) offset))))
                  loop
                    (do
                      (assert (is oarg nil) "loop: can't take oarg @instr")
                      (assert (is arg nil) "loop: can't take arg @instr")
                      (yield `(jump (,(- stack.0 1 pc) offset))))
                  loop-if
                    (do
                      (trace "cvt0" "loop-if: " instr " => " (- stack.0 1))
                      (assert (is oarg nil) "loop-if: can't take oarg @instr")
                      (yield `(jump-if ,arg.0 (,(- stack.0 1 pc) offset))))
                  loop-unless
                    (do
                      (trace "cvt0" "loop-if: " instr " => " (- stack.0 1))
                      (assert (is oarg nil) "loop-unless: can't take oarg @instr")
                      (yield `(jump-unless ,arg.0 (,(- stack.0 1 pc) offset))))
                  ;else
                    (yield instr))))
            (++ pc))))))))

(def close-offset (pc locs)
  (point return
;?   (tr "close " pc " " locs)
  (let stacksize 0
    (each (state loc) locs
      (point continue
;?       (tr stacksize "/" done " " state " " loc)
      (when (<= loc pc)
        (continue))
;?       (tr "process " stacksize loc)
      (if (is 'open state) (++ stacksize) (-- stacksize))
      ; last time
;?       (tr "process2 " stacksize loc)
      (when (is -1 stacksize)
;?         (tr "close now " loc)
        (return (- loc pc 1))))))))

;; convert symbolic names to raw memory locations

(def convert-names (instrs)
  (with (location  (table)
         isa-field  (table))
    (let idx 1
      (each instr instrs
        (point continue
        (when atom.instr
          (continue))
        (trace "cn0" instr " " canon.location " " canon.isa-field)
        (let (oargs op args)  (parse-instr instr)
          (if (in op 'get 'get-address)
            (with (basetype  (typeinfo args.0)
                   field  (v args.1))
              (assert basetype "no such type @args.0")
              (trace "cn0" "field-access " field)
              ; todo: need to rename args.0 as well?
              (when (pos 'deref (metadata args.0))
                (trace "cn0" "field-access deref")
                (assert basetype!address "@args.0 requests deref, but it's not an address of a record")
                (= basetype (types* basetype!elem)))
              (when (isa field 'sym)
                (assert (or (~location field) isa-field.field) "field @args.1 is also a variable")
                (when (~location field)
                  (trace "cn0" "new field; computing location")
                  (assert basetype!fields "no field names available for @instr")
                  (iflet idx (pos field basetype!fields)
                    (do (set isa-field.field)
                        (trace "cn0" "field location @idx")
                        (= location.field idx))
                    (assert nil "couldn't find field in @instr")))))
            (each arg args
              (assert (~isa-field v.arg) "arg @arg is also a field name")
              (when (maybe-add arg location idx)
                (err "use before set: @arg"))))
          (each arg oargs
            (trace "cn0" "checking " arg)
            (unless (is arg '_)
              (assert (~isa-field v.arg) "oarg @arg is also a field name")
              (when (maybe-add arg location idx)
                (trace "cn0" "location for arg " arg ": " idx)
                ; todo: can't allocate arrays on the stack
                (++ idx (sizeof ty.arg)))))))))
    (trace "cn1" "update names " canon.location " " canon.isa-field)
    (each instr instrs
      (when (acons instr)
        (let (oargs op args)  (parse-instr instr)
          (each arg args
            (when (and nondummy.arg (location v.arg))
              (zap location v.arg)))
          (each arg oargs
            (when (and nondummy.arg (location v.arg))
              (zap location v.arg))))))
    instrs))

(def maybe-add (arg location idx)
  (trace "maybe-add" arg)
  (when (and nondummy.arg
             (~in ty.arg 'literal 'offset 'fn)
             (~location v.arg)
             (isa v.arg 'sym)
             (~in v.arg 'nil 'default-scope)
             (~pos 'global metadata.arg))
    (= (location v.arg) idx)))

;; literate tangling system for reordering code

(def convert-quotes (instrs)
  (let deferred (queue)
    (each instr instrs
      (when (acons instr)
        (case instr.0
          defer
            (let (q qinstrs)  instr.1
              (assert (is 'make-br-fn q) "defer: first arg must be [quoted]")
              (each qinstr qinstrs
                (enq qinstr deferred))))))
    (accum yield
      (each instr instrs
        (unless (and acons.instr
                     (in instr.0 'defer))  ; keep sync'd with case clauses above
          (yield instr)))
      (each instr (as cons deferred)
        (yield instr)))))

(on-init
  (= before* (table))  ; label -> queue of fragments
  (= after* (table)))  ; label -> list of fragments

; see add-code below for adding to before* and after*

(def insert-code (instrs (o name))
  (loop (instrs instrs)
    (accum yield
      (each instr instrs
        (if (and (acons instr) (~is 'begin car.instr))
              ; simple instruction
              (yield instr)
            (and (acons instr) (is 'begin car.instr))
              ; block
              (yield `{begin ,@(recur cdr.instr)})
            (atom instr)
              ; label
              (do
;?                 (prn "tangling " instr)
                (each fragment (as cons (or (and name (before* (sym:string name '/ instr)))
                                            before*.instr))
                  (each instr fragment
                    (yield instr)))
                (yield instr)
                (each fragment (or (and name (after* (sym:string name '/ instr)))
                                   after*.instr)
                  (each instr fragment
                    (yield instr)))))))))

;; system software

(init-fn maybe-coerce
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((x tagged-value-address) <- new (tagged-value literal))
  ((x tagged-value-address deref) <- arg)
  ((p type) <- arg)
  ((xtype type) <- get (x tagged-value-address deref) (0 offset))
  ((match? boolean) <- eq (xtype type) (p type))
  { begin
    (break-if (match? boolean))
    (reply (0 literal) (nil literal))
  }
  ((xvalue location) <- get (x tagged-value-address deref) (1 offset))
  (reply (xvalue location) (match? boolean)))

(init-fn new-tagged-value
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ; assert (sizeof arg.0) == 1
  ((xtype type) <- arg)
  ((xtypesize integer) <- sizeof (xtype type))
  ((xcheck boolean) <- eq (xtypesize integer) (1 literal))
  (assert (xcheck boolean))
  ; todo: check that arg 0 matches the type? or is that for the future typechecker?
  ((result tagged-value-address) <- new (tagged-value literal))
  ; result->type = arg 0
  ((resulttype location) <- get-address (result tagged-value-address deref) (type offset))
  ((resulttype location deref) <- copy (xtype type))
  ; result->payload = arg 1
  ((locaddr location) <- get-address (result tagged-value-address deref) (payload offset))
  ((locaddr location deref) <- arg)
  (reply (result tagged-value-address)))

(init-fn list-next  ; list-address -> list-address
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((base list-address) <- arg)
  ((result list-address) <- get (base list-address deref) (cdr offset))
  (reply (result list-address)))

(init-fn list-value-address  ; list-address -> tagged-value-address
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((base list-address) <- arg)
  ((result tagged-value-address) <- get-address (base list-address deref) (car offset))
  (reply (result tagged-value-address)))

(init-fn new-list
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ; new-list = curr = new list
  ((new-list-result list-address) <- new (list literal))
  ((curr list-address) <- copy (new-list-result list-address))
  { begin
    ; while read curr-value
    ((curr-value integer) (exists? boolean) <- arg)
    (break-unless (exists? boolean))
    ; curr.cdr = new list
    ((next list-address-address) <- get-address (curr list-address deref) (cdr offset))
    ((next list-address-address deref) <- new (list literal))
    ; curr = curr.cdr
    ((curr list-address) <- list-next (curr list-address))
    ; curr.car = (type curr-value)
    ((dest tagged-value-address) <- list-value-address (curr list-address))
    ((dest tagged-value-address deref) <- save-type (curr-value integer))
    (loop)
  }
  ; return new-list.cdr
  ((new-list-result list-address) <- list-next (new-list-result list-address))  ; memory leak
  (reply (new-list-result list-address)))

(init-fn new-channel
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ; result = new channel
  ((result channel-address) <- new (channel literal))
  ; result.first-full = 0
  ((full integer-address) <- get-address (result channel-address deref) (first-full offset))
  ((full integer-address deref) <- copy (0 literal))
  ; result.first-free = 0
  ((free integer-address) <- get-address (result channel-address deref) (first-free offset))
  ((free integer-address deref) <- copy (0 literal))
  ; result.circular-buffer = new tagged-value[arg+1]
  ((capacity integer) <- arg)
  ((capacity integer) <- add (capacity integer) (1 literal))  ; unused slot for full? below
  ((channel-buffer-address tagged-value-array-address-address) <- get-address (result channel-address deref) (circular-buffer offset))
  ((channel-buffer-address tagged-value-array-address-address deref) <- new (tagged-value-array literal) (capacity integer))
  (reply (result channel-address)))

(init-fn capacity
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((chan channel) <- arg)
  ((q tagged-value-array-address) <- get (chan channel) (circular-buffer offset))
  ((qlen integer) <- len (q tagged-value-array-address deref))
  (reply (qlen integer)))

(init-fn write
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((chan channel-address) <- arg)
  ((val tagged-value) <- arg)
  { begin
    ; block if chan is full
    ((full boolean) <- full? (chan channel-address deref))
    (break-unless (full boolean))
    ((full-address integer-address) <- get-address (chan channel-address deref) (first-full offset))
    (sleep (full-address integer-address deref))
  }
  ; store val
  ((q tagged-value-array-address) <- get (chan channel-address deref) (circular-buffer offset))
  ((free integer-address) <- get-address (chan channel-address deref) (first-free offset))
  ((dest tagged-value-address) <- index-address (q tagged-value-array-address deref) (free integer-address deref))
  ((dest tagged-value-address deref) <- copy (val tagged-value))
  ; increment free
  ((free integer-address deref) <- add (free integer-address deref) (1 literal))
  { begin
    ; wrap free around to 0 if necessary
    ((qlen integer) <- len (q tagged-value-array-address deref))
    ((remaining? boolean) <- lt (free integer-address deref) (qlen integer))
    (break-if (remaining? boolean))
    ((free integer-address deref) <- copy (0 literal))
  }
  (reply (chan channel-address deref)))

(init-fn read
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((chan channel-address) <- arg)
  { begin
    ; block if chan is empty
    ((empty boolean) <- empty? (chan channel-address deref))
    (break-unless (empty boolean))
    ((free-address integer-address) <- get-address (chan channel-address deref) (first-free offset))
    (sleep (free-address integer-address deref))
  }
  ; read result
  ((full integer-address) <- get-address (chan channel-address deref) (first-full offset))
  ((q tagged-value-array-address) <- get (chan channel-address deref) (circular-buffer offset))
  ((result tagged-value) <- index (q tagged-value-array-address deref) (full integer-address deref))
  ; increment full
  ((full integer-address deref) <- add (full integer-address deref) (1 literal))
  { begin
    ; wrap full around to 0 if necessary
    ((qlen integer) <- len (q tagged-value-array-address deref))
    ((remaining? boolean) <- lt (full integer-address deref) (qlen integer))
    (break-if (remaining? boolean))
    ((full integer-address deref) <- copy (0 literal))
  }
  (reply (result tagged-value) (chan channel-address deref)))

; An empty channel has first-empty and first-full both at the same value.
(init-fn empty?
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ; return arg.first-full == arg.first-free
  ((chan channel) <- arg)
  ((full integer) <- get (chan channel) (first-full offset))
  ((free integer) <- get (chan channel) (first-free offset))
  ((result boolean) <- eq (full integer) (free integer))
  (reply (result boolean)))

; A full channel has first-empty just before first-full, wasting one slot.
; (Other alternatives: https://en.wikipedia.org/wiki/Circular_buffer#Full_.2F_Empty_Buffer_Distinction)
(init-fn full?
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((chan channel) <- arg)
  ; curr = chan.first-free + 1
  ((curr integer) <- get (chan channel) (first-free offset))
  ((curr integer) <- add (curr integer) (1 literal))
  { begin
    ; if (curr == chan.capacity) curr = 0
    ((qlen integer) <- capacity (chan channel))
    ((remaining? boolean) <- lt (curr integer) (qlen integer))
    (break-if (remaining? boolean))
    ((curr integer) <- copy (0 literal))
  }
  ; return chan.first-full == curr
  ((full integer) <- get (chan channel) (first-full offset))
  ((result boolean) <- eq (full integer) (curr integer))
  (reply (result boolean)))

(init-fn strcat
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ; result = new string[a.length + b.length]
  ((a string-address) <- arg)
  ((a-len integer) <- len (a string-address deref))
  ((b string-address) <- arg)
  ((b-len integer) <- len (b string-address deref))
  ((result-len integer) <- add (a-len integer) (b-len integer))
  ((result string-address) <- new (string literal) (result-len integer))
  ; result-idx = i = 0
  ((result-idx integer) <- copy (0 literal))
  ; copy a into result
  ((i integer) <- copy (0 literal))
  { begin
    ; while (i < a.length)
    ((a-done? boolean) <- lt (i integer) (a-len integer))
    (break-unless (a-done? boolean))
    ; result[result-idx] = a[i]
    ((out byte-address) <- index-address (result string-address deref) (result-idx integer))
    ((in byte) <- index (a string-address deref) (i integer))
    ((out byte-address deref) <- copy (in byte))
    ; ++i
    ((i integer) <- add (i integer) (1 literal))
    ; ++result-idx
    ((result-idx integer) <- add (result-idx integer) (1 literal))
    (loop)
  }
  ; copy b into result
  ((i integer) <- copy (0 literal))
  { begin
    ; while (i < b.length)
    ((b-done? boolean) <- lt (i integer) (b-len integer))
    (break-unless (b-done? boolean))
    ; result[result-idx] = a[i]
    ((out byte-address) <- index-address (result string-address deref) (result-idx integer))
    ((in byte) <- index (b string-address deref) (i integer))
    ((out byte-address deref) <- copy (in byte))
    ; ++i
    ((i integer) <- add (i integer) (1 literal))
    ; ++result-idx
    ((result-idx integer) <- add (result-idx integer) (1 literal))
    (loop)
  }
  (reply (result string-address)))

(def canon (table)
  (sort (compare < [tostring (prn:car _)]) (as cons table)))

(def int-canon (table)
  (sort (compare < car) (as cons table)))

;; loading code into the virtual machine

(def add-code (forms)
  (each (op . rest)  forms
    (case op
      ; syntax: def <name> [ <instructions> ]
      ; don't apply our lightweight tools just yet
      def!
        (let (name (_make-br-fn body))  rest
          (assert (is 'make-br-fn _make-br-fn))
          (= function*.name body))
      def
        (let (name (_make-br-fn body))  rest
          (assert (is 'make-br-fn _make-br-fn))
          (= function*.name (join body function*.name)))

      ; syntax: before <label> [ <instructions> ]
      ;
      ; multiple before directives => code in order
      before
        (let (label (_make-br-fn fragment))  rest
          (assert (is 'make-br-fn _make-br-fn))
          (or= before*.label (queue))
          (enq fragment before*.label))

      ; syntax: after <label> [ <instructions> ]
      ;
      ; multiple after directives => code in *reverse* order
      ; (if initialization order in a function is A B, corresponding
      ; finalization order should be B A)
      after
        (let (label (_make-br-fn fragment))  rest
          (assert (is 'make-br-fn _make-br-fn))
          (push fragment after*.label))
      )))

(def freeze-functions ()
  (each (name body)  canon.function*
;?     (prn keys.before* " -- " keys.after*)
;?     (= function*.name (convert-names:convert-braces:prn:insert-code body)))
    (= function*.name (convert-names:convert-braces:insert-code body name))))

;; load all provided files and start at 'main'
(reset)
(awhen cdr.argv
  (map add-code:readfile it)
;?   (= dump-trace* (obj whitelist '("run" "schedule" "add")))
;?   (freeze-functions)
;?   (prn function*!factorial)
  (run 'main)
  (if ($.current-charterm) ($.close-charterm))
  (prn memory*)
;?   (prn completed-routines*)
)
