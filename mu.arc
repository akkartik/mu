(ero "initializing mu.. (takes ~5s)")
;; profiler (http://arclanguage.org/item?id=11556)
; Keeping this right on top as a reminder to profile before guessing at why my
; program is slow.
(mac proc (name params . body)
  `(def ,name ,params ,@body nil))

(mac filter-log (msg f x)
  `(ret x@ ,x
     (prn ,msg (,f x@))))

(= times* (table))

(mac deftimed (name args . body)
  `(do
     (def ,(sym (string name "_core")) ,args
        ,@body)
     (def ,name ,args
      (let t0 (msec)
        (ret ans ,(cons (sym (string name "_core")) args)
          (update-time ,(string name) t0))))))

(proc update-time(name t0) ; call directly in recursive functions
  (or= times*.name (list 0 0))
  (with ((a b)  times*.name
         timing (- (msec) t0))
    (= times*.name
       (list
         (+ a timing)
         (+ b 1)))))

(def print-times()
  (prn (current-process-milliseconds))
  (prn "gc " (current-gc-milliseconds))
  (each (name time) (tablist times*)
    (prn name " " time)))

;; what happens when our virtual machine starts up
(= initialization-fns* (queue))
(def reset ()
  (each f (as cons initialization-fns*)
    (f)))

(mac on-init body
  `(enq (fn () ,@body)
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
  (prn "== @filename")
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
       traces*)
  (car args))

(on-init
  (wipe dump-trace*))

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

(def check-trace-doesnt-contain (msg (label unexpected-contents))
  (when (some (fn ((l s))
                (and (is l label)  (posmatch unexpected-contents msg)))
              (as cons traces*))
    (prn "F - " msg)
    (prn "  trace contents")
    (each (l msg) (as cons traces*)
      (if (and (is l label)
               (posmatch unexpected-contents msg))
        (pr "  X ")
        (pr "    "))
      (pr label ": " msg))))

;; virtual machine state

; things that a future assembler will need separate memory for:
;   code; types; args channel
;   at compile time: mapping names to locations
(on-init
  (= type* (table))  ; name -> type info
  (= memory* (table))  ; address -> value  (make this a vector?)
  (= function* (table))  ; name -> [instructions]
  ; transforming mu programs
  (= location* (table))  ; function -> {name -> index into default-space}
  (= next-space-generator* (table))  ; function -> name of function generating next space
  ; each function's next space will usually always come from a single function
  (= next-routine-id* 0)
  (= continuation* (table))
  )

(on-init
  (= type* (obj
              ; Each type must be scalar or array, sum or product or primitive
              type (obj size 1)  ; implicitly scalar and primitive
              type-address (obj size 1  address t  elem '(type))
              type-array (obj array t  elem '(type))
              type-array-address (obj size 1  address t  elem '(type-array))
              location (obj size 1  address t  elem '(location))  ; assume it points to an atom
              integer (obj size 1)
              boolean (obj size 1)
              boolean-address (obj size 1  address t  elem '(boolean))
              byte (obj size 1)
              byte-address (obj  size 1  address t  elem '(byte))
              string (obj array t  elem '(byte))  ; inspired by Go
              ; an address contains the location of a specific type
              string-address (obj size 1  address t  elem '(string))
              string-address-address (obj size 1  address t  elem '(string-address))
              string-address-array (obj array t  elem '(string-address))
              string-address-array-address (obj size 1  address t  elem '(string-address-array))
              string-address-array-address-address (obj size 1  address t  elem '(string-address-array-address))
              ; 'character' will be of larger size when mu supports unicode
              ; we're currently undisciplined about mixing 'byte' and 'character'
              ; realistic test of indiscipline in general
              character (obj size 1)  ; int32 like a Go rune
              character-address (obj size 1  address t  elem '(character))
              ; a buffer makes it easy to append to a string/array
              ; todo: make this generic
              ; data isn't a 'real' array: its length is stored outside it,
              ; so for example, 'print-string' won't work on it.
              buffer (obj size 2  and-record t  elems '((integer) (string-address))  fields '(length data))
              buffer-address (obj size 1  address t  elem '(buffer))
              ; a stream makes it easy to read from a string/array
              stream (obj size 2  and-record t  elems '((integer) (string-address))  fields '(pointer data))
              stream-address (obj size 1  address t  elem '(stream))
              ; isolating function calls
              space (obj array t  elem '(location))  ; by convention index 0 points to outer space
              space-address (obj size 1  address t  elem '(space))
              ; arrays consist of an integer length followed by that many
              ; elements, all of the same type
              integer-array (obj array t  elem '(integer))
              integer-array-address (obj size 1  address t  elem '(integer-array))
              integer-array-address-address (obj size 1  address t  elem '(integer-array-address))
              integer-address (obj size 1  address t  elem '(integer))  ; pointer to int
              integer-address-address (obj size 1  address t  elem '(integer-address))
              ; and-records consist of a multiple fields of different types
              integer-boolean-pair (obj size 2  and-record t  elems '((integer) (boolean))  fields '(int bool))
              integer-boolean-pair-address (obj size 1  address t  elem '(integer-boolean-pair))
              integer-boolean-pair-array (obj array t  elem '(integer-boolean-pair))
              integer-boolean-pair-array-address (obj size 1  address t  elem '(integer-boolean-pair-array))
              integer-integer-pair (obj size 2  and-record t  elems '((integer) (integer)))
              integer-integer-pair-address (obj size 1  address t  elem '(integer-integer-pair))
              integer-point-pair (obj size 2  and-record t  elems '((integer) (integer-integer-pair)))
              integer-point-pair-address (obj size 1  address t  elem '(integer-point-pair))
              integer-point-pair-address-address (obj size 1  address t  elem '(integer-point-pair-address))
              ; tagged-values are the foundation of dynamic types
              tagged-value (obj size 2  and-record t  elems '((type) (location))  fields '(type payload))
              tagged-value-address (obj size 1  address t  elem '(tagged-value))
              tagged-value-array (obj array t  elem '(tagged-value))
              tagged-value-array-address (obj size 1  address t  elem '(tagged-value-array))
              tagged-value-array-address-address (obj size 1  address t  elem '(tagged-value-array-address))
              ; heterogeneous lists
              list (obj size 2  and-record t  elems '((tagged-value) (list-address))  fields '(car cdr))
              list-address (obj size 1  address t  elem '(list))
              list-address-address (obj size 1  address t  elem '(list-address))
              ; parallel routines use channels to synchronize
              channel (obj size 3  and-record t  elems '((integer) (integer) (tagged-value-array-address))  fields '(first-full first-free circular-buffer))
              ; be careful of accidental copies to channels
              channel-address (obj size 1  address t  elem '(channel))
              ; opaque pointer to a call stack
              ; todo: save properly in allocated memory
              continuation (obj size 1)
              ; editor
              line (obj array t  elem '(character))
              line-address (obj size 1  address t  elem '(line))
              line-address-address (obj size 1  address t  elem '(line-address))
              screen (obj array t  elem '(line-address))
              screen-address (obj size 1  address t  elem '(screen))
              ; fake screen
              terminal (obj size 5  and-record t  elems '((integer) (integer) (integer) (integer) (string-address))  fields '(num-rows num-cols cursor-row cursor-col data))
              terminal-address (obj size 1  address t  elem '(terminal))
              ; fake keyboard
              keyboard (obj size 2  and-record t  elems '((integer) (string-address))  fields '(index data))
              keyboard-address (obj size 1  address t  elem '(keyboard))
              )))

;; managing concurrent routines

(on-init
;?   (prn "-- resetting memory allocation")
  (= Memory-allocated-until 1000)
  (= Allocation-chunk 100000))

; routine = runtime state for a serial thread of execution
(def make-routine (fn-name . args)
  (let curr-alloc Memory-allocated-until
;?     (prn "-- allocating routine: @curr-alloc")
    (++ Memory-allocated-until Allocation-chunk)
    (annotate 'routine (obj alloc curr-alloc  alloc-max Memory-allocated-until
        call-stack
          (list (obj fn-name fn-name  pc 0  args args  caller-arg-idx 0))))
        ; other fields we use in routine:
        ;   sleep: conditions
        ;   limit: number of cycles this routine can use
        ;   running-since: start of the clock for counting cycles this routine has used

    ; todo: do memory management in mu
    ))

(defextend empty (x)  (isa x 'routine)
  (no rep.x!call-stack))

(def stack (routine)
  ((rep routine) 'call-stack))

(def push-stack (routine op)
  (push (obj fn-name op  pc 0  caller-arg-idx 0  t0 (msec))
        rep.routine!call-stack))

(def pop-stack (routine)
;?   (update-time label.routine (msec)) ;? 1
  (pop rep.routine!call-stack))

(def top (routine)
  stack.routine.0)

(def label (routine)
  (whenlet stack stack.routine
    (or= stack.0!label
         (label2 stack))))
(def label2 (stack)
         (string:intersperse "/" (map [_ 'fn-name] stack)));))

(def body (routine)
  (function* stack.routine.0!fn-name))

(mac pc (routine (o idx 0))  ; assignable
  `((((rep ,routine) 'call-stack) ,idx) 'pc))

(mac caller-arg-idx (routine (o idx 0))  ; assignable
  `((((rep ,routine) 'call-stack) ,idx) 'caller-arg-idx))

(mac caller-args (routine)  ; assignable
  `((((rep ,routine) 'call-stack) 0) 'args))
(mac caller-operands (routine)  ; assignable
  `((((rep ,routine) 'call-stack) 0) 'caller-operands))
(mac caller-results (routine)  ; assignable
  `((((rep ,routine) 'call-stack) 0) 'caller-results))

(mac results (routine)  ; assignable
  `((((rep ,routine) 'call-stack) 0) 'results))
(mac reply-args (routine)  ; assignable
  `((((rep ,routine) 'call-stack) 0) 'reply-args))

(def waiting-for-exact-cycle? (routine)
  (is 'until rep.routine!sleep.0))

(def ready-to-wake-up (routine)
  (assert no.routine*)
  (case rep.routine!sleep.0
    until
      (> curr-cycle* rep.routine!sleep.1)
    until-location-changes
      (~is rep.routine!sleep.2 (memory* rep.routine!sleep.1))
    until-routine-done
      (find [and _ (is rep._!id rep.routine!sleep.1)]
            completed-routines*)
    ))

(on-init
  (= running-routines* (queue))  ; simple round-robin scheduler
  ; set of sleeping routines; don't modify routines while they're in this table
  (= sleeping-routines* (table))
  (= completed-routines* nil)  ; audit trail
  (= routine* nil)
  (= abort-routine* (parameter nil))
  (= curr-cycle* 0)
  (= scheduling-interval* 500)
  (= scheduler-switch-table* nil)  ; hook into scheduler for debugging
  )

; like arc's 'point' but you can also call ((abort-routine*)) in nested calls
(mac routine-mark body
  (w/uniq (g p)
    `(ccc (fn (,g)
            (parameterize abort-routine* (fn ((o ,p)) (,g ,p))
              ,@body)))))

(def run fn-names
  (freeze function*)
;?   (prn function*!main) ;? 1
  (load-system-functions)
  (apply run-more fn-names))

; assume we've already frozen; throw on a few more routines and continue scheduling
(def run-more fn-names
  (each it fn-names
    (enq make-routine.it running-routines*))
  (while (~empty running-routines*)
    (= routine* deq.running-routines*)
    (when rep.routine*!limit
      ; start the clock if it wasn't already running
      (or= rep.routine*!running-since curr-cycle*))
    (trace "schedule" label.routine*)
    (routine-mark
      (run-for-time-slice scheduling-interval*))
    (update-scheduler-state)))

; prepare next iteration of round-robin scheduler
;
; state before: routine* running-routines* sleeping-routines*
; state after: running-routines* (with next routine to run at head) sleeping-routines*
;
; responsibilities:
;   add routine* to either running-routines* or sleeping-routines* or completed-routines*
;   wake up any necessary sleeping routines (which might be waiting for a
;     particular time or for a particular memory location to change)
;   detect termination: all non-helper routines completed
;   detect deadlock: kill all sleeping routines when none can be woken
(def update-scheduler-state ()
  (when routine*
;?     (prn "update scheduler state: " routine*)
    (if
        rep.routine*!sleep
          (do (trace "schedule" "pushing " label.routine* " to sleep queue")
              ; keep the clock ticking at rep.routine*!running-since
              (set sleeping-routines*.routine*))
        rep.routine*!error
          (do (trace "schedule" "done with dead routine " label.routine*)
;?               (tr rep.routine*)
              (push routine* completed-routines*))
        empty.routine*
          (do (trace "schedule" "done with routine " label.routine*)
              (push routine* completed-routines*))
        (no rep.routine*!limit)
          (do (trace "schedule" "scheduling " label.routine* " for further processing")
              (enq routine* running-routines*))
        (> rep.routine*!limit 0)
          (do (trace "schedule" "scheduling " label.routine* " for further processing (limit)")
              ; stop the clock and debit the time on it from the routine
              (-- rep.routine*!limit (- curr-cycle* rep.routine*!running-since))
              (wipe rep.routine*!running-since)
              (if (<= rep.routine*!limit 0)
                (do (trace "schedule" "routine ran out of time")
                    (push routine* completed-routines*))
                (enq routine* running-routines*)))
        :else
          (err "illegal scheduler state"))
    (= routine* nil))
  (each (routine _) routine-canon.sleeping-routines*
    (when (aand rep.routine!limit (<= it (- curr-cycle* rep.routine!running-since)))
      (trace "schedule" "routine timed out")
      (wipe sleeping-routines*.routine)
      (push routine completed-routines*)
;?       (tr completed-routines*)
      ))
  (each (routine _) routine-canon.sleeping-routines*
    (when (ready-to-wake-up routine)
      (trace "schedule" "waking up " label.routine)
      (wipe sleeping-routines*.routine)  ; do this before modifying routine
      (wipe rep.routine!sleep)
      (++ pc.routine)
      (enq routine running-routines*)))
  ; optimization for simulated time
  (when (empty running-routines*)
    (whenlet exact-sleeping-routines (keep waiting-for-exact-cycle? keys.sleeping-routines*)
      (let next-wakeup-cycle (apply min (map [rep._!sleep 1] exact-sleeping-routines))
        (= curr-cycle* (+ 1 next-wakeup-cycle)))
      (trace "schedule" "skipping to cycle " curr-cycle*)
      (update-scheduler-state)))
  (when (and (or (~empty running-routines*)
                 (~empty sleeping-routines*))
             (all [rep._ 'helper] (as cons running-routines*))
             (all [rep._ 'helper] keys.sleeping-routines*))
    (trace "schedule" "just helpers left; stopping everything")
    (until (empty running-routines*)
      (push (deq running-routines*) completed-routines*))
    (each (routine _) sleeping-routines*
;?       (prn " " label.routine) ;? 0
      (wipe sleeping-routines*.routine)
      (push routine completed-routines*)))
  (detect-deadlock)
  )

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
  (tr "die: " msg)
  (= rep.routine*!error msg)
  (iflet abort-continuation (abort-routine*)
    (abort-continuation)))

;; running a single routine

; value of an arg or oarg, stripping away all metadata
; wish I could have this flag an error when arg is incorrectly formed
(mac v (operand)  ; for value
  `((,operand 0) 0))

; routines consist of instrs
; instrs consist of oargs, op and args
(def parse-instr (instr)
  (iflet delim (pos '<- instr)
    (do (when (atom (instr (+ delim 1)))
          (err "operator not tokenized in @instr; maybe you need to freeze functions*?"))
        (list (cut instr 0 delim)  ; oargs
              (v (instr (+ delim 1)))  ; op
              (cut instr (+ delim 2))))  ; args
    (list nil (v car.instr) cdr.instr)))

(def metadata (operand)
  cdr.operand)

(def ty (operand)
  (cdr operand.0))

(def literal? (operand)
  (unless (acons ty.operand)
    (err "no type in operand @operand"))
  (in ty.operand.0 'literal 'offset 'fn))

(def typeinfo (operand)
  (or (type* ty.operand.0)
      (err "unknown type @(tostring prn.operand)")))

; operand accessors
(def nondummy (operand)  ; precondition for helpers below
  (~is '_ operand))

; just for convenience, 'new' instruction sometimes takes a raw string and
; allocates just enough space to store it
(def not-raw-string (operand)
  (~isa operand 'string))

(def address? (operand)
  (or (is ty.operand.0 'location)
      typeinfo.operand!address))

($:require "charterm/main.rkt")
($:require graphics/graphics)
;? ($:require "terminal-color/terminal-color/main.rkt") ;? 1
(= Viewport nil)
; http://rosettacode.org/wiki/Terminal_control/Coloured_text#Racket
($:define (tput . xs) (system (apply ~a 'tput " " (add-between xs " "))) (void))
($:define (foreground color) (tput 'setaf color))
($:define (background color) (tput 'setab color))
($:define (reset) (tput 'sgr0))

(= new-string-foo* nil)

; run instructions from 'routine*' for 'time-slice'
(def run-for-time-slice (time-slice)
  (point return
    (for ninstrs 0 (< ninstrs time-slice) (++ ninstrs)
      (if (empty body.routine*) (err "@stack.routine*.0!fn-name not defined"))
      ; falling out of end of function = implicit reply
      (while (>= pc.routine* (len body.routine*))
        (pop-stack routine*)
        (if empty.routine* (return ninstrs))
        (when (pos '<- (body.routine* pc.routine*))
          (die "No results returned: @(tostring:pr (body.routine* pc.routine*))"))
        (++ pc.routine*))
      (++ curr-cycle*)
;?       (trace "run" "-- " int-canon.memory*) ;? 1
;?       (trace "run" curr-cycle*)
      (trace "run" label.routine* " " pc.routine* ": " (body.routine* pc.routine*))
;?       (trace "run" routine*)
      (when (atom (body.routine* pc.routine*))  ; label
;?         (tr "label") ;? 1
        (when (aand scheduler-switch-table*
                    (alref it (body.routine* pc.routine*)))
          (++ pc.routine*)
          (trace "run" label.routine* " " pc.routine* ": " "context-switch forced " abort-routine*)
          ((abort-routine*)))
        (++ pc.routine*)
        (continue))
      (let (oarg op arg)  (parse-instr (body.routine* pc.routine*))
;?         (tr op) ;? 1
        (let results
              (case op
                ; arithmetic
                add
                  (+ (m arg.0) (m arg.1))
                subtract
                  (- (m arg.0) (m arg.1))
                multiply
                  (* (m arg.0) (m arg.1))
                divide
                  (/ (real (m arg.0)) (m arg.1))
                divide-with-remainder
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
                equal
;?                   (do (prn (m arg.0) " vs " (m arg.1))
                  (is (m arg.0) (m arg.1))
;?                   )
                not-equal
                  (~is (m arg.0) (m arg.1))
                less-than
                  (< (m arg.0) (m arg.1))
                greater-than
                  (> (m arg.0) (m arg.1))
                lesser-or-equal
                  (<= (m arg.0) (m arg.1))
                greater-or-equal
                  (>= (m arg.0) (m arg.1))

                ; control flow
                jump
                  (do (= pc.routine* (+ 1 pc.routine* (v arg.0)))
                      (continue))
                jump-if
                  (when (m arg.0)
                    (= pc.routine* (+ 1 pc.routine* (v arg.1)))
                    (continue))
                jump-unless  ; convenient helper
                  (unless (m arg.0)
                    (= pc.routine* (+ 1 pc.routine* (v arg.1)))
                    (continue))

                ; data management: scalars, arrays, and-records (structs)
                copy
                  (m arg.0)
                get
                  (with (operand  (canonize arg.0)
                         idx  (v arg.1))
                    (assert (iso '(offset) (ty arg.1)) "record index @arg.1 must have type 'offset'")
                    (assert (< -1 idx (len typeinfo.operand!elems)) "@idx is out of bounds of record @operand")
                    (m `((,(apply + v.operand
                                    (map (fn(x) (sizeof `((_ ,@x))))
                                         (firstn idx typeinfo.operand!elems)))
                          ,@typeinfo.operand!elems.idx)
                         (raw))))
                get-address
                  (with (operand  (canonize arg.0)
                         idx  (v arg.1))
                    (assert (iso '(offset) (ty arg.1)) "record index @arg.1 must have type 'offset'")
                    (assert (< -1 idx (len typeinfo.operand!elems)) "@idx is out of bounds of record @operand")
                    (apply + v.operand
                             (map (fn(x) (sizeof `((_ ,@x))))
                                  (firstn idx typeinfo.operand!elems))))
                index
                  (withs (operand  (canonize arg.0)
                          elemtype  typeinfo.operand!elem
                          idx  (m arg.1))
;?                     (write arg.0)
;?                     (pr " => ")
;?                     (write operand)
;?                     (prn)
                    (unless (< -1 idx array-len.operand)
                      (die "@idx is out of bounds of array @operand"))
                    (m `((,(+ v.operand
                              1  ; for array size
                              (* idx (sizeof `((_ ,@elemtype)))))
                           ,@elemtype)
                         (raw))))
                index-address
                  (withs (operand  (canonize arg.0)
                          elemtype  typeinfo.operand!elem
                          idx  (m arg.1))
                    (unless (< -1 idx array-len.operand)
                      (die "@idx is out of bounds of array @operand"))
                    (+ v.operand
                       1  ; for array size
                       (* idx (sizeof `((_ ,@elemtype))))))
                new
                  (if (isa arg.0 'string)
                    ; special-case: allocate space for a literal string
                    (new-string arg.0)
                    (let type (v arg.0)
                      (assert (iso '(literal) (ty arg.0)) "new: second arg @arg.0 must be literal")
                      (if (no type*.type)  (err "no such type @type"))
                      ; todo: initialize memory. currently racket does it for us
                      (if type*.type!array
                        (new-array type (m arg.1))
                        (new-scalar type))))
                sizeof
                  (sizeof `((_ ,(m arg.0))))
                length
                  (let base arg.0
                    (if (or typeinfo.base!array address?.base)
                      array-len.base
                      -1))

                ; tagged-values require one primitive
                save-type
                  (annotate 'record `(,((ty arg.0) 0) ,(m arg.0)))

                ; code points for characters
                character-to-integer
                  ($.char->integer (m arg.0))
                integer-to-character
                  ($.integer->char (m arg.0))

                ; multiprocessing
                fork
                  ; args: fn globals-table args ...
                  (let routine  (apply make-routine (m arg.0) (map m (nthcdr 3 arg)))
                    (= rep.routine!id ++.next-routine-id*)
                    (= rep.routine!globals (when (len> arg 1) (m arg.1)))
                    (= rep.routine!limit (when (len> arg 2) (m arg.2)))
                    (enq routine running-routines*)
                    rep.routine!id)
                fork-helper
                  ; args: fn globals-table args ...
                  (let routine  (apply make-routine (m arg.0) (map m (nthcdr 3 arg)))
                    (= rep.routine!id ++.next-routine-id*)
                    (set rep.routine!helper)
                    (= rep.routine!globals (when (len> arg 1) (m arg.1)))
                    (= rep.routine!limit (when (len> arg 2) (m arg.2)))
                    (enq routine running-routines*)
                    rep.routine!id)
                sleep
                  (do
                    (case (v arg.0)
                      for-some-cycles
                        (let wakeup-time (+ curr-cycle* (v arg.1))
                          (trace "run" label.routine* " " pc.routine* ": " "sleeping until " wakeup-time)
                          (= rep.routine*!sleep `(until ,wakeup-time)))
                      until-location-changes
                        (= rep.routine*!sleep `(until-location-changes ,(addr arg.1) ,(m arg.1)))
                      until-routine-done
                        (= rep.routine*!sleep `(until-routine-done ,(m arg.1)))
                      ; else
                        (die "badly formed 'sleep' call @(tostring:prn (body.routine* pc.routine*))")
                      )
                    ((abort-routine*)))
                assert
                  (unless (m arg.0)
                    (die (v arg.1)))  ; other routines will be able to look at the error status
                assert-false
                  (when (m arg.0)
                    (die (v arg.1)))

                ; cursor-based (text mode) interaction
                cursor-mode
                  ;(do1 nil (system "/bin/stty -F /dev/tty raw"))
                  (do1 nil (if (no ($.current-charterm)) ($.open-charterm)))
                retro-mode
                  ;(do1 nil (system "/bin/stty -F /dev/tty sane"))
                  (do1 nil (if ($.current-charterm) ($.close-charterm)))
                clear-host-screen
                  (do1 nil (pr "\e[m\e[2J\e[;H"))
                clear-line-on-host
                  (do1 nil (pr "\e[2K"))
                cursor-on-host
                  (do1 nil (pr (+ "\e[" (m arg.0) ";" (m arg.1) "H")))
                cursor-on-host-to-next-line
                  (do1 nil (pr "\r\n"))
                cursor-up-on-host
                  (do1 nil (pr (+ "\e[" (aif (len> arg 0) (or m arg.0) 1) "A")))
                cursor-down-on-host
                  (do1 nil (pr (+ "\e[" (aif (len> arg 0) (or m arg.0) 1) "B")))
                cursor-right-on-host
                  (do1 nil (pr (+ "\e[" (aif (len> arg 0) (or m arg.0) 1) "C")))
                cursor-left-on-host
                  (do1 nil (pr (+ "\e[" (aif (len> arg 0) (or m arg.0) 1) "D")))
                print-character-to-host
                  (do1 nil
                       (assert (in (type:m arg.0) 'char 'sym) (rep (m arg.0)))
;?                        (write (m arg.0))  (pr " => ")  (prn (type (m arg.0)))
                       (if (no ($.current-charterm))
                         (pr (m arg.0))
                         (caselet x (m arg.0)
                           ; todo: test these exceptions
                           #\newline
                             (pr "\r\n")
                           #\backspace
                             ; backspace doesn't clear after moving the cursor
                             (pr "\b \b")
                           ctrl-c
                             (do ($.close-charterm)
                                 (die "interrupted"))
                           ;else
                             (if (and (len> arg 2)
                                      (m arg.2))
                                   (do
                                     ($.foreground (m arg.1))
                                     ($.background (m arg.2))
                                     (pr x)
                                     ($.reset))
                                 (and (len> arg 1)
                                      (m arg.1))
                                   (do
                                     ($.foreground (m arg.1))
                                     (pr x)
                                     ($.reset))
                                 :else
                                   (pr x))))
                       )
                read-key-from-host
                  (if ($.current-charterm)
                        (and ($.charterm-byte-ready?)
                             (ret result ($.charterm-read-key)
                               (case result
                                 ; charterm exceptions
                                 return
                                   (= result #\newline)
                                 backspace
                                   (= result #\backspace)
                                 )))
                      ($.graphics-open?)
                        ($.ready-key-press Viewport))

                ; graphics
                window-on
                  (do1 nil
                    ($.open-graphics)
                    (= Viewport ($.open-viewport (m arg.0)  ; name
                                                 (m arg.1) (m arg.2))))  ; width height
                window-off
                  (do1 nil
                    ($.close-viewport Viewport)  ; why doesn't this close the window? works in naked racket. not racket vs arc.
                    ($.close-graphics)
                    (= Viewport nil))
                mouse-position
                  (aif ($.ready-mouse-click Viewport)
                    (let posn ($.mouse-click-posn it)
                      (list (annotate 'record (list ($.posn-x posn) ($.posn-y posn))) t))
                    (list nil nil))
                wait-for-mouse
                  (let posn ($.mouse-click-posn ($.get-mouse-click Viewport))
                    (list (annotate 'record (list ($.posn-x posn) ($.posn-y posn))) t))
                ; clear-screen in cursor mode above
                rectangle
                  (do1 nil
                    (($.draw-solid-rectangle Viewport)
                        ($.make-posn (m arg.0) (m arg.1))  ; origin
                        (m arg.2)  (m arg.3)  ; width height
                        (m arg.4)))  ; color
                point
                  (do1 nil
                    (($.draw-pixel Viewport) ($.make-posn (m arg.0) (m arg.1))
                                             (m arg.2)))  ; color

                image
                  (do1 nil
                    (($.draw-pixmap Viewport) (m arg.0)  ; filename
                                              ($.make-posn (m arg.1) (m arg.2))))
                color-at
                  (let pixel (($.get-color-pixel Viewport) ($.make-posn (m arg.0) (m arg.1)))
                    (prn ($.rgb-red pixel) " " ($.rgb-blue pixel) " " ($.rgb-green pixel))
                    ($:rgb-red pixel))

                ; debugging aides
                $dump-memory
                  (do1 nil
                    (prn:repr int-canon.memory*))
                $dump-trace
                  (tofile arg.0
                    (each (label trace) (as cons traces*)
                      (pr label ": " trace)))
                $start-tracing
                  (do1 nil
                    (set dump-trace*))
                $stop-tracing
                  (do1 nil
                    (wipe dump-trace*))
                $dump-routine
                  (do1 nil
                    ($.close-charterm)
                    (prn routine*)
                    ($.open-charterm)
                    )
                $dump-channel
                  (do1 nil
                    ($.close-charterm) ;? 1
                    (withs (x (m arg.0)
                            y (memory* (+ x 2)))
                      (prn label.routine* " -- " x " -- " (list (memory* x)
                                                                (memory* (+ x 1))
                                                                (memory* (+ x 2)))
                                                   " -- " (list (memory* y)
                                                                (memory* (+ y 1))
                                                                (repr:memory* (+ y 2))
                                                                (memory* (+ y 3))
                                                                (repr:memory* (+ y 4)))))
                    ($.open-charterm) ;? 1
                    )
                $quit
                  (quit)
                $wait-for-key-from-host
                  (when ($.current-charterm)
                    (ret result ($.charterm-read-key)
                      (case result
                        ; charterm exceptions
                        return
                          (= result #\newline)
                        backspace
                          (= result #\backspace)
                        )))
                $print
                  (do1 nil
;?                        (write (m arg.0))  (pr " => ")  (prn (type (m arg.0)))
                       (if (no ($.current-charterm))
                         (pr (m arg.0))
                         (unless disable-debug-prints-in-console-mode*
                           (caselet x (m arg.0)
                             #\newline
                               (pr "\r\n")
                             #\backspace
                               ; backspace doesn't clear after moving the cursor
                               (pr "\b \b")
                             ctrl-c
                               (do ($.close-charterm)
                                   (die "interrupted"))
                             ;else
                               (pr x)))
                          ))
                $write
                  (do1 nil
                    (write (m arg.0)))
                $eval
                  (new-string:repr:eval:read:to-arc-string (m arg.0))
;?                   (let x (to-arc-string (m arg.0)) ;? 1
;?                     (prn x) ;? 1
;?                     (new-string:repr:eval x)) ;? 1

                $clear-trace
                  (do1 nil (wipe interactive-traces*))
                $save-trace
                  (let x (filter-log "CCC: " len
                         (string
                           (filter-log "BBB: " len
                           (map [string:intersperse ": " _]
                                (filter-log "AAA: " len
                                (as cons (interactive-traces* (m arg.0)))))
                                )))
;?                   (let x (string:map [string:intersperse ": " _]
;?                                      (apply join
;?                                             (map [as cons _] rev.interactive-traces*)))
                    (prn "computed trace; now saving to memory\n")
;?                     (write x)(write #\newline) ;? 1
;?                     (prn x) ;? 1
                    (set new-string-foo*)
                    (do1 (new-string x)
                      (wipe new-string-foo*)))

                ; first-class continuations
                current-continuation
                  (w/uniq continuation-name
                    (trace "continuation" "saving @(repr rep.routine*!call-stack) to @continuation-name")
                    (= continuation*.continuation-name (copy rep.routine*!call-stack))
                    continuation-name)
                continue-from
                  (let continuation-name (m arg.0)
                    (trace "continuation" "restoring @continuation-name")
                    (trace "continuation" continuation*.continuation-name)
                    (= rep.routine*!call-stack continuation*.continuation-name)
                    (trace "continuation" "call stack is now @(repr rep.routine*!call-stack)")
;?                     (++ pc.routine*) ;? 1
                    (continue))
;?                     ((abort-routine*))) ;? 1

                ; user-defined functions
                next-input
                  (let idx caller-arg-idx.routine*
                    (++ caller-arg-idx.routine*)
                    (trace "arg" repr.arg " " idx " " (repr caller-args.routine*))
                    (if (len> caller-args.routine* idx)
                      (list caller-args.routine*.idx t)
                      (list nil nil)))
                input
                  (do (assert (iso '(literal) (ty arg.0)))
                      (= caller-arg-idx.routine* (v arg.0))
                      (let idx caller-arg-idx.routine*
                        (++ caller-arg-idx.routine*)
                        (trace "arg" repr.arg " " idx " " (repr caller-args.routine*))
                        (if (len> caller-args.routine* idx)
                          (list caller-args.routine*.idx t)
                          (list nil nil))))
                ; type and otype won't always easily compile. be careful.
                type
                  (ty (caller-operands.routine* (v arg.0)))
                otype
                  (ty (caller-results.routine* (v arg.0)))
                prepare-reply
                  (prepare-reply arg)
                reply
                  (do (when arg
                        (prepare-reply arg))
                      (with (results results.routine*
                             reply-args reply-args.routine*)
                        (pop-stack routine*)
                        (if empty.routine* (return ninstrs))
                        (let (call-oargs _ call-args)  (parse-instr (body.routine* pc.routine*))
;?                           (trace "reply" repr.arg " " repr.call-oargs) ;? 1
                          (each (dest reply-arg val)  (zip call-oargs reply-args results)
                            (trace "run" label.routine* " " pc.routine* ": " repr.val " => " dest)
                            (when nondummy.dest
                              (whenlet argidx (alref metadata.reply-arg 'same-as-arg)
                                (unless (is v.dest (v call-args.argidx))
                                  (die "'same-as-arg' output arg in @repr.reply-args can't bind to @repr.call-oargs")))
                              (setm dest val))))
                        (++ pc.routine*)
                        (while (>= pc.routine* (len body.routine*))
                          (pop-stack routine*)
                          (when empty.routine* (return ninstrs))
                          (++ pc.routine*))
                        (continue)))
                ; else try to call as a user-defined function
                  (do (if function*.op
                        (with (callee-args (accum yield
                                             (each a arg
                                               (yield (m a))))
                               callee-operands (accum yield
                                                 (each a arg
                                                   (yield a)))
                               callee-results (accum yield
                                                (each a oarg
                                                  (yield a))))
                          (push-stack routine* op)
                          (= caller-args.routine* callee-args)
                          (= caller-operands.routine* callee-operands)
                          (= caller-results.routine* callee-results))
                        (err "no such op @op"))
                      (continue))
                )
              ; opcode generated some 'results'
              ; copy to output args
              (if (acons results)
                (each (dest val) (zip oarg results)
                  (unless (is dest '_)
                    (trace "run" label.routine* " " pc.routine* ": " repr.val " => " dest)
                    (setm dest val)))
                (when oarg  ; must be a list
                  (trace "run" label.routine* " " pc.routine* ": " repr.results " => " oarg.0)
                  (setm oarg.0 results)))
              )
        (++ pc.routine*)))
    (return time-slice)))

(def prepare-reply (args)
  (= results.routine*
     (accum yield
       (each a args
         (yield (m a)))))
  (= reply-args.routine* args))

; helpers for memory access respecting
;   immediate addressing - 'literal' and 'offset'
;   direct addressing - default
;   indirect addressing - 'deref'
;   relative addressing - if routine* has 'default-space'

(def m (loc)  ; read memory, respecting metadata
  (point return
    (when (literal? loc)
      (return v.loc))
    (when (is v.loc 'default-space)
      (return rep.routine*!call-stack.0!default-space))
;?     (trace "mem" loc) ;? 1
    (assert (isa v.loc 'int) "addresses must be numeric (problem in convert-names?): @repr.loc")
    (ret result
      (with (n  sizeof.loc
             addr  addr.loc)
;?         (trace "mem" "reading " n " locations starting at " addr) ;? 1
        (if (is 1 n)
              memory*.addr
            :else
              (annotate 'record
                        (map memory* (addrs addr n)))))
      (trace "mem" loc " => " result))))

(def setm (loc val)  ; set memory, respecting metadata
;?   (tr 111)
  (point return
;?   (tr 112)
    (when (is v.loc 'default-space)
      (assert (is 1 sizeof.loc) "can't store compounds in default-space @loc")
      (= rep.routine*!call-stack.0!default-space val)
      (return))
;?   (tr 120)
    (assert (isa v.loc 'int) "can't store to non-numeric address (problem in convert-names?)")
;?     (trace "mem" loc " <= " repr.val) ;? 1
    (with (n  (if (isa val 'record) (len rep.val) 1)
           addr  addr.loc
           typ  typeof.loc)
;?       (trace "mem" "size of " loc " is " n) ;? 1
      (assert n "setm: can't compute type of @loc")
      (assert addr "setm: null pointer @loc")
      (if (is 1 n)
        (do (assert (~isa val 'record) "setm: record of size 1 @(tostring prn.val)")
            (trace "mem" loc ": " addr " <= " repr.val)
            (= memory*.addr val))
        (do (if type*.typ!array
              ; size check for arrays
              (when (~is n
                         (+ 1  ; array length
                            (* rep.val.0 (sizeof `((_ ,@type*.typ!elem))))))
                (die "writing invalid array @(tostring prn.val)"))
              ; size check for non-arrays
              (when (~is sizeof.loc n)
                (die "writing to incorrect size @(tostring pr.val) => @loc")))
            (let addrs (addrs addr n)
              (each (dest src) (zip addrs rep.val)
                (trace "mem" loc ": " dest " <= " repr.src)
                (= memory*.dest src))))))))

(def typeof (operand)
  (let loc absolutize.operand
    (while (pos '(deref) metadata.loc)
      (zap deref loc))
    ty.loc.0))

(def addr (operand)
  (v canonize.operand))

(def addrs (n sz)
  (accum yield
    (repeat sz
      (yield n)
      (++ n))))

(def canonize (operand)
;?   (tr "0: @operand")
  (ret operand
;?     (prn "1: " operand)
;?     (tr "1: " operand)  ; todo: why does this die?
    (zap absolutize operand)
;?     (tr "2: @repr.operand")
    (while (pos '(deref) metadata.operand)
      (zap deref operand)
;?       (tr "3: @repr.operand")
      )))

(def array-len (operand)
  (trace "array-len" operand)
  (zap canonize operand)
  (if typeinfo.operand!array
        (m `((,v.operand integer) ,@metadata.operand))
      :else
        (err "can't take len of non-array @operand")))

(def sizeof (x)
;?   (trace "sizeof" x) ;? 1
  (assert acons.x)
  (zap canonize x)
  (point return
;?   (tr "sizeof: checking @x for array")
  (when typeinfo.x!array
;?     (tr "sizeof: @x is an array")
    (assert (~is '_ v.x) "sizeof: arrays require a specific variable")
    (return (+ 1 (* array-len.x (sizeof `((_ ,@typeinfo.x!elem)))))))
;?   (tr "sizeof: not an array")
  (when typeinfo.x!and-record
;?     (tr "sizeof: @x is an and-record")
    (return (sum idfn
                 (accum yield
                   (each elem typeinfo.x!elems
                     (yield (sizeof `((_ ,@elem)))))))))
;?   (tr "sizeof: @x is a primitive")
  (return typeinfo.x!size)))

(def absolutize (operand)
  (if (no routine*)
        operand
      (in v.operand '_ 'default-space)
        operand
      (pos '(raw) metadata.operand)
        operand
      (is 'global space.operand)
        (aif rep.routine*!globals
          `((,(+ it 1 v.operand) ,@(cdr operand.0))
            ,@(rem [caris _ 'space] metadata.operand)
            (raw))
          (die "routine has no globals: @operand"))
      :else
        (iflet base rep.routine*!call-stack.0!default-space
          (lookup-space (rem [caris _ 'space] operand)
                        base
                        space.operand)
          operand)))

(def lookup-space (operand base space)
;?   (prn operand " " base) ;? 1
  (if (is 0 space)
    ; base case
    (if (< v.operand memory*.base)
      `((,(+ base 1 v.operand) ,@(cdr operand.0))
        ,@metadata.operand
        (raw))
      (die "no room for var @operand in routine of size @memory*.base"))
    ; recursive case
    (lookup-space operand (memory* (+ base 1))  ; location 0 points to next space
                  (- space 1))))

(def space (operand)
  (or (alref metadata.operand 'space)
      0))

(def deref (operand)
  (assert (pos '(deref) metadata.operand))
  (assert address?.operand)
  (cons `(,(memory* v.operand) ,@typeinfo.operand!elem)
        (drop-one '(deref) metadata.operand)))

(def drop-one (f x)
  (when acons.x  ; proper lists only
    (if (testify.f car.x)
      cdr.x
      (cons car.x (drop-one f cdr.x)))))

; memory allocation

(def alloc (sz)
  (when (> sz (- rep.routine*!alloc-max rep.routine*!alloc))
    (let curr-alloc Memory-allocated-until
      (= rep.routine*!alloc curr-alloc)
      (++ Memory-allocated-until Allocation-chunk)
      (= rep.routine*!alloc-max Memory-allocated-until)))
  (ret result rep.routine*!alloc
    (++ rep.routine*!alloc sz)))

(def new-scalar (type)
;?   (tr "new scalar: @type")
  (alloc (sizeof `((_ ,type)))))

(def new-array (type size)
;?   (tr "new array: @type @size")
  (ret result (alloc (+ 1 (* (sizeof `((_ ,@type*.type!elem))) size)))
    (= memory*.result size)))

(def new-string (literal-string)
;?   (tr "new string: @literal-string")
  (ret result (alloc (+ 1 len.literal-string))
    (= memory*.result len.literal-string)
    (on c literal-string
      (when (and new-string-foo* (is 0 (mod index 100)))
        (prn index " " repr.c))
      (= (memory* (+ result 1 index)) c))))

(def to-arc-string (string-address)
  (let len (memory* string-address)
    (string:map memory* (range (+ string-address 1)
                               (+ string-address len)))))

;; desugar structured assembly based on blocks

(def convert-braces (instrs)
;?   (prn "convert-braces " instrs)
  (let locs ()  ; list of information on each brace: (open/close pc)
    (let pc 0
      (loop (instrs instrs)
        (each instr instrs
;?           (tr instr)
          (if (or atom.instr (~is 'begin instr.0))  ; label or regular instruction
                (do
                  (trace "c{0" pc " " instr " -- " locs)
                  (++ pc))
                ; hack: racket replaces braces with parens, so we need the
                ; keyword 'begin' to delimit blocks.
                ; ultimately there'll be no nesting and braces will just be
                ; in an instr by themselves.
              :else  ; brace
                (do
                  (push `(open ,pc) locs)
                  (recur cdr.instr)
                  (push `(close ,pc) locs))))))
    (zap rev locs)
;?     (tr "-")
    (with (pc  0
           stack  ())  ; elems are pcs
      (accum yield
        (loop (instrs instrs)
          (each instr instrs
;?             (tr "- " instr)
            (point continue
            (when (atom instr)  ; label
              (yield instr)
              (++ pc)
              (continue))
            (when (is car.instr 'begin)
              (push pc stack)
              (recur cdr.instr)
              (pop stack)
              (continue))
            (with ((oarg op arg)  (parse-instr instr)
                   yield-new-instr  (fn (new-instr)
                                      (trace "c{1" "@pc X " instr " => " new-instr)
                                      (yield new-instr))
                   yield-unchanged  (fn ()
                                      (trace "c{1" "@pc ✓ " instr)
                                      (yield instr)))
              (when (in op 'break 'break-if 'break-unless 'loop 'loop-if 'loop-unless)
                (assert (is oarg nil) "@op: can't take oarg in @instr"))
              (case op
                break
                  (yield-new-instr `(((jump)) ((,(close-offset pc locs (and arg (v arg.0))) offset))))
                break-if
                  (yield-new-instr `(((jump-if)) ,arg.0 ((,(close-offset pc locs (and cdr.arg (v arg.1))) offset))))
                break-unless
                  (yield-new-instr `(((jump-unless)) ,arg.0 ((,(close-offset pc locs (and cdr.arg (v arg.1))) offset))))
                loop
                  (yield-new-instr `(((jump)) ((,(open-offset pc stack (and arg (v arg.0))) offset))))
                loop-if
                  (yield-new-instr `(((jump-if)) ,arg.0 ((,(open-offset pc stack (and cdr.arg (v arg.1))) offset))))
                loop-unless
                  (yield-new-instr `(((jump-unless)) ,arg.0 ((,(open-offset pc stack (and cdr.arg (v arg.1))) offset))))
                ;else
                  (yield-unchanged)))
            (++ pc))))))))

(def close-offset (pc locs nblocks)
  (or= nblocks 1)
;?   (tr nblocks)
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
      (when (is stacksize (* -1 nblocks))
;?         (tr "close now " loc)
        (return (- loc pc 1))))))))

(def open-offset (pc stack nblocks)
  (or= nblocks 1)
  (- (stack (- nblocks 1)) 1 pc))

;; convert jump targets to offsets

(def convert-labels (instrs)
;?   (tr "convert-labels " instrs)
  (let labels (table)
    (let pc 0
      (each instr instrs
        (when (~acons instr)
;?           (tr "label " pc)
          (= labels.instr pc))
        (++ pc)))
    (let pc 0
      (each instr instrs
        (when (and acons.instr
                   (acons car.instr)
                   (in (v car.instr) 'jump 'jump-if 'jump-unless))
          (each arg cdr.instr
;?             (tr "trying " arg " " ty.arg ": " v.arg " => " (labels v.arg))
            (when (and (is ty.arg.0 'offset)
                       (isa v.arg 'sym)
                       (labels v.arg))
              (= v.arg (- (labels v.arg) pc 1)))))
        (++ pc))))
  instrs)

;; convert symbolic names to raw memory locations

(def add-next-space-generator (instrs name)
;?   (prn "== @name")
  (each instr instrs
    (when acons.instr
      (let (oargs op args)  (parse-instr instr)
        (each oarg oargs
          (when (and (nondummy oarg)
                     (is v.oarg 0)
                     (iso ty.oarg '(space-address)))
            (assert (or (no next-space-generator*.name)
                        (is next-space-generator*.name (alref oarg 'names)))
                    "function can have only one next-space-generator environment")
            (tr "next-space-generator of @name is @(alref oarg 'names)")
            (= next-space-generator*.name (alref oarg 'names))))))))

; just a helper for testing; in practice we unbundle assign-names-to-location
; and replace-names-with-location.
(def convert-names (instrs (o name))
;?   (tr "convert-names " instrs)
  (= location*.name (assign-names-to-location instrs name))
;?   (tr "save names for function @name: @(tostring:pr location*.name)") ;? 1
  (replace-names-with-location instrs name))

(def assign-names-to-location (instrs name (o init-locations))
  (trace "cn0" "convert-names in @name")
;?   (prn name ": " location*) ;? 1
  (point return
  (ret location (or init-locations (table))
    ; if default-space in first instruction has a name, begin with its bindings
    (when (acons instrs.0)  ; not a label
      (let first-oarg-of-first-instr instrs.0.0  ; hack: assumes the standard default-space boilerplate
        (when (and (nondummy first-oarg-of-first-instr)
                   (is 'default-space (v first-oarg-of-first-instr))
                   (assoc 'names metadata.first-oarg-of-first-instr))
          (let old-names (location*:alref metadata.first-oarg-of-first-instr 'names)
            (unless old-names
;?               (prn "@name requires bindings for @(alref metadata.first-oarg-of-first-instr 'names) which aren't computed yet. Waiting.") ;? 1
              (return nil))
            (= location copy.old-names))))) ; assumption: we've already converted names for 'it'
;?     (unless empty.location (prn location)) ;? 2
    (with (isa-field  (table)
           idx  (+ 1  ; 0 always reserved for next space
                   (or (apply max vals.location)  ; skip past bindings already shared from elsewhere
                       0))
           already-location (copy location)
           )
      (each instr instrs
        (point continue
        (when atom.instr
          (continue))
        (trace "cn0" instr " " canon.location " " canon.isa-field)
        (let (oargs op args)  (parse-instr instr)
;?           (tr "about to rename args: @op")
          (when (in op 'get 'get-address)
            ; special case: map field offset by looking up type table
            (with (basetype  (typeof args.0)
                   field  (v args.1))
;?               (tr 111 " " args.0 " " basetype)
              (assert type*.basetype!and-record "get on non-record @args.0")
;?               (tr 112)
              (trace "cn0" "field-access @field in @args.0 of type @basetype")
              (when (isa field 'sym)
                (unless (already-location field)
                  (assert (or (~location field) isa-field.field) "field @args.1 is also a variable"))
                (when (~location field)
                  (trace "cn0" "new field; computing location")
;?                   (tr "aa " type*.basetype)
                  (assert type*.basetype!fields "no field names available for @instr")
;?                   (tr "bb")
                  (iflet idx (pos field type*.basetype!fields)
                    (do (set isa-field.field)
                        (trace "cn0" "field location @idx")
                        (= location.field idx))
                    (assert nil "couldn't find field in @instr"))))))
          ; map args to location indices
          (each arg args
            (trace "cn0" "checking arg " arg)
            (when (and nondummy.arg not-raw-string.arg (~literal? arg))
              (assert (~isa-field v.arg) "arg @arg is also a field name")
              (when (maybe-add arg location idx)
                ; todo: test this
                (err "use before set: @arg"))))
;?           (tr "about to rename oargs")
          ; map oargs to location indices
          (each arg oargs
            (trace "cn0" "checking oarg " arg)
            (when (and nondummy.arg not-raw-string.arg)
              (assert (~isa-field v.arg) "oarg @arg is also a field name")
              (when (maybe-add arg location idx)
                (trace "cn0" "location for oarg " arg ": " idx)
                ; todo: can't allocate arrays on the stack
                (++ idx (sizeof `((_ ,@ty.arg))))))))))))))

(def replace-names-with-location (instrs name)
  (each instr instrs
    (when (acons instr)
      (let (oargs op args)  (parse-instr instr)
        (each arg args
          (convert-name arg name))
        (each arg oargs
          (convert-name arg name)))))
  (each instr instrs
    (trace "cn1" instr))
  instrs)

(= allow-raw-addresses* nil)
(def check-default-space (instrs name)
  (unless allow-raw-addresses*
    (let oarg-names (accum yield
                      (each (oargs _ _) (map parse-instr (keep acons  ; non-label
                                                               instrs))
                        (each oarg oargs
                          (when nondummy.oarg
                            (yield v.oarg)))))
      (when (~pos 'default-space oarg-names)
        (prn "function @name has no default-space")))))

; assign an index to an arg
(def maybe-add (arg location idx)
  (trace "maybe-add" arg)
  (when (and nondummy.arg
;?              (prn arg " " (assoc 'space arg))
             (~assoc 'space arg)
             (~literal? arg)
             (~location v.arg)
             (isa v.arg 'sym)
             (~in v.arg 'nil 'default-space)
             (~pos '(raw) metadata.arg))
    (= (location v.arg) idx)))

; convert the arg to corresponding index
(def convert-name (arg default-name)
;?   (prn "111 @arg @default-name")
  (when (and nondummy.arg not-raw-string.arg
             (~is ty.arg.0 'literal))  ; can't use 'literal?' because we want to rename offsets
;?     (prn "112 @arg")
    (let name (space-to-name arg default-name)
;?       (prn "113 @arg @name @keys.location* @(tostring:pr location*.name)")
;?       (when (is arg '((y integer) (space 1)))
;?         (prn "@arg => @name"))
      (when (aand location*.name (it v.arg))
;?         (prn 114)
        (zap location*.name v.arg))
;?       (prn 115)
      )))

(def space-to-name (arg default-name)
  (ret name default-name
    (when (~is space.arg 'global)
      (repeat space.arg
        (zap next-space-generator* name)))))

(proc check-numeric-address (instrs name)
;?   (prn name) ;? 2
  (on instr instrs
;?     (prn instr) ;? 2
    (when acons.instr  ; not a label
      (let (oargs op args)  (parse-instr instr)
        (each arg oargs
;?           (prn " " arg) ;? 2
          (when (and acons.arg  ; not dummy _ or raw string
                     (isa v.arg 'int)
                     (~is v.arg 0)
                     (~pos '(raw) metadata.arg)
                     (~literal? arg))
            (prn "using a raw integer address @arg in @name (instruction #@index)")))
        (each arg args
;?           (prn " " arg) ;? 2
          (when (and acons.arg  ; not dummy _ or raw string
                     (isa v.arg 'int)
                     (~is v.arg 0)
                     (~pos '(raw) metadata.arg)
                     (~literal? arg))
            (prn "using a raw integer address @arg in @name (instruction #@index)")))))))

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
        (if atom.instr  ; label
              (yield instr)
            (is instr.0 'defer)
              nil  ; skip
            (is instr.0 'reply)
              (do
                (when cdr.instr  ; return values
                  (= instr.0 'prepare-reply)
                  (yield instr))
                (each instr (as cons deferred)
                  (yield instr))
                (yield '(reply)))
            :else
              (yield instr)))
      (each instr (as cons deferred)
        (yield instr)))))

(on-init
  (= before* (table))  ; label -> queue of fragments
  (= after* (table)))  ; label -> list of fragments

; see add-code below for adding to before* and after*

(def insert-code (instrs (o name))
;?   (tr "insert-code " instrs)
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

;; loading code into the virtual machine

(def add-code (forms)
  (each (op . rest)  forms
    (case op
      ; function <name> [ <instructions> ]
      ; don't apply our lightweight tools just yet
      function!
        (let (name (_make-br-fn body))  rest
          (assert (is 'make-br-fn _make-br-fn))
          (= name (v tokenize-arg.name))
          (= function*.name body))
      function
        (let (name (_make-br-fn body))  rest
          (assert (is 'make-br-fn _make-br-fn))
          (= name (v tokenize-arg.name))
          (when function*.name
            (prn "adding new clause to @name"))
          (= function*.name (join body function*.name)))

      ; and-record <type> [ <name:types> ]
      and-record
        (let (name (_make-br-fn fields))  rest
          (assert (is 'make-br-fn _make-br-fn))
          (= name (v tokenize-arg.name))
          (let fields (map tokenize-arg fields)
            (= type*.name (obj size len.fields
                               and-record t
                               ; dump all metadata for now except field name and type
                               elems (map cdar fields)
                               fields (map caar fields)))))

      ; primitive <type>
      primitive
        (let (name) rest
          (= name (v tokenize-arg.name))
          (= type*.name (obj size 1)))

      ; address <type> <elem-type>
      address
        (let (name types)  rest
          (= name (v tokenize-arg.name))
          (= type*.name (obj size 1
                             address t
                             elem types)))

      ; array <type> <elem-type>
      array
        (let (name types)  rest
          (= name (v tokenize-arg.name))
          (= type*.name (obj array t
                             elem types)))

      ; before <label> [ <instructions> ]
      ;
      ; multiple before directives => code in order
      before
        (let (label (_make-br-fn fragment))  rest
          (assert (is 'make-br-fn _make-br-fn))
          ; todo: stop using '/' in non-standard manner
          ;(= label (v tokenize-arg.label))
          (or= before*.label (queue))
          (enq fragment before*.label))

      ; after <label> [ <instructions> ]
      ;
      ; multiple after directives => code in *reverse* order
      ; (if initialization order in a function is A B, corresponding
      ; finalization order should be B A)
      after
        (let (label (_make-br-fn fragment))  rest
          (assert (is 'make-br-fn _make-br-fn))
          ; todo: stop using '/' in non-standard manner
          ;(= label (v tokenize-arg.label))
          (push fragment after*.label))

      ;else
        (prn "unrecognized top-level " (cons op rest))
      )))

(def freeze (function-table)
  (each (name body)  canon.function-table
;?     (prn "freeze " name)
    (= function-table.name (convert-labels:convert-braces:tokenize-args:insert-code body name)))
  (each (name body)  canon.function-table
    (check-default-space body name))
  (each (name body)  canon.function-table
    (check-numeric-address body name))
  (each (name body)  canon.function-table
    (add-next-space-generator body name))
  ; keep converting names until none remain
  ; (we need to skip unrecognized spaces)
  (let change t
    (while change
      (= change nil)
      (each (name body)  canon.function-table
;?         (prn name) ;? 1
        (when (no location*.name)
          (= change t))
        (or= location*.name (assign-names-to-location body name)))))
;?   (each (name body)  canon.function-table ;? 1
;?     (or= location*.name (assign-names-to-location body name))) ;? 1
  (each (name body)  canon.function-table
    (= function-table.name (replace-names-with-location body name)))
  ; we could clear location* at this point, but maybe we'll find a use for it
  )

(def freeze-another (fn-name)
  (= function*.fn-name (convert-labels:convert-braces:tokenize-args:insert-code function*.fn-name fn-name))
  (check-default-space function*.fn-name fn-name)
  (add-next-space-generator function*.fn-name fn-name)
  (= location*.fn-name (assign-names-to-location function*.fn-name fn-name location*.fn-name))
  (replace-names-with-location function*.fn-name fn-name))

(def tokenize-arg (arg)
;?   (tr "tokenize-arg " arg)
  (if (in arg '<- '_)
        arg
      (isa arg 'sym)
        (map [map [fromstring _ (read)] _]
             (map [tokens _ #\:]
                  (tokens string.arg #\/)))
      :else
        arg))

(def tokenize-args (instrs)
;?   (tr "tokenize-args " instrs)
;?   (prn2 "@(tostring prn.instrs) => "
  (accum yield
    (each instr instrs
      (if atom.instr
            (yield instr)
          (is 'begin instr.0)
            (yield `{begin ,@(tokenize-args cdr.instr)})
          :else
            (yield (map tokenize-arg instr))))))
;?   )

(def prn2 (msg . args)
  (pr msg)
  (apply prn args))

(def canon (table)
  (sort (compare < [tostring (prn:car _)]) (as cons table)))

(def int-canon (table)
  (sort (compare < car) (as cons table)))

(def routine-canon (routine-table)
  (sort (compare < label:car) (as cons routine-table)))

(def repr (val)
  (tostring write.val))

;; test helpers

(def memory-contains (addr value)
;?   (prn "Looking for @value starting at @addr")
  (loop (addr addr
         idx  0)
;?     (prn "@idx vs @addr")
    (if (>= idx len.value)
          t
        (~is memory*.addr value.idx)
          (do1 nil
               (prn "@addr should contain @value.idx but contains @memory*.addr"))
        :else
          (recur (+ addr 1) (+ idx 1)))))

(def memory-contains-array (addr value)
  (and (>= memory*.addr len.value)
       (loop (addr (+ addr 1)  ; skip count
              idx  0)
         (if (>= idx len.value)
               t
             (~is memory*.addr value.idx)
               nil
             :else
               (recur (+ addr 1) (+ idx 1))))))

; like memory-contains-array but shows diffs
(def memory-contains-array-verbose (addr value)
  (prn "Mismatch when looking at @addr, size @memory*.addr vs @len.value")
  (and (>= memory*.addr len.value)
       (loop (addr (+ addr 1)  ; skip count
              idx  0)
         (and (< idx len.value) (prn "comparing @idx: @memory*.addr and @value.idx"))
         (if (>= idx len.value)
               t
             (~is memory*.addr value.idx)
               (do1 nil
                    (prn "@addr should contain @(repr value.idx) but contains @(repr memory*.addr)")
                    (recur (+ addr 1) (+ idx 1)))
             :else
               (recur (+ addr 1) (+ idx 1))))))

; like memory-contains-array but shows diffs in 2D
(def screen-contains (addr width value)
  (or (memory-contains-array addr value)
      (do1 nil
          (prn "Mismatch detected. Screen contents:")
          (with (row-start-addr  (+ addr 1)  ; skip count
                 idx  0)
            (for row 0  (< row (/ len.value width))  (do ++.row  (++ row-start-addr width))
              (pr ". ")
              (for col 0  (< col width)  ++.col
                (with (expected  value.idx
                       got  (memory* (+ col row-start-addr)))
                  (pr got)
                  (pr (if (is expected got) " " "X")))
                ++.idx)
              (prn " .")
              )))))

; run code in tests
(mac run-code (name . body)
  ; careful to avoid re-processing functions and adding noise to traces
  `(do
     (prn "-- " ',name)
     (trace "===" ',name)
     (wipe (function* ',name))
     (add-code '((function ,name [ ,@body ])))
     (freeze-another ',name)
;?      (set dump-trace*) ;? 1
     (run-more ',name)))

; kludge to prevent reloading functions in .mu files for every test
(def reset2 ()
  (= memory* (table))
  (= Memory-allocated-until 1000)
  (awhen curr-trace-file*
    (tofile (+ trace-dir* it)
      (each (label trace) (as cons traces*)
        (pr label ": " trace))))
  (= curr-trace-file* nil)
  (= traces* (queue))
  (wipe dump-trace*)
  (wipe function*!main)
  (wipe location*!main)
  (= running-routines* (queue))
  (= sleeping-routines* (table))
  (wipe completed-routines*)
  (wipe routine*)
  (= abort-routine* (parameter nil))
  (= curr-cycle* 0)
  (= scheduling-interval* 500)
  (= scheduler-switch-table* nil)
  )

(= disable-debug-prints-in-console-mode* nil)
(def test-only-settings ()
  (set allow-raw-addresses*)
  (set disable-debug-prints-in-console-mode*))

(def routine-that-ran (f)
  (find [some [is f _!fn-name] stack._]
        completed-routines*))

(def routine-running (f)
  (or
    (find [some [is f _!fn-name] stack._]
          completed-routines*)
    (find [some [is f _!fn-name] stack._]
          (as cons running-routines*))
    (find [some [is f _!fn-name] stack._]
          (keys sleeping-routines*))
    (and routine*
         (some [is f _!fn-name] stack.routine*)
         routine*)))

(def ran-to-completion (f)
  ; if a routine calling f ran to completion there'll be no sign of it in any
  ; completed call-stacks.
  (~routine-that-ran f))

(def restart (routine)
  (while (in top.routine!fn-name 'read 'write)
    (pop-stack routine))
  (wipe rep.routine!sleep)
  (wipe rep.routine!error)
  (enq routine running-routines*))

(def dump (msg routine)
  (prn "= @msg " rep.routine!sleep)
  (prn:rem [in car._ 'sleep 'call-stack] (as cons rep.routine))
  (each frame rep.routine!call-stack
    (prn " @frame!fn-name")
    (each (key val) frame
      (unless (is key 'fn-name)
        (prn "  " key " " val)))))

;; system software
; create once, load before every test

(reset)
(= system-function* (table))

(mac init-fn (name . body)
  (let real-name (v tokenize-arg.name)
    `(= (system-function* ',real-name) ',body)))

(def load-system-functions ()
  (each (name f) system-function*
    (= (function* name)
       (system-function* name))))

; allow running mu.arc without load.arc
(unless bound!section (= section do))

(section 100

(init-fn maybe-coerce
  (default-space:space-address <- new space:literal 30:literal)
  (x:tagged-value-address <- new tagged-value:literal)
  (x:tagged-value-address/deref <- next-input)
  (p:type <- next-input)
  (xtype:type <- get x:tagged-value-address/deref type:offset)
  (match?:boolean <- equal xtype:type p:type)
  { begin
    (break-if match?:boolean)
    (reply 0:literal nil:literal)
  }
  (xvalue:location <- get x:tagged-value-address/deref payload:offset)
  (reply xvalue:location match?:boolean))

(init-fn init-tagged-value
  (default-space:space-address <- new space:literal 30:literal)
  ; assert sizeof:arg.0 == 1
  (xtype:type <- next-input)
  (xtypesize:integer <- sizeof xtype:type)
  (xcheck:boolean <- equal xtypesize:integer 1:literal)
  (assert xcheck:boolean)
  ; todo: check that arg 0 matches the type? or is that for the future typechecker?
  (result:tagged-value-address <- new tagged-value:literal)
  ; result->type = arg 0
  (resulttype:location <- get-address result:tagged-value-address/deref type:offset)
  (resulttype:location/deref <- copy xtype:type)
  ; result->payload = arg 1
  (locaddr:location <- get-address result:tagged-value-address/deref payload:offset)
  (locaddr:location/deref <- next-input)
  (reply result:tagged-value-address))

(init-fn list-next  ; list-address -> list-address
  (default-space:space-address <- new space:literal 30:literal)
  (base:list-address <- next-input)
  (result:list-address <- get base:list-address/deref cdr:offset)
  (reply result:list-address))

(init-fn list-value-address  ; list-address -> tagged-value-address
  (default-space:space-address <- new space:literal 30:literal)
  (base:list-address <- next-input)
  (result:tagged-value-address <- get-address base:list-address/deref car:offset)
  (reply result:tagged-value-address))

; create a list out of a list of args
; only integers for now
(init-fn init-list
  (default-space:space-address <- new space:literal 30:literal)
  ; new-list = curr = new list
  (result:list-address <- new list:literal)
  (curr:list-address <- copy result:list-address)
  { begin
    ; while read curr-value
    (curr-value:integer exists?:boolean <- next-input)
    (break-unless exists?:boolean)
    ; curr.cdr = new list
    (next:list-address-address <- get-address curr:list-address/deref cdr:offset)
    (next:list-address-address/deref <- new list:literal)
    ; curr = curr.cdr
    (curr:list-address <- list-next curr:list-address)
    ; curr.car = type:curr-value
    (dest:tagged-value-address <- list-value-address curr:list-address)
    (dest:tagged-value-address/deref <- save-type curr-value:integer)
    (loop)
  }
  ; return new-list.cdr
  (result:list-address <- list-next result:list-address)  ; memory leak
  (reply result:list-address))

(init-fn list-length
  (default-space:space-address <- new space:literal 30:literal)
  (curr:list-address <- next-input)
;?   ; recursive
;?   { begin
;?     ; if empty list return 0
;?     (t1:tagged-value-address <- list-value-address curr:list-address)
;?     (break-if t1:tagged-value-address)
;?     (reply 0:literal)
;?   }
;?   ; else return 1+length(curr.cdr)
;? ;?   ($print (("recurse\n" literal)))
;?   (next:list-address <- list-next curr:list-address)
;?   (sub:integer <- list-length next:list-address)
;?   (result:integer <- add sub:integer 1:literal)
;?   (reply result:integer))
  ; iterative solution
  (result:integer <- copy 0:literal)
  { begin
    ; while curr
    (t1:tagged-value-address <- list-value-address curr:list-address)
    (break-unless t1:tagged-value-address)
    ; ++result
    (result:integer <- add result:integer 1:literal)
;?     ($print result:integer)
;?     ($print (("\n" literal)))
    ; curr = curr.cdr
    (curr:list-address <- list-next curr:list-address)
    (loop)
  }
  (reply result:integer))

(init-fn init-channel
  (default-space:space-address <- new space:literal 30:literal)
  ; result = new channel
  (result:channel-address <- new channel:literal)
  ; result.first-full = 0
  (full:integer-address <- get-address result:channel-address/deref first-full:offset)
  (full:integer-address/deref <- copy 0:literal)
  ; result.first-free = 0
  (free:integer-address <- get-address result:channel-address/deref first-free:offset)
  (free:integer-address/deref <- copy 0:literal)
  ; result.circular-buffer = new tagged-value[arg+1]
  (capacity:integer <- next-input)
  (capacity:integer <- add capacity:integer 1:literal)  ; unused slot for full? below
  (channel-buffer-address:tagged-value-array-address-address <- get-address result:channel-address/deref circular-buffer:offset)
  (channel-buffer-address:tagged-value-array-address-address/deref <- new tagged-value-array:literal capacity:integer)
  (reply result:channel-address))

(init-fn capacity
  (default-space:space-address <- new space:literal 30:literal)
  (chan:channel <- next-input)
  (q:tagged-value-array-address <- get chan:channel circular-buffer:offset)
  (qlen:integer <- length q:tagged-value-array-address/deref)
  (reply qlen:integer))

(init-fn write
  (default-space:space-address <- new space:literal 30:literal)
  (chan:channel-address <- next-input)
  (val:tagged-value <- next-input)
  { begin
    ; block if chan is full
    (full:boolean <- full? chan:channel-address/deref)
    (break-unless full:boolean)
    (full-address:integer-address <- get-address chan:channel-address/deref first-full:offset)
    (sleep until-location-changes:literal full-address:integer-address/deref)
  }
  ; store val
  (q:tagged-value-array-address <- get chan:channel-address/deref circular-buffer:offset)
  (free:integer-address <- get-address chan:channel-address/deref first-free:offset)
  (dest:tagged-value-address <- index-address q:tagged-value-array-address/deref free:integer-address/deref)
  (dest:tagged-value-address/deref <- copy val:tagged-value)
  ; increment free
  (free:integer-address/deref <- add free:integer-address/deref 1:literal)
  { begin
    ; wrap free around to 0 if necessary
    (qlen:integer <- length q:tagged-value-array-address/deref)
    (remaining?:boolean <- less-than free:integer-address/deref qlen:integer)
    (break-if remaining?:boolean)
    (free:integer-address/deref <- copy 0:literal)
  }
  (reply chan:channel-address/deref/same-as-arg:0))

(init-fn read
  (default-space:space-address <- new space:literal 30:literal)
  (chan:channel-address <- next-input)
;?   ($dump-channel chan:channel-address) ;? 2
  { begin
    ; block if chan is empty
    (empty:boolean <- empty? chan:channel-address/deref)
    (break-unless empty:boolean)
    (free-address:integer-address <- get-address chan:channel-address/deref first-free:offset)
    (sleep until-location-changes:literal free-address:integer-address/deref)
  }
  ; read result
  (full:integer-address <- get-address chan:channel-address/deref first-full:offset)
  (q:tagged-value-array-address <- get chan:channel-address/deref circular-buffer:offset)
  (result:tagged-value <- index q:tagged-value-array-address/deref full:integer-address/deref)
  ; increment full
  (full:integer-address/deref <- add full:integer-address/deref 1:literal)
  { begin
    ; wrap full around to 0 if necessary
    (qlen:integer <- length q:tagged-value-array-address/deref)
    (remaining?:boolean <- less-than full:integer-address/deref qlen:integer)
    (break-if remaining?:boolean)
    (full:integer-address/deref <- copy 0:literal)
  }
  (reply result:tagged-value chan:channel-address/deref/same-as-arg:0))

; An empty channel has first-empty and first-full both at the same value.
(init-fn empty?
  (default-space:space-address <- new space:literal 30:literal)
  ; return arg.first-full == arg.first-free
  (chan:channel <- next-input)
  (full:integer <- get chan:channel first-full:offset)
  (free:integer <- get chan:channel first-free:offset)
  (result:boolean <- equal full:integer free:integer)
  (reply result:boolean))

; A full channel has first-empty just before first-full, wasting one slot.
; (Other alternatives: https://en.wikipedia.org/wiki/Circular_buffer#Full_.2F_Empty_Buffer_Distinction)
(init-fn full?
  (default-space:space-address <- new space:literal 30:literal)
  (chan:channel <- next-input)
  ; curr = chan.first-free + 1
  (curr:integer <- get chan:channel first-free:offset)
  (curr:integer <- add curr:integer 1:literal)
  { begin
    ; if (curr == chan.capacity) curr = 0
    (qlen:integer <- capacity chan:channel)
    (remaining?:boolean <- less-than curr:integer qlen:integer)
    (break-if remaining?:boolean)
    (curr:integer <- copy 0:literal)
  }
  ; return chan.first-full == curr
  (full:integer <- get chan:channel first-full:offset)
  (result:boolean <- equal full:integer curr:integer)
  (reply result:boolean))

(init-fn string-equal
  (default-space:space-address <- new space:literal 30:literal)
  (a:string-address <- next-input)
  (a-len:integer <- length a:string-address/deref)
  (b:string-address <- next-input)
  (b-len:integer <- length b:string-address/deref)
  ; compare lengths
  { begin
    (length-equal?:boolean <- equal a-len:integer b-len:integer)
    (break-if length-equal?:boolean)
    (reply nil:literal)
  }
  ; compare each corresponding byte
  (i:integer <- copy 0:literal)
  { begin
    (done?:boolean <- greater-or-equal i:integer a-len:integer)
    (break-if done?:boolean)
    (a2:byte <- index a:string-address/deref i:integer)
    (b2:byte <- index b:string-address/deref i:integer)
    { begin
      (chars-match?:boolean <- equal a2:byte b2:byte)
      (break-if chars-match?:boolean)
      (reply nil:literal)
    }
    (i:integer <- add i:integer 1:literal)
    (loop)
  }
  (reply t:literal)
)

(init-fn strcat
  (default-space:space-address <- new space:literal 30:literal)
  ; result = new string[a.length + b.length]
  (a:string-address <- next-input)
  (a-len:integer <- length a:string-address/deref)
  (b:string-address <- next-input)
  (b-len:integer <- length b:string-address/deref)
  (result-len:integer <- add a-len:integer b-len:integer)
  (result:string-address <- new string:literal result-len:integer)
  ; copy a into result
  (result-idx:integer <- copy 0:literal)
  (i:integer <- copy 0:literal)
  { begin
    ; while (i < a.length)
    (a-done?:boolean <- greater-or-equal i:integer a-len:integer)
    (break-if a-done?:boolean)
    ; result[result-idx] = a[i]
    (out:byte-address <- index-address result:string-address/deref result-idx:integer)
    (in:byte <- index a:string-address/deref i:integer)
    (out:byte-address/deref <- copy in:byte)
    ; ++i
    (i:integer <- add i:integer 1:literal)
    ; ++result-idx
    (result-idx:integer <- add result-idx:integer 1:literal)
    (loop)
  }
  ; copy b into result
  (i:integer <- copy 0:literal)
  { begin
    ; while (i < b.length)
    (b-done?:boolean <- greater-or-equal i:integer b-len:integer)
    (break-if b-done?:boolean)
    ; result[result-idx] = a[i]
    (out:byte-address <- index-address result:string-address/deref result-idx:integer)
    (in:byte <- index b:string-address/deref i:integer)
    (out:byte-address/deref <- copy in:byte)
    ; ++i
    (i:integer <- add i:integer 1:literal)
    ; ++result-idx
    (result-idx:integer <- add result-idx:integer 1:literal)
    (loop)
  }
  (reply result:string-address))

; replace underscores in first with remaining args
(init-fn interpolate  ; string-address template, string-address a..
  (default-space:space-address <- new space:literal 60:literal)
  (template:string-address <- next-input)
  ; compute result-len, space to allocate for result
  (tem-len:integer <- length template:string-address/deref)
  (result-len:integer <- copy tem-len:integer)
  { begin
    ; while arg received
    (a:string-address arg-received?:boolean <- next-input)
    (break-unless arg-received?:boolean)
;?     ($print ("arg now: " literal))
;?     ($print a:string-address)
;?     ($print "@":literal)
;?     ($print a:string-address/deref)  ; todo: test (m on scoped array)
;?     ($print "\n":literal)
;? ;?     (assert nil:literal)
    ; result-len = result-len + arg.length - 1 (for the 'underscore' being replaced)
    (a-len:integer <- length a:string-address/deref)
    (result-len:integer <- add result-len:integer a-len:integer)
    (result-len:integer <- subtract result-len:integer 1:literal)
;?     ($print ("result-len now: " literal))
;?     ($print result-len:integer)
;?     ($print "\n":literal)
    (loop)
  }
  ; rewind to start of non-template args
  (_ <- input 0:literal)
  ; result = new string[result-len]
  (result:string-address <- new string:literal result-len:integer)
  ; repeatedly copy sections of template and 'holes' into result
  (result-idx:integer <- copy 0:literal)
  (i:integer <- copy 0:literal)
  { begin
    ; while arg received
    (a:string-address arg-received?:boolean <- next-input)
    (break-unless arg-received?:boolean)
    ; copy template into result until '_'
    { begin
      ; while (i < template.length)
      (tem-done?:boolean <- greater-or-equal i:integer tem-len:integer)
      (break-if tem-done?:boolean 2:blocks)
      ; while template[i] != '_'
      (in:byte <- index template:string-address/deref i:integer)
      (underscore?:boolean <- equal in:byte ((#\_ literal)))
      (break-if underscore?:boolean)
      ; result[result-idx] = template[i]
      (out:byte-address <- index-address result:string-address/deref result-idx:integer)
      (out:byte-address/deref <- copy in:byte)
      ; ++i
      (i:integer <- add i:integer 1:literal)
      ; ++result-idx
      (result-idx:integer <- add result-idx:integer 1:literal)
      (loop)
    }
;?     ($print ("i now: " literal))
;?     ($print i:integer)
;?     ($print "\n":literal)
    ; copy 'a' into result
    (j:integer <- copy 0:literal)
    { begin
      ; while (j < a.length)
      (arg-done?:boolean <- greater-or-equal j:integer a-len:integer)
      (break-if arg-done?:boolean)
      ; result[result-idx] = a[j]
      (in:byte <- index a:string-address/deref j:integer)
;?       ($print ("copying: " literal))
;?       ($print in:byte)
;?       ($print (" at: " literal))
;?       ($print result-idx:integer)
;?       ($print "\n":literal)
      (out:byte-address <- index-address result:string-address/deref result-idx:integer)
      (out:byte-address/deref <- copy in:byte)
      ; ++j
      (j:integer <- add j:integer 1:literal)
      ; ++result-idx
      (result-idx:integer <- add result-idx:integer 1:literal)
      (loop)
    }
    ; skip '_' in template
    (i:integer <- add i:integer 1:literal)
;?     ($print ("i now: " literal))
;?     ($print i:integer)
;?     ($print "\n":literal)
    (loop)  ; interpolate next arg
  }
  ; done with holes; copy rest of template directly into result
  { begin
    ; while (i < template.length)
    (tem-done?:boolean <- greater-or-equal i:integer tem-len:integer)
    (break-if tem-done?:boolean)
    ; result[result-idx] = template[i]
    (in:byte <- index template:string-address/deref i:integer)
;?     ($print ("copying: " literal))
;?     ($print in:byte)
;?     ($print (" at: " literal))
;?     ($print result-idx:integer)
;?     ($print "\n":literal)
    (out:byte-address <- index-address result:string-address/deref result-idx:integer)
    (out:byte-address/deref <- copy in:byte)
    ; ++i
    (i:integer <- add i:integer 1:literal)
    ; ++result-idx
    (result-idx:integer <- add result-idx:integer 1:literal)
    (loop)
  }
  (reply result:string-address))

(init-fn find-next  ; string, character, index -> next index
  (default-space:space-address <- new space:literal 30:literal)
  (text:string-address <- next-input)
  (pattern:character <- next-input)
  (idx:integer <- next-input)
  (len:integer <- length text:string-address/deref)
  { begin
    (eof?:boolean <- greater-or-equal idx:integer len:integer)
    (break-if eof?:boolean)
    (curr:byte <- index text:string-address/deref idx:integer)
    (found?:boolean <- equal curr:byte pattern:character)
    (break-if found?:boolean)
    (idx:integer <- add idx:integer 1:literal)
    (loop)
  }
  (reply idx:integer))

(init-fn find-substring/variant:find-next
  (default-space:space-address <- new space:literal 30:literal)
  ; fairly dumb algorithm; used for parsing code and traces
  (text:string-address <- next-input)
  (pattern:string-address <- next-input)
  (idx:integer <- next-input)
  (first:character <- index pattern:string-address/deref 0:literal)
  ; repeatedly check for match at current idx
  (len:integer <- length text:string-address/deref)
  { begin
    ; does some unnecessary work checking for substrings even when there isn't enough of text left
    (eof?:boolean <- greater-or-equal idx:integer len:integer)
    (break-if eof?:boolean)
    (found?:boolean <- match-at text:string-address pattern:string-address idx:integer)
    (break-if found?:boolean)
    (idx:integer <- add idx:integer 1:literal)
    ; optimization: skip past indices that definitely won't match
    (idx:integer <- find-next text:string-address first:character idx:integer)
    (loop)
  }
  (reply idx:integer)
)

(init-fn match-at
  (default-space:space-address <- new space:literal 30:literal)
  ; fairly dumb algorithm; used for parsing code and traces
  (text:string-address <- next-input)
  (pattern:string-address <- next-input)
  (idx:integer <- next-input)
  (pattern-len:integer <- length pattern:string-address/deref)
  ; check that there's space left for the pattern
  { begin
    (x:integer <- length text:string-address/deref)
    (x:integer <- subtract x:integer pattern-len:integer)
    (enough-room?:boolean <- lesser-or-equal idx:integer x:integer)
    (break-if enough-room?:boolean)
    (reply nil:literal)
  }
  ; check each character of pattern
  (pattern-idx:integer <- copy 0:literal)
  { begin
    (done?:boolean <- greater-or-equal pattern-idx:integer pattern-len:integer)
    (break-if done?:boolean)
    (c:character <- index text:string-address/deref idx:integer)
    (exp:character <- index pattern:string-address/deref pattern-idx:integer)
    { begin
      (match?:boolean <- equal c:character exp:character)
      (break-if match?:boolean)
      (reply nil:literal)
    }
    (idx:integer <- add idx:integer 1:literal)
    (pattern-idx:integer <- add pattern-idx:integer 1:literal)
    (loop)
  }
  (reply t:literal)
)

(init-fn split  ; string, character -> string-address-array-address
  (default-space:space-address <- new space:literal 30:literal)
  (s:string-address <- next-input)
  (delim:character <- next-input)
  ; empty string? return empty array
  (len:integer <- length s:string-address/deref)
  { begin
    (empty?:boolean <- equal len:integer 0:literal)
    (break-unless empty?:boolean)
    (result:string-address-array-address <- new string-address-array:literal 0:literal)
    (reply result:string-address-array-address)
  }
  ; count #pieces we need room for
  (count:integer <- copy 1:literal)  ; n delimiters = n+1 pieces
  (idx:integer <- copy 0:literal)
  { begin
    (idx:integer <- find-next s:string-address delim:character idx:integer)
    (done?:boolean <- greater-or-equal idx:integer len:integer)
    (break-if done?:boolean)
    (idx:integer <- add idx:integer 1:literal)
    (count:integer <- add count:integer 1:literal)
    (loop)
  }
  ; allocate space
;?   ($print (("alloc: " literal)))
;?   ($print count:integer)
;?   ($print (("\n" literal)))
  (result:string-address-array-address <- new string-address-array:literal count:integer)
  ; repeatedly copy slices (start..end) until delimiter into result[curr-result]
  (curr-result:integer <- copy 0:literal)
  (start:integer <- copy 0:literal)
  { begin
    ; while next delim exists
    (done?:boolean <- greater-or-equal start:integer len:integer)
    (break-if done?:boolean)
    (end:integer <- find-next s:string-address delim:character start:integer)
;?     ($print start:integer) ;? 1
;?     ($print ((" " literal))) ;? 1
;?     ($print end:integer) ;? 1
;?     ($print (("\n" literal))) ;? 1
    ; copy start..end into result[curr-result]
    (dest:string-address-address <- index-address result:string-address-array-address/deref curr-result:integer)
    (dest:string-address-address/deref <- string-copy s:string-address start:integer end:integer)
    ; slide over to next slice
    (start:integer <- add end:integer 1:literal)
    (curr-result:integer <- add curr-result:integer 1:literal)
    (loop)
  }
  (reply result:string-address-array-address)
)

(init-fn split-first-at-substring/variant:split-first  ; string text, string delim -> string first, string rest
  (default-space:space-address <- new space:literal 30:literal)
  (text:string-address <- next-input)
  (delim:string-address <- next-input)
  ; empty string? return empty strings
  (len:integer <- length text:string-address/deref)
  { begin
    (empty?:boolean <- equal len:integer 0:literal)
    (break-unless empty?:boolean)
    (x:string-address <- new "")
    (y:string-address <- new "")
    (reply x:string-address y:string-address)
  }
  (idx:integer <- find-substring text:string-address delim:string-address 0:literal)
  (x:string-address <- string-copy text:string-address 0:literal idx:integer)
  (k:integer <- length delim:string-address/deref)
  (idx:integer <- add idx:integer k:integer)
  (y:string-address <- string-copy text:string-address idx:integer len:integer)
  (reply x:string-address y:string-address)
)

(init-fn split-first  ; string text, character delim -> string first, string rest
  (default-space:space-address <- new space:literal 30:literal)
  (text:string-address <- next-input)
  (delim:character <- next-input)
  ; empty string? return empty strings
  (len:integer <- length text:string-address/deref)
  { begin
    (empty?:boolean <- equal len:integer 0:literal)
    (break-unless empty?:boolean)
    (x:string-address <- new "")
    (y:string-address <- new "")
    (reply x:string-address y:string-address)
  }
  (idx:integer <- find-next text:string-address delim:character 0:literal)
  (x:string-address <- string-copy text:string-address 0:literal idx:integer)
  (idx:integer <- add idx:integer 1:literal)
  (y:string-address <- string-copy text:string-address idx:integer len:integer)
  (reply x:string-address y:string-address)
)

; todo: make this generic
(init-fn string-copy  ; buf start end -> address of new array
  (default-space:space-address <- new space:literal 30:literal)
  (buf:string-address <- next-input)
  (start:integer <- next-input)
  (end:integer <- next-input)
;?   ($print (("  copy: " literal))) ;? 1
;?   ($print start:integer) ;? 1
;?   ($print (("-" literal))) ;? 1
;?   ($print end:integer) ;? 1
;?   ($print (("\n" literal))) ;? 1
  ; if end is out of bounds, trim it
  (len:integer <- length buf:string-address/deref)
  (end:integer <- min len:integer end:integer)
  ; allocate space for result
  (len:integer <- subtract end:integer start:integer)
  (result:string-address <- new string:literal len:integer)
  ; copy start..end into result[curr-result]
  (src-idx:integer <- copy start:integer)
  (dest-idx:integer <- copy 0:literal)
  { begin
    (done?:boolean <- greater-or-equal src-idx:integer end:integer)
    (break-if done?:boolean)
    (src:character <- index buf:string-address/deref src-idx:integer)
;?     ($print (("  copying " literal))) ;? 1
;?     ($print src:character) ;? 1
;?     ($print (("\n" literal))) ;? 1
    (dest:character-address <- index-address result:string-address/deref dest-idx:integer)
    (dest:character-address/deref <- copy src:character)
    (src-idx:integer <- add src-idx:integer 1:literal)
    (dest-idx:integer <- add dest-idx:integer 1:literal)
    (loop)
  }
  (reply result:string-address)
)

(init-fn min
  (default-space:space-address <- new space:literal 30:literal)
  (x:integer <- next-input)
  (y:integer <- next-input)
  { begin
    (return-x?:boolean <- less-than x:integer y:integer)
    (break-if return-x?:boolean)
    (reply y:integer)
  }
  (reply x:integer)
)

(init-fn max
  (default-space:space-address <- new space:literal 30:literal)
  (x:integer <- next-input)
  (y:integer <- next-input)
  { begin
    (return-x?:boolean <- greater-than x:integer y:integer)
    (break-if return-x?:boolean)
    (reply y:integer)
  }
  (reply x:integer)
)

(init-fn init-stream
  (default-space:space-address <- new space:literal 30:literal)
  (in:string-address <- next-input)
  (result:stream-address <- new stream:literal)
  (x:integer-address <- get-address result:stream-address/deref pointer:offset)
  (x:integer-address/deref <- copy 0:literal)
  (y:string-address-address <- get-address result:stream-address/deref data:offset)
  (y:string-address-address/deref <- copy in:string-address)
  (reply result:stream-address)
)

(init-fn rewind-stream
  (default-space:space-address <- new space:literal 30:literal)
  (in:stream-address <- next-input)
  (x:integer-address <- get-address in:stream-address/deref pointer:offset)
  (x:integer-address/deref <- copy 0:literal)
  (reply in:stream-address/same-as-arg:0)
)

(init-fn read-line
  (default-space:space-address <- new space:literal 30:literal)
  (in:stream-address <- next-input)
  (idx:integer-address <- get-address in:stream-address/deref pointer:offset)
  (s:string-address <- get in:stream-address/deref data:offset)
;?   ($print (("idx before: " literal))) ;? 1
;?   ($print idx:integer-address/deref) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (next-idx:integer <- find-next s:string-address ((#\newline literal)) idx:integer-address/deref)
;?   ($print (("next-idx: " literal))) ;? 1
;?   ($print next-idx:integer) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (result:string-address <- string-copy s:string-address idx:integer-address/deref next-idx:integer)
  (idx:integer-address/deref <- add next-idx:integer 1:literal)  ; skip newline
;?   ($print (("idx now: " literal))) ;? 1
;?   ($print idx:integer-address/deref) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (reply result:string-address)
)

(init-fn read-character
  (default-space:space-address <- new space:literal 30:literal)
  (in:stream-address <- next-input)
  (idx:integer-address <- get-address in:stream-address/deref pointer:offset)
  (s:string-address <- get in:stream-address/deref data:offset)
  (c:character <- index s:string-address/deref idx:integer-address/deref)
  (idx:integer-address/deref <- add idx:integer-address/deref 1:literal)
  (reply c:character)
)

(init-fn end-of-stream?
  (default-space:space-address <- new space:literal 30:literal)
  (in:stream-address <- next-input)
  (idx:integer <- get in:stream-address/deref pointer:offset)
  (s:string-address <- get in:stream-address/deref data:offset)
  (len:integer <- length s:string-address/deref)
;?   ($print (("eos: " literal))) ;? 1
;?   ($print len:integer) ;? 1
;?   ($print (("\n" literal))) ;? 1
;?   ($print (("idx: " literal))) ;? 1
;?   ($print idx:integer) ;? 1
;?   ($print (("\n" literal))) ;? 1
  (result:boolean <- greater-or-equal idx:integer len:integer)
  (reply result:boolean)
)

(init-fn init-keyboard
  (default-space:space-address <- new space:literal 30:literal)
  (result:keyboard-address <- new keyboard:literal)
  (buf:string-address-address <- get-address result:keyboard-address/deref data:offset)
  (buf:string-address-address/deref <- next-input)
  (idx:integer-address <- get-address result:keyboard-address/deref index:offset)
  (idx:integer-address/deref <- copy 0:literal)
  (reply result:keyboard-address)
)

(init-fn read-key
  (default-space:space-address <- new space:literal 30:literal)
  (x:keyboard-address <- next-input)
  (screen:terminal-address <- next-input)
  { begin
    (break-unless x:keyboard-address)
    (idx:integer-address <- get-address x:keyboard-address/deref index:offset)
    (buf:string-address <- get x:keyboard-address/deref data:offset)
    (max:integer <- length buf:string-address/deref)
    { begin
      (done?:boolean <- greater-or-equal idx:integer-address/deref max:integer)
      (break-unless done?:boolean)
      (reply ((#\null literal)))
    }
    (c:character <- index buf:string-address/deref idx:integer-address/deref)
    (idx:integer-address/deref <- add idx:integer-address/deref 1:literal)
    (reply c:character)
  }
  ; real keyboard input is infrequent; avoid polling it too much
  (sleep for-some-cycles:literal 1:literal)
  (c:character <- read-key-from-host)
  ; when we read from a real keyboard we print to screen as well
  { begin
    (break-unless c:character)
    (silent?:boolean <- equal screen:terminal-address ((silent literal)))
    (break-if silent?:boolean)
;?     ($print (("aaaa\n" literal))) ;? 1
    (print-character-to-host c:character)
  }
  (reply c:character)
)

(init-fn wait-for-key
  (default-space:space-address <- new space:literal 30:literal)
  (k:keyboard-address <- next-input)
  (screen:terminal-address <- next-input)
  { begin
    (result:character <- read-key k:keyboard-address screen:terminal-address)
    (loop-unless result:character)
  }
  (reply result:character)
)

(init-fn send-keys-to-stdin
  (default-space:space-address <- new space:literal 30:literal)
  (k:keyboard-address <- next-input)
  (stdin:channel-address <- next-input)
;?   (c:character <- copy ((#\a literal))) ;? 1
;?   (curr:tagged-value <- save-type c:character) ;? 1
;?   (stdin:channel-address/deref <- write stdin:channel-address curr:tagged-value) ;? 1
;?   (c:character <- copy ((#\newline literal))) ;? 1
;?   (curr:tagged-value <- save-type c:character) ;? 1
;?   (stdin:channel-address/deref <- write stdin:channel-address curr:tagged-value) ;? 1
  { begin ;? 1
    (c:character <- read-key k:keyboard-address) ;? 1
    (loop-unless c:character) ;? 1
    (curr:tagged-value <- save-type c:character) ;? 1
    (stdin:channel-address/deref <- write stdin:channel-address curr:tagged-value) ;? 1
    (eof?:boolean <- equal c:character ((#\null literal))) ;? 1
    (break-if eof?:boolean) ;? 1
    (loop) ;? 1
  } ;? 1
)

; collect characters until newline before sending out
(init-fn buffer-lines
  (default-space:space-address <- new space:literal 30:literal)
  (stdin:channel-address <- next-input)
  (buffered-stdin:channel-address <- next-input)
  ; repeat forever
  { begin
    (line:buffer-address <- init-buffer 30:literal)
;?     ($dump-channel 1093:literal) ;? 1
    ; read characters from stdin until newline, copy into line
    { begin
      (x:tagged-value stdin:channel-address/deref <- read stdin:channel-address)
      (c:character <- maybe-coerce x:tagged-value character:literal)
      (assert c:character)
;?       ($print line:buffer-address) ;? 2
;?       ($print (("\n" literal))) ;? 2
;?       ($print c:character) ;? 2
;?       ($print (("\n" literal))) ;? 2
      ; handle backspace
      { begin
        (backspace?:boolean <- equal c:character ((#\backspace literal)))
        (break-unless backspace?:boolean)
        (len:integer-address <- get-address line:buffer-address/deref length:offset)
        ; but only if we need to
        { begin
;?           ($print (("backspace: " literal))) ;? 1
;?           ($print len:integer-address/deref) ;? 1
;?           ($print (("\n" literal))) ;? 1
          (zero?:boolean <- lesser-or-equal len:integer-address/deref 0:literal)
          (break-if zero?:boolean)
          (len:integer-address/deref <- subtract len:integer-address/deref 1:literal)
        }
        (loop 2:blocks)
      }
      (line:buffer-address <- append line:buffer-address c:character)
      (line-done?:boolean <- equal c:character ((#\newline literal)))
      (break-if line-done?:boolean)
      (eof?:boolean <- equal c:character ((#\null literal)))
      (break-if eof?:boolean 2:blocks)
      (loop)
    }
    ; copy line into buffered-stdout
    (i:integer <- copy 0:literal)
    (line-contents:string-address <- get line:buffer-address/deref data:offset)
    (max:integer <- get line:buffer-address/deref length:offset)
;?     ($print (("len: " literal))) ;? 1
;?     ($print max:integer) ;? 1
;?     ($print (("\n" literal))) ;? 1
    { begin
      (done?:boolean <- greater-or-equal i:integer max:integer)
      (break-if done?:boolean)
      (c:character <- index line-contents:string-address/deref i:integer)
      (curr:tagged-value <- save-type c:character)
;?       ($dump-channel 1093:literal) ;? 1
;?       ($start-tracing) ;? 1
;?       ($print (("bufferout: " literal))) ;? 2
;?       ($print c:character) ;? 1
;?       (x:integer <- character-to-integer c:character) ;? 1
;?       ($print x:integer) ;? 1
;?       ($print (("\n" literal))) ;? 2
      (buffered-stdin:channel-address/deref <- write buffered-stdin:channel-address curr:tagged-value)
;?       ($stop-tracing) ;? 1
;?       ($dump-channel 1093:literal) ;? 1
;?       ($quit) ;? 1
      (i:integer <- add i:integer 1:literal)
      (loop)
    }
    (loop)
  }
)

(init-fn clear-screen
  (default-space:space-address <- new space:literal 30:literal)
  (x:terminal-address <- next-input)
  { begin
    (break-unless x:terminal-address)
;?     ($print (("AAA" literal)))
    (buf:string-address <- get x:terminal-address/deref data:offset)
    (max:integer <- length buf:string-address/deref)
    (i:integer <- copy 0:literal)
    { begin
      (done?:boolean <- greater-or-equal i:integer max:integer)
      (break-if done?:boolean)
      (x:byte-address <- index-address buf:string-address/deref i:integer)
      (x:byte-address/deref <- copy ((#\space literal)))
      (i:integer <- add i:integer 1:literal)
      (loop)
    }
    (reply)
  }
  (clear-host-screen)
)

(init-fn cursor
  (default-space:space-address <- new space:literal 30:literal)
  (x:terminal-address <- next-input)
  (newrow:integer <- next-input)
  (newcol:integer <- next-input)
  { begin
    (break-unless x:terminal-address)
    (row:integer-address <- get-address x:terminal-address/deref cursor-row:offset)
    (row:integer-address/deref <- copy newrow:integer)
    (col:integer-address <- get-address x:terminal-address/deref cursor-col:offset)
    (col:integer-address/deref <- copy newcol:integer)
    (reply)
  }
  (cursor-on-host row:integer col:integer)
)

(init-fn cursor-to-next-line
  (default-space:space-address <- new space:literal 30:literal)
  (x:terminal-address <- next-input)
  { begin
    (break-unless x:terminal-address)
    (row:integer-address <- get-address x:terminal-address/deref cursor-row:offset)
;?     ($print row:integer-address/deref)
;?     ($print (("\n" literal)))
    (row:integer-address/deref <- add row:integer-address/deref 1:literal)
    (col:integer-address <- get-address x:terminal-address/deref cursor-col:offset)
;?     ($print col:integer-address/deref)
;?     ($print (("\n" literal)))
    (col:integer-address/deref <- copy 0:literal)
    (reply)
  }
  (cursor-on-host-to-next-line)
)

(init-fn cursor-down
  (default-space:space-address <- new space:literal 30:literal)
  (x:terminal-address <- next-input)
;?   ($print ((#\# literal))) ;? 1
  (height:integer-address <- get-address x:terminal-address/deref num-rows:offset)
;?   ($print height:integer-address/deref) ;? 1
  { begin
    (break-unless x:terminal-address)
;?     ($print ((#\% literal))) ;? 1
    (row:integer-address <- get-address x:terminal-address/deref cursor-row:offset)
;?     ($print (("cursor down: " literal))) ;? 1
;?     ($print row:integer-address/deref) ;? 1
;?     ($print (("\n" literal))) ;? 1
    { begin
      (bottom?:boolean <- greater-or-equal row:integer-address/deref height:integer-address/deref)
      (break-if bottom?:boolean)
      (row:integer-address/deref <- add row:integer-address/deref 1:literal)
;?       ($print ((#\* literal))) ;? 1
;?       ($print row:integer-address/deref) ;? 1
    }
    (reply)
  }
  (cursor-down-on-host)
)

(init-fn cursor-up
  (default-space:space-address <- new space:literal 30:literal)
  (x:terminal-address <- next-input)
  { begin
    (break-unless x:terminal-address)
    (row:integer-address <- get-address x:terminal-address/deref cursor-row:offset)
;?     ($print (("cursor up: " literal))) ;? 1
;?     ($print row:integer-address/deref) ;? 1
;?     ($print (("\n" literal))) ;? 1
    { begin
      (top?:boolean <- lesser-or-equal row:integer-address/deref 0:literal)
      (break-if top?:boolean)
      (row:integer-address/deref <- subtract row:integer-address/deref 1:literal)
    }
    (reply)
  }
  (cursor-up-on-host)
)

(init-fn cursor-left
  (default-space:space-address <- new space:literal 30:literal)
  (x:terminal-address <- next-input)
  { begin
    (break-unless x:terminal-address)
    (col:integer-address <- get-address x:terminal-address/deref cursor-col:offset)
    { begin
      (edge?:boolean <- lesser-or-equal col:integer-address/deref 0:literal)
      (break-if edge?:boolean)
      (col:integer-address/deref <- subtract col:integer-address/deref 1:literal)
    }
    (reply)
  }
  (cursor-left-on-host)
)

(init-fn cursor-right
  (default-space:space-address <- new space:literal 30:literal)
  (x:terminal-address <- next-input)
  (width:integer-address <- get-address x:terminal-address/deref num-cols:offset)
  { begin
    (break-unless x:terminal-address)
    (col:integer-address <- get-address x:terminal-address/deref cursor-col:offset)
    { begin
      (edge?:boolean <- lesser-or-equal col:integer-address/deref width:integer-address/deref)
      (break-if edge?:boolean)
      (col:integer-address/deref <- add col:integer-address/deref 1:literal)
    }
    (reply)
  }
  (cursor-right-on-host)
)

(init-fn replace-character
  (default-space:space-address <- new space:literal 30:literal)
  (x:terminal-address <- next-input)
  (c:character <- next-input)
  (print-character x:terminal-address c:character)
  (cursor-left x:terminal-address)
)

(init-fn clear-line
  (default-space:space-address <- new space:literal 30:literal)
  (x:terminal-address <- next-input)
  { begin
    (break-unless x:terminal-address)
    (n:integer <- get x:terminal-address/deref num-cols:offset)
    (col:integer-address <- get-address x:terminal-address/deref cursor-col:offset)
    (orig-col:integer <- copy col:integer-address/deref)
    ; space over the entire line
    { begin
      (done?:boolean <- greater-or-equal col:integer-address/deref n:integer)
      (break-if done?:boolean)
      (print-character x:terminal-address ((#\space literal)))  ; implicitly updates 'col'
      (loop)
    }
    ; now back to where the cursor was
    (col:integer-address/deref <- copy orig-col:integer)
    (reply)
  }
  (clear-line-on-host)
)

(init-fn print-character
  (default-space:space-address <- new space:literal 30:literal)
  (x:terminal-address <- next-input)
  (c:character <- next-input)
  (fg:integer/color <- next-input)
  (bg:integer/color <- next-input)
;?   ($print (("printing character to screen " literal)))
;?   ($print c:character)
;?   (reply)
;?   ($print (("\n" literal)))
  { begin
    (break-unless x:terminal-address)
    (row:integer-address <- get-address x:terminal-address/deref cursor-row:offset)
;?     ($print row:integer-address/deref) ;? 2
;?     ($print ((", " literal))) ;? 1
    (col:integer-address <- get-address x:terminal-address/deref cursor-col:offset)
;?     ($print col:integer-address/deref) ;? 1
;?     ($print (("\n" literal))) ;? 1
    (width:integer <- get x:terminal-address/deref num-cols:offset)
    (t1:integer <- multiply row:integer-address/deref width:integer)
    (idx:integer <- add t1:integer col:integer-address/deref)
    (buf:string-address <- get x:terminal-address/deref data:offset)
    (cursor:byte-address <- index-address buf:string-address/deref idx:integer)
    (cursor:byte-address/deref <- copy c:character)  ; todo: newline, etc.
    (col:integer-address/deref <- add col:integer-address/deref 1:literal)
    ; we don't rely on any auto-wrap functionality
    ; maybe die if we go out of screen bounds?
    (reply)
  }
  (print-character-to-host c:character fg:integer/color bg:integer/color)
)

(init-fn print-string
  (default-space:space-address <- new space:literal 30:literal)
  (x:terminal-address <- next-input)
  (s:string-address <- next-input)
  (len:integer <- length s:string-address/deref)
;?   ($print (("print/string: len: " literal)))
;?   ($print len:integer)
;?   ($print (("\n" literal)))
  (i:integer <- copy 0:literal)
  { begin
    (done?:boolean <- greater-or-equal i:integer len:integer)
    (break-if done?:boolean)
    (c:character <- index s:string-address/deref i:integer)
    (print-character x:terminal-address c:character)
    (i:integer <- add i:integer 1:literal)
    (loop)
  }
)

(init-fn print-integer
  (default-space:space-address <- new space:literal 30:literal)
  (x:terminal-address <- next-input)
  (n:integer <- next-input)
  ; todo: other bases besides decimal
;?   ($print (("AAA " literal)))
;?   ($print n:integer)
  (s:string-address <- integer-to-decimal-string n:integer)
;?   ($print s:string-address)
  (print-string x:terminal-address s:string-address)
)

(init-fn init-buffer
  (default-space:space-address <- new space:literal 30:literal)
  (result:buffer-address <- new buffer:literal)
  (len:integer-address <- get-address result:buffer-address/deref length:offset)
  (len:integer-address/deref <- copy 0:literal)
  (s:string-address-address <- get-address result:buffer-address/deref data:offset)
  (capacity:integer <- next-input)
  (s:string-address-address/deref <- new string:literal capacity:integer)
  (reply result:buffer-address)
)

(init-fn grow-buffer
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  ; double buffer size
  (x:string-address-address <- get-address in:buffer-address/deref data:offset)
  (oldlen:integer <- length x:string-address-address/deref/deref)
;?   ($print oldlen:integer) ;? 1
  (newlen:integer <- multiply oldlen:integer 2:literal)
;?   ($print newlen:integer) ;? 1
  (olddata:string-address <- copy x:string-address-address/deref)
  (x:string-address-address/deref <- new string:literal newlen:integer)
  ; copy old contents
  (i:integer <- copy 0:literal)
  { begin
    (done?:boolean <- greater-or-equal i:integer oldlen:integer)
    (break-if done?:boolean)
    (src:byte <- index olddata:string-address/deref i:integer)
    (dest:byte-address <- index-address x:string-address-address/deref/deref i:integer)
    (dest:byte-address/deref <- copy src:byte)
    (i:integer <- add i:integer 1:literal)
    (loop)
  }
  (reply in:buffer-address)
)

(init-fn buffer-full?
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  (len:integer <- get in:buffer-address/deref length:offset)
  (s:string-address <- get in:buffer-address/deref data:offset)
  (capacity:integer <- length s:string-address/deref)
  (result:boolean <- greater-or-equal len:integer capacity:integer)
  (reply result:boolean)
)

(init-fn buffer-index
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  (idx:integer <- next-input)
  { begin
    (len:integer <- get in:buffer-address/deref length:offset)
    (not-too-high?:boolean <- less-than idx:integer len:integer)
    (not-too-low?:boolean <- greater-or-equal idx:integer 0:literal)
    (in-bounds?:boolean <- and not-too-low?:boolean not-too-high?:boolean)
    (break-if in-bounds?:boolean)
    (assert nil:literal (("buffer-index out of bounds" literal)))
  }
  (s:string-address <- get in:buffer-address/deref data:offset)
  (result:character <- index s:string-address/deref idx:integer)
  (reply result:character)
)

(init-fn to-array  ; from buffer
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  (len:integer <- get in:buffer-address/deref length:offset)
  (s:string-address <- get in:buffer-address/deref data:offset)
  { begin
    ; test: ctrl-d -> s is nil -> to-array returns nil -> read-expression returns t -> exit repl
    (break-if s:string-address)
    (reply nil:literal)
  }
  ; we can't just return s because it is usually the wrong length
  (result:string-address <- new string:literal len:integer)
  (i:integer <- copy 0:literal)
  { begin
    (done?:boolean <- greater-or-equal i:integer len:integer)
    (break-if done?:boolean)
    (src:byte <- index s:string-address/deref i:integer)
;?     (foo:integer <- character-to-integer src:byte) ;? 1
;?     ($print (("a: " literal))) ;? 1
;?     ($print foo:integer) ;? 1
;?     ($print ((#\newline literal))) ;? 1
    (dest:byte-address <- index-address result:string-address/deref i:integer)
    (dest:byte-address/deref <- copy src:byte)
    (i:integer <- add i:integer 1:literal)
    (loop)
  }
  (reply result:string-address)
)

(init-fn append
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  (c:character <- next-input)
;?   ($print c:character) ;? 1
  { begin
    ; grow buffer if necessary
    (full?:boolean <- buffer-full? in:buffer-address)
;?     ($print (("aa\n" literal))) ;? 1
    (break-unless full?:boolean)
;?     ($print (("bb\n" literal))) ;? 1
    (in:buffer-address <- grow-buffer in:buffer-address)
;?     ($print (("cc\n" literal))) ;? 1
  }
  (len:integer-address <- get-address in:buffer-address/deref length:offset)
  (s:string-address <- get in:buffer-address/deref data:offset)
  (dest:byte-address <- index-address s:string-address/deref len:integer-address/deref)
  (dest:byte-address/deref <- copy c:character)
  (len:integer-address/deref <- add len:integer-address/deref 1:literal)
  (reply in:buffer-address/same-as-arg:0)
)

(init-fn last
  (default-space:space-address <- new space:literal 30:literal)
  (in:buffer-address <- next-input)
  (n:integer <- get in:buffer-address/deref length:offset)
  { begin
    ; if empty return nil
    (empty?:boolean <- equal n:integer 0:literal)
    (break-unless empty?:boolean)
    (reply nil:literal)
  }
  (n:integer <- subtract n:integer 1:literal)
  (s:string-address <- get in:buffer-address/deref data:offset)
  (result:character <- index s:string-address/deref n:integer)
  (reply result:character)
)

(init-fn integer-to-decimal-string
  (default-space:space-address <- new space:literal 30:literal)
  (n:integer <- next-input)
  ; is it zero?
  { begin
    (zero?:boolean <- equal n:integer 0:literal)
    (break-unless zero?:boolean)
    (s:string-address <- new "0")
    (reply s:string-address)
  }
  ; save sign
  (negate-result:boolean <- copy nil:literal)
  { begin
    (negative?:boolean <- less-than n:integer 0:literal)
    (break-unless negative?:boolean)
;?     ($print (("is negative " literal)))
    (negate-result:boolean <- copy t:literal)
    (n:integer <- multiply n:integer -1:literal)
  }
  ; add digits from right to left into intermediate buffer
  (tmp:buffer-address <- init-buffer 30:literal)
  (zero:character <- copy ((#\0 literal)))
  (digit-base:integer <- character-to-integer zero:character)
  { begin
    (done?:boolean <- equal n:integer 0:literal)
    (break-if done?:boolean)
    (n:integer digit:integer <- divide-with-remainder n:integer 10:literal)
    (digit-codepoint:integer <- add digit-base:integer digit:integer)
    (c:character <- integer-to-character digit-codepoint:integer)
    (tmp:buffer-address <- append tmp:buffer-address c:character)
    (loop)
  }
  ; add sign
  { begin
    (break-unless negate-result:boolean)
    (tmp:buffer-address <- append tmp:buffer-address ((#\- literal)))
  }
  ; reverse buffer into string result
  (len:integer <- get tmp:buffer-address/deref length:offset)
  (buf:string-address <- get tmp:buffer-address/deref data:offset)
  (result:string-address <- new string:literal len:integer)
  (i:integer <- subtract len:integer 1:literal)
  (j:integer <- copy 0:literal)
  { begin
    ; while (i >= 0)
    (done?:boolean <- less-than i:integer 0:literal)
    (break-if done?:boolean)
    ; result[j] = tmp[i]
    (src:byte <- index buf:string-address/deref i:integer)
    (dest:byte-address <- index-address result:string-address/deref j:integer)
    (dest:byte-address/deref <- copy src:byte)
    ; ++i
    (i:integer <- subtract i:integer 1:literal)
    ; --j
    (j:integer <- add j:integer 1:literal)
    (loop)
  }
  (reply result:string-address)
)

(init-fn send-prints-to-stdout
  (default-space:space-address <- new space:literal 30:literal)
  (screen:terminal-address <- next-input)
  (stdout:channel-address <- next-input)
;?   (i:integer <- copy 0:literal) ;? 1
  { begin
    (x:tagged-value stdout:channel-address/deref <- read stdout:channel-address)
    (c:character <- maybe-coerce x:tagged-value character:literal)
    (done?:boolean <- equal c:character ((#\null literal)))
    (break-if done?:boolean)
;?     ($print (("printing " literal))) ;? 1
;?     ($print i:integer) ;? 1
;?     ($print ((" -- " literal))) ;? 1
;?     (x:integer <- character-to-integer c:character) ;? 1
;?     ($print x:integer) ;? 1
;?     ($print (("\n" literal))) ;? 1
;?     (i:integer <- add i:integer 1:literal) ;? 1
    (print-character screen:terminal-address c:character)
    (loop)
  }
)

; remember to call this before you clear the screen or at any other milestone
; in an interactive program
(init-fn flush-stdout
  (default-space:boolean <- copy nil:literal)  ; silence warning, but die if locals used
  (sleep for-some-cycles:literal 1:literal)
)

(init-fn init-fake-terminal
  (default-space:space-address <- new space:literal 30:literal/capacity)
  (result:terminal-address <- new terminal:literal)
  (width:integer-address <- get-address result:terminal-address/deref num-cols:offset)
  (width:integer-address/deref <- next-input)
  (height:integer-address <- get-address result:terminal-address/deref num-rows:offset)
  (height:integer-address/deref <- next-input)
  (row:integer-address <- get-address result:terminal-address/deref cursor-row:offset)
  (row:integer-address/deref <- copy 0:literal)
  (col:integer-address <- get-address result:terminal-address/deref cursor-col:offset)
  (col:integer-address/deref <- copy 0:literal)
  (bufsize:integer <- multiply width:integer-address/deref height:integer-address/deref)
  (buf:string-address-address <- get-address result:terminal-address/deref data:offset)
  (buf:string-address-address/deref <- new string:literal bufsize:integer)
  (clear-screen result:terminal-address)
  (reply result:terminal-address)
)

; after all system software is loaded:
;? (= dump-trace* (obj whitelist '("cn0" "cn1")))
(freeze system-function*)
)  ; section 100 for system software

;; initialization

(reset)
(awhen (pos "--" argv)
  ; batch mode: load all provided files and start at 'main'
  (map add-code:readfile (cut argv (+ it 1)))
;?   (set dump-trace*)
  (run 'main)
  (if ($.current-charterm) ($.close-charterm))
  (when ($.graphics-open?) ($.close-viewport Viewport) ($.close-graphics))
;?   (pr "\nmemory: ")
;?   (write int-canon.memory*)
  (prn)
  (each routine completed-routines*
    (awhen rep.routine!error
      (prn "error - " it)
;?       (prn routine)
      ))
)

; repl
(def run-interactive (stmt)
  ; careful to avoid re-processing functions and adding noise to traces
  (= function*!interactive (convert-labels:convert-braces:tokenize-args (list stmt)))
  (add-next-space-generator function*!interactive 'interactive)
  (= location*!interactive (assign-names-to-location function*!interactive 'interactive location*!interactive))
  (replace-names-with-location function*!interactive 'interactive)
  (= traces* (queue))  ; skip preprocessing
  (run-more 'interactive))

(when (no cdr.argv)
  (add-code:readfile "trace.mu")
  (wipe function*!main)
  (add-code:readfile "chessboard.mu")
  (wipe function*!main)
  (freeze function*)
  (load-system-functions)
  (wipe interactive-commands*)
  (wipe interactive-traces*)
  (= interactive-cmdidx* 0)
  (= traces* (queue))
;?   (set dump-trace*) ;? 2
  ; interactive mode
  (point break
  (while t
    (pr interactive-cmdidx*)(pr "> ")
    (let expr (read)
      (unless expr (break))
      (push expr interactive-commands*)
      (run-interactive expr))
    (push traces* interactive-traces*)
    (++ interactive-cmdidx*)
    )))

(if ($.current-charterm) ($.close-charterm))
(reset)
;? (print-times)
