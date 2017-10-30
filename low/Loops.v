(** RLoops.
  This file provides looping monads to easily manipulate R objects. **)

Set Implicit Arguments.
Require Export Monads Globals.

(** * Defn.h **)

(** This section defines the FUNTAB structure, which is used to store primitive
  and internal functions, as well as some constructs to evaluate it. **)

(** All function in the array [R_FunTab] have the same type. **)
Definition function_code :=
  state ->
  SExpRec_pointer -> (** call **)
  SExpRec_pointer -> (** op **)
  SExpRec_pointer -> (** args **)
  SExpRec_pointer -> (** rho **)
  result SExpRec_pointer.

(** The following type is represented in C as an integer, each of its figure
  (in base 10) representing a different bit of information. **)
Record funtab_eval_arg := make_funtab_eval_arg {
    funtab_eval_arg_internal : bool ; (** Whether it is stored in the array [.Internals] or directly visible. **)
    funtab_eval_arg_eval : bool (** Whether its arguments should be evaluated before calling. **)
  }.

(** FUNTAB **)
Record funtab_cell := make_funtab_cell {
    fun_name : string ;
    fun_cfun : function_code ;
    fun_code : nat ;
    fun_eval : funtab_eval_arg ;
    fun_arity : int
  }.

Definition funtab := option (list funtab_cell).


(** * Global structure of the interpreter **)

(** A structure to deal with infinite execution (which is not allowed in Coq). Inspired from JSCert. **)
Record runs_type : Type := runs_type_intro {
    runs_do_while : forall A, state -> A -> (state -> A -> result bool) -> (state -> A -> result A) -> result A ;
    runs_eval : state -> SExpRec_pointer -> SExpRec_pointer -> result SExpRec_pointer ;
    runs_inherits : state -> SExpRec_pointer -> string -> result bool ;
    runs_getAttrib : state -> SExpRec_pointer -> SExpRec_pointer -> result SExpRec_pointer ;
    runs_R_FunTab : funtab
  }.


(** * Frequent Patterns **)

(** The functions presented here are not from R source code, but
  represent frequent programming pattern in its source code. **)

(** ** While **)

(** A basic C-like loop **)
Definition do_while runs A S (a : A) expr stat : result A :=
  let%success b := expr S a using S in
  if b : bool then
    let%success a := stat S a using S in
    runs_do_while runs S a expr stat
  else
    result_success S a.

Notation "'do%let' a ':=' e 'while' expr 'do' stat 'using' S ',' runs" :=
  (do_while runs S e (fun S a => expr) (fun S a => stat))
  (at level 50, left associativity) : monad_scope.

Notation "'do%let' 'while' expr 'do' stat 'using' S ',' runs" :=
  (do%let _ := tt while expr do stat using S, runs)
  (at level 50, left associativity) : monad_scope.

Notation "'do%let' '(' a1 ',' a2 ')' ':=' a 'while' expr 'do' stat 'using' S ',' runs" :=
  (do%let x := a
   while let (a1, a2) := x in expr
   do let (a1, a2) := x in stat
   using S, runs)
  (at level 50, left associativity) : monad_scope.

Notation "'do%let' '(' a1 ',' a2 ',' a3 ')' ':=' a 'while' expr 'do' stat 'using' S ',' runs" :=
  (do%let x := a
   while let '(a1, a2, a3) := x in expr
   do let '(a1, a2, a3) := x in stat
   using S, runs)
  (at level 50, left associativity) : monad_scope.

Notation "'do%let' '(' a1 ',' a2 ',' a3 ',' a4 ')' ':=' a 'while' expr 'do' stat 'using' S ',' runs" :=
  (do%let x := a
   while let '(a1, a2, a3, a4) := x in expr
   do let '(a1, a2, a3, a4) := x in stat
   using S, runs)
  (at level 50, left associativity) : monad_scope.

