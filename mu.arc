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
              boolean-address (obj size 1  address t)
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
              integer-address (obj size 1  address t  elem 'integer)  ; pointer to int
              ; records consist of a series of elems, corresponding to a list of types
              integer-boolean-pair (obj size 2  record t  elems '(integer boolean))
              integer-boolean-pair-address (obj size 1  address t  elem 'integer-boolean-pair)
              integer-boolean-pair-array (obj array t  elem 'integer-boolean-pair)
              integer-integer-pair (obj size 2  record t  elems '(integer integer))
              integer-point-pair (obj size 2  record t  elems '(integer integer-integer-pair))
              ; tagged-values are the foundation of dynamic types
              tagged-value (obj size 2  record t  elems '(type location))
              tagged-value-address (obj size 1  address t  elem 'tagged-value)
              ; heterogeneous lists
              list (obj size 2  record t  elems '(tagged-value list-address))
              list-address (obj size 1  address t  elem 'list)
              list-address-address (obj size 1  address t  elem 'list-address)
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
;?     (prn "reset: " it)
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
;?   (prn "trace: " dump-trace*)
  (when (or (is dump-trace* t)
            (and dump-trace* (~pos label dump-trace*!blacklist)))
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

;; running mu
(mac v (operand)  ; for value
  `(,operand 0))

(def metadata (operand)
  cdr.operand)

(def ty (operand)
  operand.1)  ; assume type is always first bit of metadata, and it's always present

(def typeinfo (operand)
  (types* ty.operand))

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
;?   (trace "addr" loc)
  (ret result v.loc
    (unless (pos 'global metadata.loc)
      (whenlet base rep.routine*!call-stack.0!default-scope
        (if (< result memory*.base)
           (++ result base)
           (die "addr: no room for var @result"))))
    (when (pos 'deref metadata.loc)
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
    (let n sz.loc
      (trace "setm" "size of " loc " is " n)
      (assert n "setm: can't compute type of @loc")
      (if (is 1 n)
        (do (assert (~isa val 'record) "setm: record of size 1?! @val")
            (= (memory* addr.loc) val))
        (do (assert (isa val 'record) "setm: non-record of size >1?! @val")
            (each (dest src) (zip (addrs addr.loc n)
                                  (rep val))
              (= (memory* dest) src)))))))

(def array-len (operand)
;?   (prn operand)
;?   (prn (memory* 1000))
  (if typeinfo.operand!array
        (m `(,v.operand integer))
      (and typeinfo.operand!address (pos 'deref metadata.operand))
        (array-len (m operand) typeinfo.operand!elem)
      :else
        (err "can't take len of non-array @operand")))

; (operand field-offset) -> (base-addr field-type)
; operand can be a deref address
; operand can be scope-based
; base-addr returned is always global
(def record-info (operand field-offset)
  (assert (is 'offset (ty field-offset)) "record index @field-offset must have type 'offset'")
  (with (base  addr.operand
         basetype  typeinfo.operand
         idx  (v field-offset))
    (when (pos 'deref metadata.operand)
      (assert basetype!address "base @operand requests deref, but its type is not an address")
      (= basetype (types* basetype!elem)))
    (assert basetype!record "get on non-record @operand")
    (assert (< -1 idx (len basetype!elems)) "@idx is out of bounds of @operand")
    (list (+ base (apply + (map sz (firstn idx basetype!elems))))
          basetype!elems.idx)))

(def array-ref-addr (operand idx)
  (assert typeinfo.operand!array "aref-addr: not an array @operand")
  (unless (< -1 idx (array-len operand))
    (die "aref-addr: out of bounds index @idx for @operand of size @array-len.operand"))
  (withs (elem  typeinfo.operand!elem
          offset  (+ 1 (* idx sz.elem)))
    (+ v.operand offset)))

(def array-ref (operand idx)
  (assert typeinfo.operand!array "aref: not an array @operand")
  (unless (< -1 idx (array-len operand))
    (die "aref: out of bounds index @idx for @operand of size @array-len.operand"))
  (withs (elem  typeinfo.operand!elem
          offset  (+ 1 (* idx sz.elem)))
    (m `(,(+ v.operand offset) ,elem))))

; data structure: routine
; runtime state for a serial thread of execution

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

(= scheduling-interval* 500)

(def parse-instr (instr)
  (iflet delim (pos '<- instr)
    (list (cut instr 0 delim)  ; oargs
          (instr (+ delim 1))  ; op
          (cut instr (+ delim 2)))  ; args
    (list nil instr.0 cdr.instr)))

(mac caller-args (routine)  ; assignable
  `((((rep ,routine) 'call-stack) 0) 'args))

(mac results (routine)  ; assignable
  `((((rep ,routine) 'call-stack) 0) 'results))

(on-init
  (= running-routines* (queue))
  (= completed-routines* (queue))
  (= routine* nil)
  (= abort-routine* (parameter nil)))

; like arc's 'point' but you can also call ((abort-routine*)) in nested calls
(mac routine-mark body
  (w/uniq (g p)
    `(ccc (fn (,g)
            (parameterize abort-routine* (fn ((o ,p)) (,g ,p))
              ,@body)))))

(def run fn-names
  (ret result 0
    (each it fn-names
      (enq make-routine.it running-routines*))
    ; simple round-robin scheduler
    (while (~empty running-routines*)
      (= routine* deq.running-routines*)
      (trace "schedule" top.routine*!fn-name)
      (whenlet insts-run (routine-mark:run-for-time-slice scheduling-interval*)
        (= result (+ result insts-run)))
      (if (~empty routine*)
        (enq routine* running-routines*)
        (enq-limit routine* completed-routines*)))))

(def die (msg)
  (= rep.routine*!error msg)
  (= rep.routine*!stack-trace rep.routine*!call-stack)
  (wipe rep.routine*!call-stack)
  ((abort-routine*)))

($:require "charterm/main.rkt")

(def run-for-time-slice (time-slice)
;?   (prn "AAA")
  (point return
;?     (prn "BBB")
    (for ninstrs 0 (< ninstrs time-slice) (++ ninstrs)
;?       (prn "CCC " pc.routine* " " routine* " " (len body.routine*))
      (if (empty body.routine*) (err "@stack.routine*.0!fn-name not defined"))
      (while (>= pc.routine* (len body.routine*))
        (pop-stack routine*)
        (if empty.routine* (return ninstrs))
        (++ pc.routine*))
      (trace "run" "-- " (sort (compare < string:car) (as cons memory*)))
      (trace "run" top.routine*!fn-name " " pc.routine* ": " (body.routine* pc.routine*))
;?       (trace "run" routine*)
      (let (oarg op arg)  (parse-instr (body.routine* pc.routine*))
;?         (prn op " " arg " -> " oarg)
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
                    (m `(,addr ,type global)))
                get-address
                  (let (addr _)  (record-info arg.0 arg.1)
                    addr)
                index
                  (with (base arg.0  ; integer (non-symbol) memory location including metadata
                         idx (m arg.1))
;?                     (prn "processing index: @base @idx")
                    (when typeinfo.base!address
                      (assert (pos 'deref metadata.base) "index: array has deref but isn't an address @base")
                      (= base (list (memory* v.base) typeinfo.base!elem)))
;?                     (prn "after maybe deref: @base @idx")
;?                     (prn Memory-in-use-until ": " memory*)
                    (assert typeinfo.base!array "index on invalid type @arg.0 => @base")
                    (array-ref base idx))
                index-address
                  (with (base arg.0
                         idx (m arg.1))
                    (when typeinfo.base!address
                      (assert (pos 'deref metadata.base) "index-addr: array has deref but isn't an address @base")
                      (= base (list (memory* v.base) typeinfo.base!elem)))
                    (assert typeinfo.base!array "index-addr on invalid type @arg.0 => @base")
                    (array-ref-addr base idx))
                new
                  (let type (v arg.0)
                    (assert (is 'literal (ty arg.0)) "new: second arg @arg.0 must be literal")
                    (if (no types*.type)  (err "no such type @type"))
                    (if types*.type!array
                      (new-array type (m arg.1))
                      (new-scalar type)))
                sizeof
                  (sizeof (m arg.0))
                len
                  (let base arg.0
                    (if typeinfo.base!array
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
                            (trace "reply" val " => " dest)
                            (setm dest val)))
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
                  (setm oarg.i tmp.i))
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
        (err "no such type @type")))

;; desugar structured assembly based on blocks

(def convert-braces (instrs)
  (let locs ()  ; list of information on each brace: (open/close pc)
    (let pc 0
      (loop (instrs instrs)
        (each instr instrs
          (if (~is 'begin instr.0)
            (do
              (trace "cvt0" pc " " instr " -- " locs)
              (++ pc))
            ; hack: racket replaces curlies with parens, so we need the
            ; keyword begin to delimit blocks.
            ; ultimately there'll be no nesting and curlies will just be in a
            ; line by themselves.
            (do
;?               (prn `(open ,pc))
              (push `(open ,pc) locs)
              (recur cdr.instr)
;?               (prn `(close ,pc))
              (push `(close ,pc) locs))))))
    (zap rev locs)
;?     (prn locs)
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
                (trace "cvt1" pc " " op " " oarg)
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
;?                       (prn "break-if: " instr)
                      (assert (is oarg nil) "break-if: can't take oarg @instr")
                      (yield `(jump-if ,arg.0 (,(close-offset pc locs) offset))))
                  break-unless
                    (do
;?                       (prn "break-if: " instr)
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
;?         (prn "  :" close " " state " - " loc)
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
  (let offset (table)
    (let idx 1
      (each instr instrs
        (let (oargs op args)  (parse-instr instr)
          (each arg args
            (when (maybe-add arg offset idx)
              (err "use before set: @arg")
              (++ idx)))
          (each arg oargs
            (when (maybe-add arg offset idx)
              (++ idx))))))
    (each instr instrs
      (let (oargs op args)  (parse-instr instr)
        (each arg args
          (when (offset v.arg)
            (zap offset v.arg)))
        (each arg oargs
          (when (offset v.arg)
            (zap offset v.arg)))))
    instrs))

(def maybe-add (arg offset idx)
  (unless (or (in ty.arg 'literal 'offset)
              (offset v.arg)
              (~isa v.arg 'sym)
              (in v.arg 'nil 'default-scope)
              (pos 'global metadata.arg))
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

; drop all traces while processing above functions
(on-init
  (= traces* (queue)))

(def prn2 (msg . args)
  (pr msg)
  (apply prn args))

;; after loading all files, start at 'main'
(reset)
(awhen cdr.argv
  (map add-fns:readfile it)
  (run 'main)
  (if ($.current-charterm) ($.close-charterm))
  (prn memory*))
