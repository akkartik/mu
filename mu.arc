;; what happens when our virtual machine starts up
(= initialization-fns* (queue))
(def reset ()
  (each f (as cons initialization-fns*)
    (f)))

(mac on-init body
  `(enq (fn () ,@body)
        initialization-fns*))

(mac init-fn (name . body)
  `(enq (fn () (= (function* ',name) (convert-names:convert-braces ',body)))
        initialization-fns*))

; things that a future assembler will need separate memory for:
;   code; types; args channel
(def clear ()
  (= types* (table))
  (= memory* (table))
  (= function* (table)))
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
;?               string (obj array t  elem 'byte)  ; inspired by Go
              character (obj size 1)  ; int32 like a Go rune
              character-address (obj size 1  address t  elem 'character)
              string (obj size 1)  ; temporary hack
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
              tagged-value (obj size 2  record t  elems '(type location))
              tagged-value-address (obj size 1  address t  elem 'tagged-value)
              tagged-value-array (obj array t  elem 'tagged-value)
              tagged-value-array-address (obj size 1  address t  elem 'tagged-value-array)
              tagged-value-array-address-address (obj size 1  address t  elem 'tagged-value-array-address)
              ; heterogeneous lists
              list (obj size 2  record t  elems '(tagged-value list-address))
              list-address (obj size 1  address t  elem 'list)
              list-address-address (obj size 1  address t  elem 'list-address)
              ; parallel routines use channels to synchronize
              channel (obj size 5  record t  elems '(boolean boolean integer integer tagged-value-array-address)  fields '(write-watch read-watch first-full first-free circular-buffer))
              channel-address (obj size 1  address t  elem 'channel)
              ; editor
              line (obj array t  elem 'character)
              line-address (obj size 1  address t  elem 'line)
              line-address-address (obj size 1  address t  elem 'line-address)
              screen (obj array t  elem 'line-address)
              screen-address (obj size 1  address t  elem 'screen)
              )))

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
  (= curr-trace-file* filename))

(= dump-trace* nil)
(def trace (label . args)
  (when (or (is dump-trace* t)
            (and dump-trace* (pos label dump-trace*!whitelist))
            (and dump-trace* (no dump-trace*!whitelist) (~pos label dump-trace*!blacklist)))
    (apply prn label ": " args))
  (enq (list label (apply tostring:prn args))
       traces*))

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

(def add-fns (fns)
  (each (name . body) fns
    (= function*.name (convert-names:convert-braces body))))

;; managing concurrent routines

; routine = runtime state for a serial thread of execution
(def make-routine (fn-name)
  (annotate 'routine (obj call-stack (list
      (obj fn-name fn-name  pc 0  caller-arg-idx 0)))))

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

(on-init
  (= running-routines* (queue))
  (= completed-routines* (queue))
  ; set of sleeping routines; don't modify routines while they're in this table
  (= sleeping-routines* (table))
  (= routine* nil)
  (= abort-routine* (parameter nil))
  (= curr-cycle* 0)
  (= scheduling-interval* 500)
  )

; like arc's 'point' but you can also call ((abort-routine*)) in nested calls
(mac routine-mark body
  (w/uniq (g p)
    `(ccc (fn (,g)
            (parameterize abort-routine* (fn ((o ,p)) (,g ,p))
              ,@body)))))

(def run fn-names
  (each it fn-names
    (enq make-routine.it running-routines*))
  ; simple round-robin scheduler
  (while (or (~empty running-routines*)
             (~empty sleeping-routines*))
    (point continue
    (each (routine _) canon.sleeping-routines*
      (awhen (case rep.routine!sleep.1
                literal
                  (> curr-cycle* rep.routine!sleep.0)
                ;else
                  (aand (m rep.routine!sleep)
                        (~is it 0)))
        (trace "schedule" "waking up " top.routine!fn-name)
        (wipe sleeping-routines*.routine)  ; before modifying routine below
        (wipe rep.routine!sleep)
        (++ pc.routine)  ; complete the sleep instruction
        (enq routine running-routines*)))
    (when (empty running-routines*)
      ; ensure forward progress
      (trace "schedule" "skipping cycle " curr-cycle*)
      (++ curr-cycle*)
      (continue))
    (= routine* deq.running-routines*)
    (trace "schedule" top.routine*!fn-name)
    (routine-mark:run-for-time-slice scheduling-interval*)
    (if rep.routine*!sleep
          (do (trace "schedule" "pushing " top.routine*!fn-name " to sleep queue")
              (set sleeping-routines*.routine*))
        (~empty routine*)
          (enq routine* running-routines*)
        :else
          (enq-limit routine* completed-routines*)))))

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
      (whenlet base rep.routine*!call-stack.0!default-scope
        (if (< result memory*.base)
          (do (trace "addr" "incrementing by " base)
              (++ result base))
          (die "addr: no room for var @result"))))
    (when (pos 'deref metadata.loc)
      (trace "addr" "deref " result " => " memory*.result)
      (zap memory* result))))

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
    (if (is 1 sz.loc)
          (memory* addr.loc)
        :else
          (annotate 'record
                    (map memory* (addrs addr.loc sz.loc))))))

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
        (do (assert (~isa val 'record) "setm: record of size 1 @val")
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
      (let (oarg op arg)  (parse-instr (body.routine* pc.routine*))
        (let tmp
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
;?                       (trace "jump" "jumping to " pc.routine*)
                      (continue))
                jump-if
                  (when (is t (m arg.0))
                    (= pc.routine* (+ 1 pc.routine* (v arg.1)))
;?                     (trace "jump-if" "jumping to " pc.routine*)
                    (continue))
                jump-unless  ; convenient helper
                  (unless (is t (m arg.0))
                    (= pc.routine* (+ 1 pc.routine* (v arg.1)))
;?                     (trace "jump-unless" "jumping to " pc.routine*)
                    (continue))

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
                  (let type (v arg.0)
                    (assert (is 'literal (ty arg.0)) "new: second arg @arg.0 must be literal")
                    (if (no types*.type)  (err "no such type @type"))
                    ; todo: initialize memory. currently racket does it for us
                    (if types*.type!array
                      (new-array type (m arg.1))
                      (new-scalar type)))
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
                  (enq (make-routine (v arg.0)) running-routines*)
                ; todo: errors should stall a process and let its parent
                ; inspect it
                assert
                  (assert (m arg.0))
                sleep
                  (let operand arg.0
                    (assert (~pos 'deref metadata.operand)
                            "sleep doesn't support indirect addressing yet")
                    (if (is ty.operand 'literal)
                      (let delay v.operand
                        (trace "run" "sleeping until " (+ curr-cycle* delay))
                        (= rep.routine*!sleep `(,(+ curr-cycle* delay) literal)))
                      (= rep.routine*!sleep operand))
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
              ; opcode generated some value, stored in 'tmp'
              ; copy to output args
;?               (prn "store: " tmp " " oarg)
              (if (acons tmp)
                (for i 0 (< i (min len.tmp len.oarg)) ++.i
                  (when (nondummy oarg.i)
                    (setm oarg.i tmp.i)))
                (when oarg  ; must be a list
                  (trace "run" "writing to oarg " tmp " => " oarg.0)
                  (setm oarg.0 tmp)))
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

(def sizeof (type)
  (trace "sizeof" type)
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
          (if (~is 'begin instr.0)
            (do
              (trace "c{0" pc " " instr " -- " locs)
              (++ pc))
            ; hack: racket replaces curlies with parens, so we need the
            ; keyword begin to delimit blocks.
            ; ultimately there'll be no nesting and curlies will just be in a
            ; line by themselves.
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
                  continue
                    (do
                      (assert (is oarg nil) "continue: can't take oarg @instr")
                      (assert (is arg nil) "continue: can't take arg @instr")
                      (yield `(jump (,(- stack.0 1 pc) offset))))
                  continue-if
                    (do
                      (trace "cvt0" "continue-if: " instr " => " (- stack.0 1))
                      (assert (is oarg nil) "continue-if: can't take oarg @instr")
                      (yield `(jump-if ,arg.0 (,(- stack.0 1 pc) offset))))
                  continue-unless
                    (do
                      (trace "cvt0" "continue-if: " instr " => " (- stack.0 1))
                      (assert (is oarg nil) "continue-unless: can't take oarg @instr")
                      (yield `(jump-unless ,arg.0 (,(- stack.0 1 pc) offset))))
                  ;else
                    (yield instr))))
            (++ pc))))))))

(def close-offset (pc locs)
  (let close 0
    (with (stacksize 0
           done nil)
      (each (state loc) locs
        (if (< loc pc)
              nil  ; do nothing
            (no done)
              (do
                ; first time
                (when (and (is 0 stacksize) (~is loc pc))
                  (++ stacksize))
                (if (is 'open state) (++ stacksize) (-- stacksize))
                ; last time
                (when (is 0 stacksize)
                  (= close loc)
                  (set done))))))
    (- close pc 1)))

;; convert symbolic names to integer offsets

(def convert-names (instrs)
  (with (offset  (table)
         isa-field  (table))
    (let idx 1
      (each instr instrs
        (trace "cn0" instr " " canon.offset " " canon.isa-field)
        (let (oargs op args)  (parse-instr instr)
          (if (in op 'get 'get-address)
            (with (basetype  (typeinfo args.0)
                   field  (v args.1))
              (trace "cn0" "field-access " field)
              ; todo: need to rename args.0 as well?
              (when (pos 'deref (metadata args.0))
                (trace "cn0" "field-access deref")
                (assert basetype!address "@args.0 requests deref, but it's not an address of a record")
                (= basetype (types* basetype!elem)))
              (when (isa field 'sym)
                (assert (or (~offset field) isa-field.field) "field @args.1 is also a variable")
                (when (~offset field)
                  (trace "cn0" "new field; computing offset")
                  (assert basetype!fields "no field names available for @instr")
                  (iflet idx (pos field basetype!fields)
                    (do (set isa-field.field)
                        (= offset.field idx))
                    (assert nil "couldn't find field in @instr")))))
            (each arg args
              (assert (~isa-field v.arg) "arg @arg is also a field name")
              (when (maybe-add arg offset idx)
                (err "use before set: @arg"))))
          (each arg oargs
            (trace "cn0" "checking " arg)
            (unless (is arg '_)
              (assert (~isa-field v.arg) "oarg @arg is also a field name")
              (when (maybe-add arg offset idx)
                (trace "cn0" "location for arg " arg ": " idx)
                (++ idx (sizeof ty.arg))))))))
    (trace "cn1" "update names " canon.offset " " canon.isa-field)
    (each instr instrs
      (let (oargs op args)  (parse-instr instr)
        (each arg args
          (when (and nondummy.arg (offset v.arg))
            (zap offset v.arg)))
        (each arg oargs
          (when (and nondummy.arg (offset v.arg))
            (zap offset v.arg)))))
    instrs))

(def maybe-add (arg offset idx)
  (trace "maybe-add" arg)
  (when (and nondummy.arg
             (~in ty.arg 'literal 'offset 'fn)
             (~offset v.arg)
             (isa v.arg 'sym)
             (~in v.arg 'nil 'default-scope)
             (~pos 'global metadata.arg))
    (= (offset v.arg) idx)))

;; literate tangling system for reordering code

(def convert-quotes (instrs)
  (let deferred (queue)
    (each instr instrs
      (case instr.0
        defer
          (let (q qinstrs)  instr.1
            (assert (is 'make-br-fn q) "defer: first arg must be [quoted]")
            (each qinstr qinstrs
              (enq qinstr deferred)))))
    (accum yield
      (each instr instrs
        (unless (in instr.0 'defer)  ; keep sync'd with case clauses above
          (yield instr)))
      (each instr (as cons deferred)
        (yield instr)))))

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
  ((xtype type) <- arg)
  ((xtypesize integer) <- sizeof (xtype type))
  ((xcheck boolean) <- eq (xtypesize integer) (1 literal))
  (assert (xcheck boolean))
  ; todo: check that arg 0 matches the type? or is that for the future typechecker?
  ((result tagged-value-address) <- new (tagged-value literal))
  ((resulttype location) <- get-address (result tagged-value-address deref) (0 offset))
  ((resulttype location deref) <- copy (xtype type))
  ((locaddr location) <- get-address (result tagged-value-address deref) (1 offset))
  ((locaddr location deref) <- arg)
  (reply (result tagged-value-address)))

(init-fn list-next  ; list-address -> list-address
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((base list-address) <- arg)
  ((result list-address) <- get (base list-address deref) (1 offset))
  (reply (result list-address)))

(init-fn list-value-address  ; list-address -> tagged-value-address
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((base list-address) <- arg)
  ((result tagged-value-address) <- get-address (base list-address deref) (0 offset))
  (reply (result tagged-value-address)))

(init-fn new-list
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((new-list-result list-address) <- new (list literal))
  ((curr list-address) <- copy (new-list-result list-address))
  { begin
    ((curr-value integer) (exists? boolean) <- arg)
    (break-unless (exists? boolean))
    ((next list-address-address) <- get-address (curr list-address deref) (1 offset))
    ((next list-address-address deref) <- new (list literal))
    ((curr list-address) <- list-next (curr list-address))
    ((dest tagged-value-address) <- list-value-address (curr list-address))
    ((dest tagged-value-address deref) <- save-type (curr-value integer))
    (continue)
  }
  ((new-list-result list-address) <- list-next (new-list-result list-address))  ; memory leak
  (reply (new-list-result list-address)))

(init-fn new-channel
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((capacity integer) <- arg)
  ((buffer-address tagged-value-array-address) <- new (tagged-value-array literal) (capacity integer))
  ((result channel-address) <- new (channel literal))
  ((full integer-address) <- get-address (result channel-address deref) (first-full offset))
  ((full integer-address deref) <- copy (0 literal))
  ((free integer-address) <- get-address (result channel-address deref) (first-free offset))
  ((free integer-address deref) <- copy (0 literal))
  ((channel-buffer-address tagged-value-array-address-address) <- get-address (result channel-address deref) (circular-buffer offset))
  ((channel-buffer-address tagged-value-array-address-address deref) <- copy (buffer-address tagged-value-array-address))
  (reply (result channel-address)))

(init-fn write
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((chan channel) <- arg)
  ((val tagged-value) <- arg)
  ((q tagged-value-array-address) <- get (chan channel) (circular-buffer offset))
  ((free integer-address) <- get-address (chan channel) (first-free offset))
  ((dest tagged-value-address) <- index-address (q tagged-value-array-address deref) (free integer-address deref))
  ((dest tagged-value-address deref) <- copy (val tagged-value))
  ((free integer-address deref) <- add (free integer-address deref) (1 literal))
  ((watch boolean-address) <- get-address (chan channel) (write-watch offset))
  ((watch boolean-address deref) <- copy (t literal))
  (reply (chan channel)))

(init-fn read
  ((default-scope scope-address) <- new (scope literal) (30 literal))
  ((chan channel) <- arg)
  ((full integer-address) <- get-address (chan channel) (first-full offset))
  ((q tagged-value-array-address) <- get (chan channel) (circular-buffer offset))
  ((result tagged-value) <- index (q tagged-value-array-address deref) (full integer-address deref))
  ((full integer-address deref) <- add (full integer-address deref) (1 literal))
  ((watch boolean-address) <- get-address (chan channel) (read-watch offset))
  ((watch boolean-address deref) <- copy (t literal))
  (reply (result tagged-value) (chan channel)))

; drop all traces while processing above functions
(on-init
  (= traces* (queue)))

(def prn2 (msg . args)
  (pr msg)
  (apply prn args))

(def canon (table)
  (sort (compare < [tostring (prn:car _)]) (as cons table)))

(def int-canon (table)
  (sort (compare < car) (as cons table)))

;; after loading all files, start at 'main'
(reset)
(awhen cdr.argv
  (map add-fns:readfile it)
  (run 'main)
  (if ($.current-charterm) ($.close-charterm))
  (prn memory*)
;?   (prn completed-routines*)
)