Notation "'do%let' '(' a1 ',' a2 ',' a3 ',' a4 ',' a5 ')' ':=' a 'while' expr 'do' stat 'using' S ',' runs" :=
  (do%let x := a
   while let '(a1, a2, a3, a4, a5) := x in expr
   do let '(a1, a2, a3, a4, a5) := x in stat
   using S, runs)
  (at level 50, left associativity) : monad_scope.

Notation "'do%success' 'while' expr 'do' stat 'using' S ',' runs 'in' cont" :=
  (run%success
     do%let while expr
     do stat
     using S, runs using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'do%success' a ':=' e 'while' expr 'do' stat 'using' S ',' runs 'in' cont" :=
  (let%success a :=
     do%let a := e
     while expr
     do stat
     using S, runs using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'do%success' '(' a1 ',' a2 ')' ':=' a 'while' expr 'do' stat 'using' S ',' runs 'in' cont" :=
  (let%success (a1, a2) :=
     do%let (a1, a2) := a
     while expr
     do stat
     using S, runs using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'do%success' '(' a1 ',' a2 ',' a3 ')' ':=' a 'while' expr 'do' stat 'using' S ',' runs 'in' cont" :=
  (let%success (a1, a2, a3) :=
     do%let (a1, a2, a3) := a
     while expr
     do stat
     using S, runs using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'do%success' '(' a1 ',' a2 ',' a3 ',' a4 ')' ':=' a 'while' expr 'do' stat 'using' S ',' runs 'in' cont" :=
  (let%success (a1, a2, a3, a4) :=
     do%let (a1, a2, a3, a4) := a
     while expr
     do stat
     using S, runs using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'do%success' '(' a1 ',' a2 ',' a3 ',' a4 ',' a5 ')' ':=' a 'while' expr 'do' stat 'using' S ',' runs 'in' cont" :=
  (let%success (a1, a2, a3, a4, a5) :=
     do%let (a1, a2, a3, a4, a5) := a
     while expr
     do stat
     using S, runs using S in
   cont)
  (at level 50, left associativity) : monad_scope.


(** ** Fold **)

(** Looping through a list is a frequent pattern in R source code.
  [fold_left_listSxp_gen] corresponds to the C code
  [for (i = l, v = a; i != R_NilValue; i = CDR (i)) v = iterate ( *i, v); v]. **)
Definition fold_left_listSxp_gen runs globals A S (l : SExpRec_pointer) (a : A)
    (iterate : state -> A -> SExpRec_pointer -> SExpRec -> ListSxp_struct -> result A) : result A :=
  do%success (l, a) := (l, a)
  while result_success S (decide (l <> globals R_NilValue))
  do
    read%list l_, l_list := l using S in
    let%success a := iterate S a l l_ l_list using S in
    result_success S (list_cdrval l_list, a)
  using S, runs in
  result_success S a.

Notation "'fold%let' a ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals" :=
  (fold_left_listSxp_gen runs globals S le e (fun S a l l_ l_list => iterate))
  (at level 50, left associativity) : monad_scope.

Notation "'fold%let' 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals" :=
  (fold%let _ := tt
   along le
   as l, l_, l_list
   do iterate
   using S, runs, globals)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%let' '(' a1 ',' a2 ')' ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals" :=
  (fold%let x := e
   along le
   as l, l_, l_list
   do let (a1, a2) := x in iterate
   using S, runs, globals)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%let' '(' a1 ',' a2 ',' a3 ')' ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals" :=
  (fold%let x := e
   along le
   as l, l_, l_list
   do let '(a1, a2, a3) := x in iterate
   using S, runs, globals)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%let' '(' a1 ',' a2 ',' a3 ',' a4 ')' ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals" :=
  (fold%let x := e
   along le
   as l, l_, l_list
   do let '(a1, a2, a3, a4) := x in iterate
   using S, runs, globals)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%let' '(' a1 ',' a2 ',' a3 ',' a4 ',' a5 ')' ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals" :=
  (fold%let x := e
   along le
   as l, l_, l_list
   do let '(a1, a2, a3, a4, a5) := x in iterate
   using S, runs, globals)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%success' 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (run%success
     fold%let
     along le
     as l, l_, l_list
     do iterate
     using S, runs, globals using S in
   cont)
    (at level 50, left associativity) : monad_scope.

Notation "'fold%success' a ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (let%success a :=
     fold%let a := e
     along le
     as l, l_, l_list
     do iterate
     using S, runs, globals using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%success' '(' a1 ',' a2 ')' ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (let%success (a1, a2) :=
     fold%let (a1, a2) := e
     along le
     as l, l_, l_list
     do iterate
     using S, runs, globals using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%success' '(' a1 ',' a2 ',' a3 ')' ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (let%success (a1, a2, a3) :=
     fold%let (a1, a2, a3) := e
     along le
     as l, l_, l_list
     do iterate
     using S, runs, globals using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%success' '(' a1 ',' a2 ',' a3 ',' a4 ')' ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (let%success (a1, a2, a3, a4) :=
     fold%let (a1, a2, a3, a4) := e
     along le
     as l, l_, l_list
     do iterate
     using S, runs, globals using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%success' '(' a1 ',' a2 ',' a3 ',' a4 ',' a5 ')' ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (let%success (a1, a2, a3, a4, a5) :=
     fold%let (a1, a2, a3, a4, a5) := e
     along le
     as l, l_, l_list
     do iterate
     using S, runs, globals using S in
   cont)
  (at level 50, left associativity) : monad_scope.


(** [fold_left_listSxp] corresponds to the C code
  [for (i = l, v = a; i != R_NilValue; i = CDR (i)) v = iterate (CAR (i), TAG (i), v); v]. **)
Definition fold_left_listSxp runs globals A S (l : SExpRec_pointer) (a : A)
    (iterate : state -> A -> SExpRec_pointer -> SExpRec_pointer -> result A) : result A :=
  fold%let a := a
  along l
  as _, _, l_list
  do iterate S a (list_carval l_list) (list_tagval l_list)
  using S, runs, globals.

Notation "'fold%let' a ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals" :=
  (fold_left_listSxp runs globals S le e (fun S a l_car l_tag => iterate))
  (at level 50, left associativity) : monad_scope.

Notation "'fold%let' '(' a1 ',' a2 ')' ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals" :=
  (fold%let x := e
   along le
   as l_car, l_tag
   do let (a1, a2) := x in iterate
   using S, runs, globals)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%let' '(' a1 ',' a2 ',' a3 ')' ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals" :=
  (fold%let x := e
   along le
   as l_car, l_tag
   do let '(a1, a2, a3) := x in iterate
   using S, runs, globals)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%let' '(' a1 ',' a2 ',' a3 ',' a4 ')' ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals" :=
  (fold%let x := e
   along le
   as l_car, l_tag
   do let '(a1, a2, a3, a4) := x in iterate
   using S, runs, globals)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%let' '(' a1 ',' a2 ',' a3 ',' a4 ',' a5 ')' ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals" :=
  (fold%let x := e
   along le
   as l_car, l_tag
   do let '(a1, a2, a3, a4, a5) := x in iterate
   using S, runs, globals)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%success' 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (run%success
     fold%let _ := tt
     along le
     as l_car, l_tag
     do iterate
     using S, runs, globals using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%success' a ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (let%success a :=
     fold%let a := e
     along le
     as l_car, l_tag
     do iterate
     using S, runs, globals using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%success' '(' a1 ',' a2 ')' ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (let%success (a1, a2) :=
     fold%let (a1, a2) := e
     along le
     as l_car, l_tag
     do iterate
     using S, runs, globals using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%success' '(' a1 ',' a2 ',' a3 ')' ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (let%success (a1, a2, a3) :=
     fold%let (a1, a2, a3) := e
     along le
     as l_car, l_tag
     do iterate
     using S, runs, globals using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%success' '(' a1 ',' a2 ',' a3 ',' a4 ')' ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (let%success (a1, a2, a3, a4) :=
     fold%let (a1, a2, a3, a4) := e
     along le
     as l_car, l_tag
     do iterate
     using S, runs, globals using S in
   cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%success' '(' a1 ',' a2 ',' a3 ',' a4 ',' a5 ')' ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (let%success (a1, a2, a3, a4, a5) :=
     fold%let (a1, a2, a3, a4, a5) := e
     along le
     as l_car, l_tag
     do iterate
     using S, runs, globals using S in
   cont)
  (at level 50, left associativity) : monad_scope.


(** ** Return **)

(** The following notations deal with loops that may return.
  In these cases, one can use the definitions [result_rsuccess],
  or [result_rskip] for a normal ending of the loop, and
  [result_rreturn] for a breaking return. Note that this only
  breaks the current loop and its continuation, not the whole
  function. **)

Inductive normal_return A B :=
  | normal_result : A -> normal_return A B
  | return_result : B -> normal_return A B
  .
Arguments normal_result {A B}.
Arguments return_result {A B}.

Definition result_rsuccess {A B} S r : result (normal_return A B) :=
  result_success S (normal_result r).

Definition result_rskip {B} S : result (normal_return _ B) :=
  result_rsuccess S tt.

Definition result_rreturn {A B} S r : result (normal_return A B) :=
  result_success S (return_result r).

Definition match_rresult {A B C} (r : result (normal_return A B)) cont
    : result (normal_return C B) :=
  let%success res := r using S in
  match res with
  | normal_result r => cont S r
  | return_result r => result_rreturn S r
  end.

Notation "'let%return' a ':=' e 'using' S 'in' cont" :=
  (match_rresult e (fun S a => cont))
  (at level 50, left associativity) : monad_scope.

Notation "'run%return' c 'using' S 'in' cont" :=
  (let%return _ := c using S in cont)
  (at level 50, left associativity) : monad_scope.

(** Exiting the return-monad. **)
Definition exit_rresult {A B} (r : result (normal_return A B)) cont :=
  let%success res := r using S in
  match res with
  | normal_result r => cont S r
  | return_result r => result_success S r
  end.

Definition continue_and_condition {A B} S (r : normal_return A B) cond :=
  match r with
  | normal_result r => cond S r
  | return_result r => result_success S false
  end.

Definition get_success {A B} S (r : normal_return A B) cont
    : result (normal_return A B) :=
  match r with
  | normal_result r => cont S r
  | return_result r => result_rreturn S r
  end.


Notation "'do%return' 'while' expr 'do' stat 'using' S ',' runs 'in' cont" :=
  (exit_rresult
     (do%let ret := normal_result tt
      while continue_and_condition S ret (fun S _ => expr)
      do stat
      using S, runs)
     (fun S _ => cont))
  (at level 50, left associativity) : monad_scope.

Notation "'do%return' a ':=' e 'while' expr 'do' stat 'using' S ',' runs 'in' cont" :=
  (exit_rresult
     (do%let a := normal_result e
      while continue_and_condition S a (fun S a => expr)
      do get_success S a (fun S a => stat)
      using S, runs)
     (fun S a => cont))
  (at level 50, left associativity) : monad_scope.

Notation "'do%return' '(' a1 ',' a2 ')' ':=' e 'while' expr 'do' stat 'using' S ',' runs 'in' cont" :=
  (do%return a := e
   while let (a1, a2) := a in expr
   do let (a1, a2) := a in stat
   using S, runs
   in let (a1, a2) := a in cont)
  (at level 50, left associativity) : monad_scope.

Notation "'do%return' '(' a1 ',' a2 ',' a3 ')' ':=' e 'while' expr 'do' stat 'using' S ',' runs 'in' cont" :=
  (do%return a := e
   while let (a1, a2, a3) := a in expr
   do let (a1, a2, a3) := a in stat
   using S, runs
   in let (a1, a2, a3) := a in cont)
  (at level 50, left associativity) : monad_scope.

Notation "'do%return' '(' a1 ',' a2 ',' a3 ',' a4 ')' ':=' e 'while' expr 'do' stat 'using' S ',' runs 'in' cont" :=
  (do%return a := e
   while let (a1, a2, a3, a4) := a in expr
   do let (a1, a2, a3, a4) := a in stat
   using S, runs
   in let (a1, a2, a3, a4) := a in cont)
  (at level 50, left associativity) : monad_scope.

Notation "'do%return' '(' a1 ',' a2 ',' a3 ',' a4 ',' a5 ')' ':=' e 'while' expr 'do' stat 'using' S ',' runs 'in' cont" :=
  (do%return a := e
   while let (a1, a2, a3, a4, a5) := a in expr
   do let (a1, a2, a3, a4, a5) := a in stat
   using S, runs
   in let (a1, a2, a3, a4, a5) := a in cont)
  (at level 50, left associativity) : monad_scope.


Notation "'fold%return' a ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (exit_rresult
     (fold%let a := normal_result e
      along le
      as l, l_, l_list
      do get_success S a (fun S a => iterate)
      using S, runs, globals)
     (fun S a => cont))
  (at level 50, left associativity) : monad_scope.

Notation "'fold%return' 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (fold%return ret := tt
   along le
   as l, l_, l_list
   do iterate
   using S, runs, globals in cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%return' '(' a1 ',' a2 ')' ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (fold%return a := e
   along le
   as l, l_, l_list
   do let (a1, a2) := a in iterate
   using S, runs, globals in let (a1, a2) := a in cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%return' '(' a1 ',' a2 ',' a3 ')' ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (fold%return a := e
   along le
   as l, l_, l_list
   do let (a1, a2, a3) := a in iterate
   using S, runs, globals in let (a1, a2, a3) := a in cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%return' '(' a1 ',' a2 ',' a3 ',' a4 ')' ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (fold%return a := e
   along le
   as l, l_, l_list
   do let (a1, a2, a3, a4) := a in iterate
   using S, runs, globals in let (a1, a2, a3, a4) := a in cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%return' '(' a1 ',' a2 ',' a3 ',' a4 ',' a5 ')' ':=' e 'along' le 'as' l ',' l_ ',' l_list 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (fold%return a := e
   along le
   as l, l_, l_list
   do let (a1, a2, a3, a4, a5) := a in iterate
   using S, runs, globals in let (a1, a2, a3, a4, a5) := a in cont)
  (at level 50, left associativity) : monad_scope.


Notation "'fold%return' a ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (exit_rresult
     (fold%let a := normal_result e
      along le
      as l_car, l_tag
      do get_success S a (fun S a => iterate)
      using S, runs, globals)
     (fun S a => cont))
  (at level 50, left associativity) : monad_scope.

Notation "'fold%return' 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (fold%return ret := tt
   along le
   as l_car, l_tag
   do iterate
   using S, runs, globals in cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%return' '(' a1 ',' a2 ')' ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (fold%return a := e
   along le
   as l_car, l_tag
   do let (a1, a2) := a in iterate
   using S, runs, globals in let (a1, a2) := a in cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%return' '(' a1 ',' a2 ',' a3 ')' ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (fold%return a := e
   along le
   as l_car, l_tag
   do let (a1, a2, a3) := a in iterate
   using S, runs, globals in let (a1, a2, a3) := a in cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%return' '(' a1 ',' a2 ',' a3 ',' a4 ')' ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (fold%return a := e
   along le
   as l_car, l_tag
   do let (a1, a2, a3, a4) := a in iterate
   using S, runs, globals in let (a1, a2, a3, a4) := a in cont)
  (at level 50, left associativity) : monad_scope.

Notation "'fold%return' '(' a1 ',' a2 ',' a3 ',' a4 ',' a5 ')' ':=' e 'along' le 'as' l_car ',' l_tag 'do' iterate 'using' S ',' runs ',' globals 'in' cont" :=
  (fold%return a := e
   along le
   as l_car, l_tag
   do let (a1, a2, a3, a4, a5) := a in iterate
   using S, runs, globals in let (a1, a2, a3, a4, a5) := a in cont)
  (at level 50, left associativity) : monad_scope.
