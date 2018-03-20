(** Invariants.
  States some invariants of R’s heap, as well as tactics to manipulate it. **)

Set Implicit Arguments.
Require Import TLC.LibBag Paco.paco.
Require Export Path MonadTactics.

Open Scope list_scope. (* FIXME: How to disable some notations of LibBag? *)


(** * Predicates to speak about the memory **)

(** ** A pointer is valid **)

Definition bound_such_that (S : state) P p :=
  exists p_, read_SExp S p = Some p_ /\ P p_.

Definition bound S := bound_such_that S (fun _ => True).

Lemma bound_such_that_weaken : forall S (P1 P2 : _ -> Prop) p,
  (forall p_, P1 p_ -> P2 p_) ->
  bound_such_that S P1 p ->
  bound_such_that S P2 p.
Proof. introv I (p_&E&H). exists* p_. Qed.

Lemma bound_write : forall S S' p p' p_,
  write_SExp S p p_ = Some S' ->
  bound S p' ->
  bound S' p'.
Proof.
  introv W (p'_&R&_). tests D: (p = p').
  - exists p_. splits~. applys~ read_write_SExp_eq W.
  - exists p'_. splits~. rewrites~ >> read_write_SExp_neq W D.
Qed.


(** ** Typed pointers **)

Definition may_have_types S l :=
  bound_such_that S (fun p_ => type p_ \in l).

Lemma may_have_types_bound : forall S p l,
  may_have_types S l p ->
  bound S p.
Proof. introv. apply* bound_such_that_weaken. Qed.

Lemma may_have_types_nil : forall S p,
  ~ may_have_types S nil p.
Proof. introv (p_&E&M). applys~ BagInEmpty_list M. Qed.

Lemma may_have_types_cons : forall S t l p,
  may_have_types S (t :: l) p <->
  may_have_types S ([t]) p \/ may_have_types S l p.
Proof.
  introv. iff I.
  - forwards (p_&E&M): (rm I). apply BagIn_cons in M. forwards [M'|M']: (rm M).
    + left. exists p_. splits~. apply~ BagInSingle_list.
    + right. exists* p_.
  - forwards [(p_&E&M)|(p_&E&M)]: (rm I); exists p_; splits~; apply* BagIn_cons.
    left. apply~ BagInSingle_list.
Qed.

Lemma may_have_types_merge : forall S p l1 l2,
  may_have_types S l1 p ->
  may_have_types S l2 p ->
  may_have_types S (l1 \n l2) p.
Proof.
  introv (p1_&E1&M1) (p2_&E2&M2).
  rewrite E1 in E2. inverts E2. exists p2_. splits~.
  rewrite~ BagInter_list.
Qed.

Lemma may_have_types_weaken : forall S p l1 l2,
  may_have_types S l1 p ->
  l1 \c l2 ->
  may_have_types S l2 p.
Proof. introv T I. applys~ bound_such_that_weaken T. introv M. applys~ BagInIncl M I. Qed.

Lemma may_have_types_write_SExp : forall S S' p p' p_ l,
  write_SExp S p p_ = Some S' ->
  may_have_types S l p' ->
  p <> p' ->
  may_have_types S' l p'.
Proof. introv W (p'_&E&T) D. exists p'_. splits~. rewrites~ >> read_write_SExp_neq W D. Qed.

Lemma may_have_types_write_SExp_eq : forall S S' p p_ l,
  write_SExp S p p_ = Some S' ->
  type p_ \in l ->
  may_have_types S' l p.
Proof. introv W I. exists p_. splits~. applys~ read_write_SExp_eq W. Qed.

Lemma may_have_types_write_SExp_eq_exact : forall S S' p p_ t,
  write_SExp S p p_ = Some S' ->
  type p_ = t ->
  may_have_types S' ([t]) p.
Proof. introv W E. applys~ may_have_types_write_SExp_eq W. apply~ BagInSingle_list. Qed.

Lemma may_have_types_read_SExp : forall S l p p_,
  may_have_types S l p ->
  read_SExp S p = Some p_ ->
  type p_ \in l.
Proof. introv (p_'&E&T) R. rewrite E in R. inverts~ R. Qed.

Lemma read_SExp_may_have_types_read : forall (S : state) l p p_,
  read_SExp S p = Some p_ ->
  type p_ \in l ->
  may_have_types S l p.
Proof. introv E T. exists p_. splits~. Qed.

Lemma read_SExp_may_have_types_read_exact : forall (S : state) t p p_,
  read_SExp S p = Some p_ ->
  type p_ = t ->
  may_have_types S ([t]) p.
Proof. introv E T. applys read_SExp_may_have_types_read E. substs. Mem_solve. Qed.


(** ** List pointers **)

Definition list_type_head_such_that P Pheader Pcar Ptag S l_t l_car l_tag (p_ : SExpRec) :=
  exists header car cdr tag,
    p_ = make_NonVector_SExpRec header (make_ListSxp_struct car cdr tag)
    /\ type p_ \in l_t /\ Pheader header
    /\ may_have_types S l_car car /\ Pcar car
    /\ P S l_t l_car l_tag cdr
    /\ may_have_types S l_tag tag /\ Ptag tag.

Definition list_type_step_such_that P Pheader Pcar Ptag (S : state) l_t l_car l_tag :=
  bound_such_that S (list_type_head_such_that P Pheader Pcar Ptag S l_t l_car l_tag).

Inductive list_type_such_that Pheader Pcar Ptag (S : state) : list SExpType -> list SExpType -> list SExpType -> SEXP -> Prop :=
  | list_type_nil : forall p l_t l_car l_tag,
    may_have_types S ([NilSxp]) p ->
    list_type_such_that Pheader Pcar Ptag S l_t l_car l_tag p
  | list_type_cons : forall p l_t l_car l_tag,
    list_type_step_such_that (list_type_such_that Pheader Pcar Ptag) Pheader Pcar Ptag S l_t l_car l_tag p ->
    list_type_such_that Pheader Pcar Ptag S l_t l_car l_tag p
  .

Definition list_head_such_that Pheader Pcar Ptag :=
  list_type_head_such_that (list_type_such_that Pheader Pcar Ptag) Pheader Pcar Ptag.

Definition list_type := list_type_such_that (fun _ => True) (fun _ => True) (fun _ => True).
Definition list_head := list_head_such_that (fun _ => True) (fun _ => True) (fun _ => True).

Fixpoint list_type_ind (Pheader Pcar Ptag : _ -> Prop) S
    (P : list SExpType -> list SExpType -> list SExpType -> SEXP -> Prop)
    (f_nil : forall p l_t l_car l_tag,
       may_have_types S ([NilSxp]) p ->
       P l_t l_car l_tag p)
    (f_cons : forall p l_t l_car l_tag p_ header car cdr tag,
       read_SExp S p = Some p_ ->
       p_ = make_NonVector_SExpRec header (make_ListSxp_struct car cdr tag) ->
       type p_ \in l_t ->
       Pheader header ->
       may_have_types S l_car car ->
       Pcar car ->
       list_type_such_that Pheader Pcar Ptag S l_t l_car l_tag cdr ->
       may_have_types S l_tag tag ->
       Ptag tag ->
       P l_t l_car l_tag cdr ->
       P l_t l_car l_tag p)
    l_t l_car l_tag p (HL : list_type_such_that Pheader Pcar Ptag S l_t l_car l_tag p) : P l_t l_car l_tag p.
  refine (
    match HL in list_type_such_that _ _ _ _ l_t l_car l_tag p return P l_t l_car l_tag p with
    | @list_type_nil _ _ _ _ p l_t l_car l_tag N =>
      f_nil p l_t l_car l_tag N
    | @list_type_cons _ _ _ _ p l_t l_car l_tag N => _
    end).
  destruct N as (p_&E&h&car&cdr&tag&M&H&HH&A&HA&L&T&HT).
  refine (f_cons p l_t l_car l_tag _ _ _ _ _ E M H HH A HA L T HT _).
  applys~ list_type_ind f_nil f_cons.
Defined.

Lemma list_head_may_have_types : forall S Pheader Pcar Ptag l_t l_car l_tag p_,
  list_head_such_that Pheader Pcar Ptag S l_t l_car l_tag p_ ->
  type p_ \in l_t.
Proof. introv (h&car&cdr&tag&M&H&HH&A&HA&L&T&HT). substs~. Qed.

Lemma list_type_may_have_types : forall S l_t l_car l_tag p,
  list_type S l_t l_car l_tag p ->
  may_have_types S (l_t \u [NilSxp]) p.
Proof.
  introv I. destruct~ I as [? ? ? ? I|? ? ? ? (p_&E&h&car&cdr&tag&M&H&HH&A&AH&L&T&HT)].
  - applys~ may_have_types_weaken I. apply~ BagUnionIncl_right.
  - exists p_. splits~. applys~ BagInIncl H. apply~ BagUnionIncl_left.
Qed.

Lemma list_type_merge : forall Pheader Pcar Ptag S p l1_t l2_t l1_car l2_car l1_tag l2_tag,
  list_type_such_that Pheader Pcar Ptag S l1_t l1_car l1_tag p ->
  list_type_such_that Pheader Pcar Ptag S l2_t l2_car l2_tag p ->
  list_type_such_that Pheader Pcar Ptag S (l1_t \n l2_t) (l1_car \n l2_car) (l1_tag \n l2_tag) p.
Proof.
  introv T1 T2. gen l2_t l2_car l2_tag.
  induction T1 as [? ? ? ? I1|? ? ? ? p1_ h1 car1 cdr1 tag1 E1 M1 H1 HH1 A1 HA1 L1 T1 HT1 IH]
    using list_type_ind; introv T.
  - apply~ list_type_nil.
  - inverts T as T.
    + apply~ list_type_nil.
    + inverts T as (E2&h2&car2&cdr2&tag2&M2&H2&HH2&A2&HA2&L2&T2&HT2).
      rewrite E2 in E1. inversion E1 as [E1']. rewrite E1' in *.
      rewrite M1 in M2. inverts M2.
      apply list_type_cons. exists p1_. splits~. exists h2 car2 cdr2 tag2. splits~.
      * apply BagInter_list. splits~.
      * applys~ may_have_types_merge A1 A2.
      * applys~ may_have_types_merge T1 T2.
Qed.

Lemma list_type_head_such_that_weaken : forall (P1 P2 : _ -> _ -> _ -> _ -> _ -> Prop)
    (P1header P2header P1car P2car P1tag P2tag : _ -> Prop) S l1_t l2_t l1_car l2_car l1_tag l2_tag p_,
  l1_t \c l2_t ->
  l1_car \c l2_car ->
  l1_tag \c l2_tag ->
  (forall p, P1 S l1_t l1_car l1_tag p -> P2 S l2_t l2_car l2_tag p) ->
  (forall p, P1header p -> P2header p) ->
  (forall p, P1car p -> P2car p) ->
  (forall p, P1tag p -> P2tag p) ->
  list_type_head_such_that P1 P1header P1car P1tag S l1_t l1_car l1_tag p_ ->
  list_type_head_such_that P2 P2header P2car P2tag S l2_t l2_car l2_tag p_.
Proof.
  introv I1 I2 I3 I Iheader Icar Itag (h&car&cdr&tag&E&T&HH&Mcar&Hcar&IH&Mtag&Htag).
  exists h car cdr tag. splits~.
  - applys~ BagInIncl I1.
  - applys~ may_have_types_weaken Mcar.
  - applys~ may_have_types_weaken Mtag.
Qed.

Lemma list_type_weaken : forall (P1header P2header P1car P2car P1tag P2tag : _ -> Prop)
    S p l1_t l2_t l1_car l2_car l1_tag l2_tag,
  l1_t \c l2_t ->
  l1_car \c l2_car ->
  l1_tag \c l2_tag ->
  (forall p, P1header p -> P2header p) ->
  (forall p, P1car p -> P2car p) ->
  (forall p, P1tag p -> P2tag p) ->
  list_type_such_that P1header P1car P1tag S l1_t l1_car l1_tag p ->
  list_type_such_that P2header P2car P2tag S l2_t l2_car l2_tag p.
Proof.
  introv I1 I2 I3 Iheader Icar Itag T. gen l2_t l2_car l2_tag.
  induction T as [? ? ? ? I1|? ? ? ? p_ h car cdr tag E M H HH A HA L T HT IH]
    using list_type_ind; introv Incl1 Incl2 Incl3.
  - apply~ list_type_nil.
  - apply list_type_cons. exists p_. splits~. exists h car cdr tag. splits~.
    + applys~ BagInIncl H Incl1.
    + applys~ may_have_types_weaken A Incl2.
    + applys~ may_have_types_weaken T Incl3.
Qed.

Lemma list_head_such_that_weaken : forall (P1header P2header P1car P2car P1tag P2tag : _ -> Prop)
    S l1_t l2_t l1_car l2_car l1_tag l2_tag p_,
  l1_t \c l2_t ->
  l1_car \c l2_car ->
  l1_tag \c l2_tag ->
  (forall p, P1header p -> P2header p) ->
  (forall p, P1car p -> P2car p) ->
  (forall p, P1tag p -> P2tag p) ->
  list_head_such_that P1header P1car P1tag S l1_t l1_car l1_tag p_ ->
  list_head_such_that P2header P2car P2tag S l2_t l2_car l2_tag p_.
Proof.
  introv I1 I2 I3 Iheader Icar Itag L. applys~ list_type_head_such_that_weaken L.
  introv L'. applys~ list_type_weaken Icar Itag L'.
Qed.


(** * Invariants about the state. **)

(** ** Invariants **)

Inductive null_pointer_exceptions_entry_point : entry_point -> Prop :=
  | null_pointer_exceptions_context_promargs :
    null_pointer_exceptions_entry_point
      (Econtext (context_path_entry Pstate_context) Scontext_promargs)
  | null_pointer_exceptions_context_callfun :
    null_pointer_exceptions_entry_point
      (Econtext (context_path_entry Pstate_context) Scontext_callfun)
  | null_pointer_exceptions_context_sysparent :
    null_pointer_exceptions_entry_point
      (Econtext (context_path_entry Pstate_context) Scontext_sysparent)
  | null_pointer_exceptions_context_call :
    null_pointer_exceptions_entry_point
      (Econtext (context_path_entry Pstate_context) Scontext_call)
  | null_pointer_exceptions_context_cloenv :
    null_pointer_exceptions_entry_point
      (Econtext (context_path_entry Pstate_context) Scontext_cloenv)
  | null_pointer_exceptions_context_conexit :
    null_pointer_exceptions_entry_point
      (Econtext (context_path_entry Pstate_context) Scontext_conexit)
  | null_pointer_exceptions_context_returnValue : forall cp,
    null_pointer_exceptions_entry_point (Econtext cp Scontext_returnValue)
  .

Inductive null_pointer_exceptions_suffix : path_step -> Prop :=
  | null_pointer_symbol_value :
    null_pointer_exceptions_suffix (SNonVectorSym Ssym_value)
  (* FIXME: BindData_ans_ptr *)
  (* FIXME: BindData_ans_names *)
  .

Inductive null_pointer_exceptions_path : path -> Prop :=
  | null_pointer_exceptions_path_entry_point : forall e,
    null_pointer_exceptions_entry_point e ->
    null_pointer_exceptions_path (Pentry e)
  | null_pointer_exceptions_path_suffix : forall s p,
    null_pointer_exceptions_suffix s ->
    Path.last p s ->
    null_pointer_exceptions_path p
  .

Inductive safe_SExpRec_type safe_header (safe_pointer : _ -> _ -> Prop) S : SExpType -> SExpRec -> Prop :=
  | SExpType_corresponds_to_data_NilSxp : forall header car cdr tag,
      may_have_types S ([NilSxp]) car ->
      safe_pointer S car ->
      may_have_types S ([NilSxp]) cdr ->
      safe_pointer S cdr ->
      may_have_types S ([NilSxp]) tag ->
      safe_pointer S tag ->
      safe_SExpRec_type safe_header safe_pointer S NilSxp (make_NonVector_SExpRec header (make_ListSxp_struct car cdr tag))
  | SExpType_corresponds_to_data_SymSxp : forall header pname value internal,
      may_have_types S ([CharSxp]) pname ->
      safe_pointer S pname ->
      (* may_have_types S ([(*TODO*)]) value -> *)
      safe_pointer S value ->
      (* may_have_types S ([(*TODO*) internal]) -> *)
      safe_pointer S internal ->
      safe_SExpRec_type safe_header safe_pointer S SymSxp (make_NonVector_SExpRec header (make_SymSxp_struct pname value internal))
  | SExpType_corresponds_to_data_ListSxp : forall e_,
      list_head_such_that (safe_header S) (safe_pointer S) (safe_pointer S) S
         ([ListSxp]) all_storable_SExpTypes ([NilSxp ; CharSxp]) e_ ->
      safe_SExpRec_type safe_header safe_pointer S ListSxp e_
  | SExpType_corresponds_to_data_CloSxp : forall header formals body env,
      list_type_such_that (safe_header S) (safe_pointer S) (safe_pointer S) S
        ([ListSxp]) all_storable_SExpTypes(*TODO*) ([NilSxp ; CharSxp]) formals ->
      (* may_have_types S ([(*TODO*)]) body -> *)
      may_have_types S ([EnvSxp]) env ->
      safe_pointer S env ->
      safe_SExpRec_type safe_header safe_pointer S CloSxp (make_NonVector_SExpRec header (make_CloSxp_struct formals body env))
  | SExpType_corresponds_to_data_EnvSxp : forall header frame enclos,
      list_type_such_that (safe_header S) (safe_pointer S) (safe_pointer S) S
        ([ListSxp]) all_storable_SExpTypes(*TODO*) ([NilSxp ; CharSxp]) frame ->
      may_have_types S ([EnvSxp]) enclos ->
      safe_pointer S enclos ->
      safe_SExpRec_type safe_header safe_pointer S EnvSxp (make_NonVector_SExpRec header (make_EnvSxp_struct frame enclos))
  | SExpType_corresponds_to_data_SpecialSxp : forall header offset,
      safe_SExpRec_type safe_header safe_pointer S SpecialSxp (make_NonVector_SExpRec header (make_PrimSxp_struct offset))
  | SExpType_corresponds_to_data_BuiltinSxp : forall header offset,
      safe_SExpRec_type safe_header safe_pointer S BuiltinSxp (make_NonVector_SExpRec header (make_PrimSxp_struct offset))
  | SExpType_corresponds_to_data_CharSxp : forall header array,
      safe_SExpRec_type safe_header safe_pointer S CharSxp
        (SExpRec_VectorChar (make_Vector_SExpRec header
          (make_VecSxp_struct (ArrayList.length array) (ArrayList.length array) array)))
  | SExpType_corresponds_to_data_LglSxp : forall header array,
      safe_SExpRec_type safe_header safe_pointer S LglSxp
        (SExpRec_VectorLogical (make_Vector_SExpRec header
          (make_VecSxp_struct (ArrayList.length array) (ArrayList.length array) array)))
  | SExpType_corresponds_to_data_IntSxp : forall header array,
      safe_SExpRec_type safe_header safe_pointer S IntSxp
        (SExpRec_VectorInteger (make_Vector_SExpRec header
          (make_VecSxp_struct (ArrayList.length array) (ArrayList.length array) array)))
  | SExpType_corresponds_to_data_RealSxp : forall header array,
      safe_SExpRec_type safe_header safe_pointer S RealSxp
        (SExpRec_VectorReal (make_Vector_SExpRec header
          (make_VecSxp_struct (ArrayList.length array) (ArrayList.length array) array)))
  | SExpType_corresponds_to_data_CplxSxp : forall header array,
      safe_SExpRec_type safe_header safe_pointer S CplxSxp
        (SExpRec_VectorComplex (make_Vector_SExpRec header
           (make_VecSxp_struct (ArrayList.length array) (ArrayList.length array) array)))
  | SExpType_corresponds_to_data_StrSxp : forall header array,
      (forall a,
        Mem a (ArrayList.to_list array) ->
        may_have_types S ([CharSxp]) a /\ safe_pointer S a) ->
      safe_SExpRec_type safe_header safe_pointer S StrSxp
        (SExpRec_VectorPointer (make_Vector_SExpRec header
          (make_VecSxp_struct (ArrayList.length array) (ArrayList.length array) array)))
  | SExpType_corresponds_to_data_DotSxp : forall e_,
      list_head_such_that (safe_header S) (safe_pointer S) (safe_pointer S) S
        ([ListSxp ; DotSxp]) all_storable_SExpTypes ([NilSxp]) e_  ->
      safe_SExpRec_type safe_header safe_pointer S DotSxp e_
  (** The type [AnySxp] does not appear as the type of a C object,
    Thus no constructor is associated to this type. **)
  | SExpType_corresponds_to_data_VecSxp : forall header array,
        (* (forall a,
          Mem a (ArrayList.to_list array) ->
          may_have_types S ([(*TODO*)]) a /\ safe_pointer S a) -> *)
      safe_SExpRec_type safe_header safe_pointer S VecSxp
        (SExpRec_VectorPointer (make_Vector_SExpRec header
          (make_VecSxp_struct (ArrayList.length array) (ArrayList.length array) array)))
  | SExpType_corresponds_to_data_ExprSxp : forall header array,
      (* (forall a,
        Mem a (ArrayList.to_list array) ->
        may_have_types S ([(*TODO*)]) a /\ safe_pointer S a) -> *)
      safe_SExpRec_type safe_header safe_pointer S ExprSxp
        (SExpRec_VectorPointer (make_Vector_SExpRec header
          (make_VecSxp_struct (ArrayList.length array) (ArrayList.length array) array)))
  (** The following four types have not been implemented. **)
  | SExpType_corresponds_to_data_BcodeSxp : forall e_,
      safe_SExpRec_type safe_header safe_pointer S BcodeSxp e_
  | SExpType_corresponds_to_data_ExtptrSxp : forall e_,
      safe_SExpRec_type safe_header safe_pointer S ExtptrSxp e_
  | SExpType_corresponds_to_data_RawSxp : forall e_,
      safe_SExpRec_type safe_header safe_pointer S RawSxp e_
  | SExpType_corresponds_to_data_S4Sxp : forall e_,
      safe_SExpRec_type safe_header safe_pointer S S4Sxp e_
  (** The two types [NewSxp] and [FreeSxp] are only used in the
    garbage collector, which has not been formalised.  They thus never
    appear in our memory, and no constructor is associated to
    these types. **)
  (** The type [FunSxp] is not possible as the type of a C object,
    as it would need more bytes than actually present.  It is
    rewriten in practise into CloSxp if someone tries to put it into
    an object. Again, no constructor is associated to this type. **)
  .

Record safe_header (safe_pointer : state -> _ -> Prop) S (h : SExpRecHeader) : Prop := make_safe_header {
    safe_attrib : safe_pointer S (attrib h)
  }.

Record safe_SExpRec_gen safe_pointer S (e_ : SExpRec) : Prop := make_safe_SExpRec {
    SExpType_corresponds_to_datatype :
      safe_SExpRec_type (safe_header safe_pointer) safe_pointer S (type e_) e_
  }.

Record safe_pointer_gen (safe_pointer : _ -> _ -> Prop) S p : Prop := make_safe_pointer {
    pointer_bound : bound S p ;
    no_null_pointer_along_path_step : forall s p',
      ~ null_pointer_exceptions_suffix s ->
      move_along_path_step s S p = Some p' ->
      p' <> NULL ;
    safe_pointer_along_path_step : forall s e,
      move_along_path_step s S p = Some e ->
      e <> NULL ->
      safe_pointer S e ;
    safe_SExpRec_read : forall p_,
      read_SExp S p = Some p_ ->
      safe_SExpRec_gen safe_pointer S p_
  }.

Definition safe_pointer S p := paco2 safe_pointer_gen bot2 S p.
Hint Unfold safe_pointer.

Lemma safe_pointer_gen_mon : monotone2 safe_pointer_gen.
Proof.
  pmonauto.
  repeat intro. destruct IN as [B OKf OKs R]. constructors*.
  introv E. forwards [IH]: R E. constructors.
  inverts IH; constructors~;
    try match goal with
    | H : list_head_such_that _ _ _ _ _ _ _ _ |- list_head_such_that _ _ _ _ _ _ _ _ =>
      applys~ list_head_such_that_weaken H;
      (apply BagIncl_refl || let M := fresh "M" in introv M; destruct M; constructors~)
    | H : list_type_such_that _ _ _ _ _ _ _ _ |- list_type_such_that _ _ _ _ _ _ _ _ =>
      applys~ list_type_weaken H;
      (apply BagIncl_refl || let M := fresh "M" in introv M; destruct M; constructors~)
    | H : _ |- _ => let M := fresh "M" in introv M; forwards* [? ?]: H M
    end.
Qed.
Hint Resolve safe_pointer_gen_mon : paco.

Lemma safe_pointer_rewrite : safe_pointer = safe_pointer_gen safe_pointer.
Proof.
  extens. intros S p. iff I.
  - punfold I. applys_eq I 3. extens. clear. intros S p. iff I.
    + left~.
    + inverts I as I; [ autos* | inverts I ].
  - pfold. applys_eq I 3. extens. clear. intros S p. iff I.
    + inverts I as I; [ autos* | inverts I ].
    + left~.
Qed.

Definition safe_SExpRec := safe_SExpRec_gen safe_pointer.

Definition list_type_safe S := list_type_such_that (safe_header safe_pointer S) (safe_pointer S) (safe_pointer S) S.
Definition list_head_safe S := list_head_such_that (safe_header safe_pointer S) (safe_pointer S) (safe_pointer S) S.

Record safe_state S : Prop := make_safe_state {
    no_null_pointer_entry_point : forall e p,
      ~ null_pointer_exceptions_entry_point e ->
      move_along_entry_point e S = Some p ->
      p <> NULL ;
    safe_entry_points : forall e p,
      move_along_entry_point e S = Some p ->
      p <> NULL ->
      safe_pointer S p ;
    only_one_nil : forall p1 p2,
      may_have_types S ([NilSxp]) p1 ->
      may_have_types S ([NilSxp]) p2 ->
      p1 = p2
  }.

Inductive null_pointer_exceptions_globals : GlobalVariable -> Prop := .

Record safe_globals S globals : Prop := make_safe_globals {
    globals_not_NULL : forall g,
      ~ null_pointer_exceptions_globals g ->
      read_globals globals g <> NULL ;
    globals_not_NULL_safe : forall g,
      read_globals globals g <> NULL ->
      safe_pointer S (read_globals globals g) ;
    R_NilValue_may_have_types : may_have_types S ([NilSxp]) (read_globals globals R_NilValue)
  }.


(** ** Transitions between states **)

Record conserve_old_binding S S' : Prop := make_conserve_old_binding {
    conserve_old_binding_binding : forall p,
      bound S p ->
      bound_such_that S (fun e_ =>
        bound_such_that S' (fun e'_ => e_ = e'_) p) p ;
    conserve_old_binding_entry_point : forall e,
      move_along_entry_point e S = move_along_entry_point e S'
  }.


(** ** Lemmae **)

Lemma safe_pointer_along_path_from_incl : forall (safe_pointer' : _ -> _ -> Prop) S p path e,
  (forall S p, safe_pointer' S p -> safe_pointer_gen safe_pointer' S p) ->
  safe_pointer' S p ->
  move_along_path_from path S p = Some e ->
  e <> NULL ->
  safe_pointer' S e.
Proof.
  introv Incl OKp E D. gen p e. induction path; introv OKp E D.
  - rewrite move_along_path_from_nil in E. inverts~ E.
  - forwards (e2&E1&E2): move_along_path_from_cons_inv E.
    applys~ IHpath E2. applys~ safe_pointer_along_path_step E1.
    introv ?. substs. destruct path.
    + rewrite move_along_path_from_nil in E2. inverts~ E2.
    + rewrite move_along_path_from_NULL in E2; [ inverts E2 | discriminate ].
Qed.

Lemma safe_pointer_along_path_from : forall S p path e,
  safe_pointer S p ->
  move_along_path_from path S p = Some e ->
  e <> NULL ->
  safe_pointer S e.
Proof.
  introv. applys~ safe_pointer_along_path_from_incl.
  clear. introv OKp. rewrite~ <- safe_pointer_rewrite.
Qed.

Lemma safe_pointer_not_NULL : forall S p,
  safe_pointer S p ->
  p <> NULL.
Proof.
  introv OKp E. rewrite safe_pointer_rewrite in OKp.
  forwards (p_&B&?): pointer_bound OKp. substs. rewrite read_SExp_NULL in B. inverts~ B.
Qed.

Lemma no_null_pointer_along_path_from : forall S p p' path,
  safe_pointer S p ->
  (forall s,
    s \in path ->
    ~ null_pointer_exceptions_suffix s) ->
  move_along_path_from path S p = Some p' ->
  p' <> NULL.
Proof.
  introv OKp NE E. gen p. induction path; introv OKp E.
  - rewrite move_along_path_from_nil in E. inverts E. applys~ safe_pointer_not_NULL OKp.
  - forwards (p2&E1&E2): move_along_path_from_cons_inv (rm E).
    rewrite safe_pointer_rewrite in OKp. forwards~ D: no_null_pointer_along_path_step OKp E1.
    + introv NE'. false NE NE'. Mem_solve.
    + applys~ IHpath E2.
      * introv I. applys NE. right~.
      * applys~ safe_pointer_along_path_step OKp E1 D.
Qed.

Lemma safe_SExpRec_along_path_from : forall S p path e e_,
  safe_pointer S p ->
  move_along_path_from path S p = Some e ->
  read_SExp S e = Some e_ ->
  safe_SExpRec S e_.
Proof.
  introv OKp E R. forwards~ OKe: safe_pointer_along_path_from E.
  - introv ?. substs. rewrite read_SExp_NULL in R. inverts R.
  - rewrite safe_pointer_rewrite in OKe. applys~ safe_SExpRec_read OKe.
Qed.

Lemma safe_pointer_along_path : forall S path e,
  safe_state S ->
  move_along_path path S = Some e ->
  e <> NULL ->
  safe_pointer S e.
Proof.
  introv OKS E D. gen e. induction path; introv E D.
  - applys~ safe_entry_points E.
  - simpl in E. destruct move_along_path eqn:E'.
    + simpl in E. forwards~ OKs: IHpath.
      * introv ?. substs. rewrite move_along_path_step_NULL in E. inverts E.
      * rewrite safe_pointer_rewrite in OKs. applys~ safe_pointer_along_path_step OKs E.
    + inverts E.
Qed.

Lemma no_null_pointer_along_path : forall S path e,
  safe_state S ->
  move_along_path path S = Some e ->
  ~ null_pointer_exceptions_path path ->
  e <> NULL.
Proof.
  introv OKS E NE D. destruct path.
  - applys~ no_null_pointer_entry_point E.
    introv NE'. apply NE. applys~ null_pointer_exceptions_path_entry_point NE'.
  - simpl in E. destruct move_along_path eqn: E'.
    + forwards~ OKe: safe_pointer_along_path E'.
      * introv ?. substs. simpl in E. rewrite move_along_path_step_NULL in E. inverts~ E.
      * rewrite safe_pointer_rewrite in OKe. applys~ no_null_pointer_along_path_step OKe p.
        -- introv NE'. apply NE. applys~ null_pointer_exceptions_path_suffix NE'.
           unfolds. applys_eq suffix_cons 1; [apply suffix_nil|reflexivity].
        -- substs. apply E.
    + inverts E.
Qed.

Lemma safe_bindings_along_path : forall S path e,
  safe_state S ->
  move_along_path path S = Some e ->
  e <> NULL ->
  bound S e.
Proof.
  introv OKS E D. forwards~ OKe: safe_pointer_along_path E D.
  rewrite safe_pointer_rewrite in OKe. applys pointer_bound OKe.
Qed.

Lemma safe_SExpRec_along_path : forall S path e e_,
  safe_state S ->
  move_along_path path S = Some e ->
  read_SExp S e = Some e_ ->
  safe_SExpRec S e_.
Proof.
  introv OKS E R. forwards~ OKe: safe_pointer_along_path OKS E.
  - introv ?. substs. rewrite read_SExp_NULL in R. inverts R.
  - rewrite safe_pointer_rewrite in OKe. applys~ safe_SExpRec_read OKe.
Qed.

Lemma alloc_SExp_conserve_old_binding : forall S S' e e_,
  alloc_SExp S e_ = (S', e) ->
  conserve_old_binding S S'.
Proof.
  introv A. constructors.
  - (** conserve_old_binding_binding **)
    introv (p_&E&_). exists p_. splits~. exists p_. splits~.
    eapply alloc_read_SExp_neq in A.
    + rewrite~ A.
    + introv D. substs. erewrite alloc_read_SExp_fresh in E; autos*. inverts* E.
  - (** conserve_old_binding_entry_point **)
    introv. rewrites* >> move_along_entry_point_alloc_SExp A.
Qed.

Lemma read_bound : forall (S : state) p p_,
  read_SExp S p = Some p_ ->
  bound S p.
Proof. introv E. exists* p_. Qed.

Lemma bound_read : forall (S : state) p,
  bound S p ->
  exists p_, read_SExp S p = Some p_.
Proof. introv (p_&E&_). exists* p_. Qed.

Lemma only_one_nil_SExprRec : forall S p1 p2 e1 e2 e1_ e2_,
  safe_state S ->
  move_along_path p1 S = Some e1 ->
  move_along_path p2 S = Some e2 ->
  read_SExp S e1 = Some e1_ ->
  read_SExp S e2 = Some e2_ ->
  type e1_ = NilSxp ->
  type e2_ = NilSxp ->
  e1 = e2.
Proof.
  introv Safe M1 M2 R1 R2 T1 T2.
  applys~ only_one_nil Safe; eexists; splits*; apply~ BagInSingle_list.
Qed.

Lemma may_have_types_NilSxp_safe_pointer : forall S globals p,
  safe_state S ->
  safe_globals S globals ->
  may_have_types S ([NilSxp]) p ->
  safe_pointer S p.
Proof.
  introv OKS OKg M. asserts_rewrite (p = read_globals globals R_NilValue).
  - applys~ only_one_nil M. applys~ R_NilValue_may_have_types OKg.
  - applys~ globals_not_NULL_safe OKg. applys~ globals_not_NULL OKg. introv A. inverts A.
Qed.

Lemma conserve_old_binding_read : forall S S' p p_,
  conserve_old_binding S S' ->
  read_SExp S p = Some p_ ->
  read_SExp S' p = Some p_.
Proof.
  introv C E. forwards (p1_&E1&(p2_&E2&E3)): conserve_old_binding_binding C p.
  - apply* read_bound.
  - rewrite E in E1. inverts E1. substs~.
Qed.

Lemma conserve_old_binding_bound : forall S S' p,
  conserve_old_binding S S' ->
  bound S p ->
  bound S' p.
Proof.
  introv C (p_&E&_). forwards (p1_&E1&(p2_&E2&E3)): conserve_old_binding_binding C p.
  - apply* read_bound.
  - rewrite E in E1. inverts E1. substs. exists~ p2_.
Qed.

Lemma conserve_old_binding_may_have_types : forall S S' l p,
  conserve_old_binding S S' ->
  may_have_types S l p ->
  may_have_types S' l p.
Proof.
  introv C (p_&E&T). forwards (p1_&E1&(p2_&E2&E3)): conserve_old_binding_binding C p.
  - apply* read_bound.
  - rewrite E in E1. inverts E1. substs. exists~ p2_.
Qed.

Lemma conserve_old_binding_list_type : forall Pheader Pcar Ptag S S' l_t l_car l_tag p,
  conserve_old_binding S S' ->
  list_type_such_that Pheader Pcar Ptag S l_t l_car l_tag p ->
  list_type_such_that Pheader Pcar Ptag S' l_t l_car l_tag p.
Proof.
  introv C L. induction L as [? ? ? ? I|? ? ? ? p_ h car cdr tag E M H HH A L T IH]
    using list_type_ind.
  - apply list_type_nil. applys~ conserve_old_binding_may_have_types C.
  - apply list_type_cons. exists p_. splits~.
    + applys~ conserve_old_binding_read C.
    + exists h car cdr tag. splits~; applys~ conserve_old_binding_may_have_types C.
Qed.

Lemma conserve_old_binding_list_head : forall Pheader Pcar Ptag S S' l_t l_car l_tag p_,
  conserve_old_binding S S' ->
  list_head_such_that Pheader Pcar Ptag S l_t l_car l_tag p_ ->
  list_head_such_that Pheader Pcar Ptag S' l_t l_car l_tag p_.
Proof.
  introv C (h&car&cdr&tag&L). exists h car cdr tag. splits; try apply~ L.
  - applys* conserve_old_binding_may_have_types C.
  - applys* conserve_old_binding_list_type C.
  - applys* conserve_old_binding_may_have_types C.
Qed.

Lemma conserve_old_binding_transitive : forall S1 S2 S3,
  conserve_old_binding S1 S2 ->
  conserve_old_binding S2 S3 ->
  conserve_old_binding S1 S3.
Proof.
  introv C1 C2. constructors.
  - (** conserve_old_binding_binding **)
    introv (p_&E&_). exists p_. splits~.
    forwards~ E1: conserve_old_binding_read C1 (rm E).
    forwards~ E2: conserve_old_binding_read C2 (rm E1).
    exists p_. splits~.
  - (** conserve_old_binding_entry_point **)
    introv. rewrites >> conserve_old_binding_entry_point C1.
    rewrites~ >> conserve_old_binding_entry_point C2.
Qed.

Lemma conserve_old_binding_move_along_path_step : forall S S' p e e',
  conserve_old_binding S S' ->
  move_along_path_step p S e = Some e' ->
  move_along_path_step p S' e = Some e'.
Proof.
  introv C E. unfolds in E. destruct (read_SExp S e) eqn: R.
  - unfolds. rewrites~ >> conserve_old_binding_read C R.
  - inverts~ E.
Qed.

Lemma conserve_old_binding_move_along_path_from : forall S S' p e e',
  conserve_old_binding S S' ->
  move_along_path_from p S e = Some e' ->
  move_along_path_from p S' e = Some e'.
Proof.
  introv C M. unfolds move_along_path_from.
  rewrite fold_left_eq_fold_right in *.
  gen e e'. induction (rev p); introv M.
  - inverts~ M.
  - rew_list in *. destruct fold_right eqn: F.
    + simpl in M. forwards M': conserve_old_binding_move_along_path_step C M.
      erewrite IHl; [apply M'|]. rewrite~ F.
    + inverts~ M.
Qed.

Lemma conserve_old_binding_move_along_path_step_inv : forall S S' s e e',
  conserve_old_binding S S' ->
  bound S e ->
  move_along_path_step s S' e = Some e' ->
  move_along_path_step s S e = Some e'.
Proof.
  introv C B E. forwards (e_&R): bound_read B.
  unfolds move_along_path_step. rewrite R.
  rewrites >> conserve_old_binding_read C R in E. apply~ E.
Qed.

Lemma conserve_old_binding_move_along_path_from_inv_incl : forall (safe_pointer' : _ -> _ -> Prop) S S' p e e',
  (forall S p, safe_pointer' S p -> safe_pointer_gen safe_pointer' S p) ->
  conserve_old_binding S S' ->
  safe_pointer' S e ->
  move_along_path_from p S' e = Some e' ->
  move_along_path_from p S e = Some e'.
Proof.
  introv Incl C OKe E. gen e e'. induction p using list_ind_last; introv OKe E.
  - rewrite move_along_path_from_nil in *. apply~ E.
  - forwards~ (e2&E1&E2): move_along_path_from_last_inv E.
    forwards~ E': IHp E1. applys~ move_along_path_from_last E'.
    applys~ conserve_old_binding_move_along_path_step_inv E2.
    forwards~ OKe2: safe_pointer_along_path_from_incl OKe E'.
    + introv ?. substs. rewrite move_along_path_step_NULL in E2. inverts E2.
    + apply Incl in OKe2. applys~ pointer_bound OKe2.
Qed.

Lemma conserve_old_binding_move_along_path_from_inv : forall S S' p e e',
  conserve_old_binding S S' ->
  safe_pointer S e ->
  move_along_path_from p S' e = Some e' ->
  move_along_path_from p S e = Some e'.
Proof.
  introv. applys~ conserve_old_binding_move_along_path_from_inv_incl.
  clear. introv OKp. rewrite~ <- safe_pointer_rewrite.
Qed.

Lemma conserve_old_binding_move_along_entry_point_inv : forall S S' e p,
  conserve_old_binding S S' ->
  move_along_entry_point e S' = Some p ->
  move_along_entry_point e S = Some p.
Proof. introv C E. rewrites~ >> conserve_old_binding_entry_point C. Qed.

Lemma conserve_old_binding_move_along_path_inv : forall S S' p e,
  safe_state S ->
  conserve_old_binding S S' ->
  move_along_path p S' = Some e ->
  move_along_path p S = Some e.
Proof.
  introv OKS C E. gen e. induction p as [?|p IH s]; introv E.
  - simpls. applys~ conserve_old_binding_move_along_entry_point_inv E.
  - simpls. destruct (move_along_path p S') eqn: E1.
    + rewrites~ >> IH. simpls.
      applys~ conserve_old_binding_move_along_path_step_inv E.
      applys~ safe_bindings_along_path.
      introv ?. substs. rewrite move_along_path_step_NULL in E. inverts E.
    + inverts E.
Qed.

Lemma conserve_old_binding_list_type_safe_aux : forall (safe_pointer1 safe_pointer2 : _ -> _ -> Prop)
    S S' l_t l_car l_tag p,
  conserve_old_binding S S' ->
  (forall p, safe_pointer1 S p -> safe_pointer2 S' p) ->
  list_type_such_that (safe_header safe_pointer1 S) (safe_pointer1 S) (safe_pointer1 S) S l_t l_car l_tag p ->
  list_type_such_that (safe_header safe_pointer2 S') (safe_pointer2 S') (safe_pointer2 S') S' l_t l_car l_tag p.
Proof.
  introv C CSafe L. induction L as [? ? ? ? I|? ? ? ? p_ h car cdr tag E M H HH A L T IH]
    using list_type_ind.
  - apply list_type_nil. applys~ conserve_old_binding_may_have_types C.
  - apply list_type_cons. exists p_. splits~.
    + applys~ conserve_old_binding_read C.
    + exists h car cdr tag. splits~; try applys~ conserve_old_binding_may_have_types C.
      inverts HH. constructors*.
Qed.

Lemma conserve_old_binding_list_head_safe_aux : forall (safe_pointer1 safe_pointer2 : _ -> _ -> Prop)
    S S' l_t l_car l_tag p_,
  conserve_old_binding S S' ->
  (forall p, safe_pointer1 S p -> safe_pointer2 S' p) ->
  list_head_such_that (safe_header safe_pointer1 S) (safe_pointer1 S) (safe_pointer1 S) S l_t l_car l_tag p_ ->
  list_head_such_that (safe_header safe_pointer2 S') (safe_pointer2 S') (safe_pointer2 S') S' l_t l_car l_tag p_.
Proof.
  introv C CSafe (h&car&cdr&tag&E&T&HH&Mcar&OKcar&L&Mtag&OKtag).
  exists h car cdr tag. splits~.
  - inverts HH. constructors*.
  - applys* conserve_old_binding_may_have_types C.
  - applys* conserve_old_binding_list_type_safe_aux C.
  - applys* conserve_old_binding_may_have_types C.
Qed.

Lemma conserve_old_binding_safe_SExprRec_type_aux : forall (safe_pointer1 safe_pointer2 : _ -> _ -> Prop) S S' t p_,
  conserve_old_binding S S' ->
  (forall p, safe_pointer1 S p -> safe_pointer2 S' p) ->
  safe_SExpRec_type (safe_header safe_pointer1) safe_pointer1 S t p_ ->
  safe_SExpRec_type (safe_header safe_pointer2) safe_pointer2 S' t p_.
Proof.
  introv C CSafe OK. inverts OK; constructors~;
    try (introv M; match goal with P : _ |- _ =>
                     let P' := fresh P in forwards P': P M;
                     repeat (let P'' := fresh P in
                       lets (?&P''): (rm P'); rename P'' into P')
                   end; try splits);
    try applys_first (>> conserve_old_binding_may_have_types
                         conserve_old_binding_list_type_safe_aux
                         conserve_old_binding_list_head_safe_aux) C; autos*.
Qed.

Lemma conserve_old_binding_safe_SExpRec_aux : forall (safe_pointer1 safe_pointer2 : _ -> _ -> Prop) S S' p_,
  conserve_old_binding S S' ->
  (forall p, safe_pointer1 S p -> safe_pointer2 S' p) ->
  safe_SExpRec_gen safe_pointer1 S p_ ->
  safe_SExpRec_gen safe_pointer2 S' p_.
Proof.
  introv C Csafe E. constructors~.
  applys* conserve_old_binding_safe_SExprRec_type_aux C.
  applys~ SExpType_corresponds_to_datatype E.
Qed.

Lemma conserve_old_binding_safe_pointer : forall S S' p,
  conserve_old_binding S S' ->
  safe_pointer S p ->
  safe_pointer S' p.
Proof.
  pcofix IH. introv C OKS. pfold. rewrite safe_pointer_rewrite in OKS. constructors~.
  - (** pointer_bound **)
    applys conserve_old_binding_bound C. applys~ pointer_bound OKS.
  - (** no_null_pointer_along_path_step **)
    introv NPE E. applys~ no_null_pointer_along_path_step OKS NPE.
    applys~ conserve_old_binding_move_along_path_step_inv C OKS.
  - (** safe_pointer_along_path_step **)
    introv E D. right. applys IH C. forwards E': conserve_old_binding_move_along_path_step_inv C E.
    + applys~ pointer_bound OKS.
    + applys~ safe_pointer_along_path_step E'.
  - (** safe_SExpRec_read **)
    introv R. destruct (read_SExp S p) as [p'_|] eqn: E.
    + forwards E': conserve_old_binding_read C E.
      rewrite E' in R. inverts~ R.
      applys~ conserve_old_binding_safe_SExpRec_aux safe_pointer C.
      * clear - C IH. introv OKp. right*.
      * applys~ safe_SExpRec_read E.
    + false. forwards~ (?&E'): bound_read (pointer_bound OKS). rewrite E' in E. inverts E.
Qed.

Lemma conserve_old_binding_list_type_safe : forall S S' l_t l_car l_tag p,
  conserve_old_binding S S' ->
  list_type_safe S l_t l_car l_tag p ->
  list_type_safe S' l_t l_car l_tag p.
Proof.
  introv C L. applys~ conserve_old_binding_list_type_safe_aux C L.
  introv. applys~ conserve_old_binding_safe_pointer.
Qed.

Lemma conserve_old_binding_list_head_safe : forall S S' l_t l_car l_tag p_,
  conserve_old_binding S S' ->
  list_head_safe S l_t l_car l_tag p_ ->
  list_head_safe S' l_t l_car l_tag p_.
Proof.
  introv C L. applys~ conserve_old_binding_list_head_safe_aux C L.
  introv. applys~ conserve_old_binding_safe_pointer.
Qed.

Lemma conserve_old_binding_safe_SExprRec_type : forall S S' t p_,
  conserve_old_binding S S' ->
  safe_SExpRec_type (safe_header safe_pointer) safe_pointer S t p_ ->
  safe_SExpRec_type (safe_header safe_pointer) safe_pointer S' t p_.
Proof.
  introv C OK. applys~ conserve_old_binding_safe_SExprRec_type_aux C OK.
  introv. applys~ conserve_old_binding_safe_pointer.
Qed.

Lemma conserve_old_binding_safe_SExpRec : forall S S' p_,
  conserve_old_binding S S' ->
  safe_SExpRec S p_ ->
  safe_SExpRec S' p_.
Proof.
  introv C OK. applys~ conserve_old_binding_safe_SExpRec_aux C OK.
  introv. applys~ conserve_old_binding_safe_pointer.
Qed.

Lemma alloc_SExp_safe_state : forall S S' p p_,
  safe_state S ->
  safe_SExpRec S p_ ->
  alloc_SExp S p_ = (S', p) ->
  type p_ <> NilSxp ->
  safe_state S'.
Proof.
  introv OKS OKp A D. forwards C: alloc_SExp_conserve_old_binding A. constructors~.
  - (** no_null_pointer_entry_point **)
    introv NE E1. forwards~ E2: conserve_old_binding_move_along_entry_point_inv C E1.
    applys~ no_null_pointer_entry_point E2.
  - (** safe_entry_points **)
    introv E1 D'. applys~ conserve_old_binding_safe_pointer C.
    forwards~ E2: conserve_old_binding_move_along_entry_point_inv C E1.
    applys~ safe_entry_points E2.
  - (** only_one_nil **)
    introv (p1_&E1&T1) (p2_&E2&T2). rewrites >> alloc_read_SExp_neq A in E1.
    + introv ?. substs. rewrites >> alloc_read_SExp_eq A in E1. inverts E1.
      false D. apply~ BagInSingle_list.
    + rewrites >> alloc_read_SExp_neq A in E2.
      * introv ?. substs. rewrites >> alloc_read_SExp_eq A in E2. inverts E2.
        false D. apply~ BagInSingle_list.
      * applys~ only_one_nil OKS; eexists; autos*.
Qed.

Lemma safe_pointer_may_have_types_all_storable_SExpTypes : forall S p,
  safe_pointer S p ->
  may_have_types S all_storable_SExpTypes p.
Proof.
  introv OKp. rewrite safe_pointer_rewrite in OKp. forwards (p_&R&_): pointer_bound OKp. exists p_. splits~.
  forwards~ OKp_: safe_SExpRec_read OKp R.
  apply SExpType_corresponds_to_datatype in OKp_. inverts OKp_; Mem_solve.
Qed.

Lemma safe_make_SExpRec_list : forall S attrib car cdr tag,
  safe_pointer S attrib ->
  safe_pointer S car ->
  list_type_safe S ([ListSxp]) all_storable_SExpTypes ([NilSxp; CharSxp]) cdr ->
  may_have_types S ([NilSxp; CharSxp]) tag ->
  safe_pointer S tag ->
  safe_SExpRec S (make_SExpRec_list attrib car cdr tag).
Proof.
  introv OKattrib OKcar OKcdr Ttag OKtag. constructors.
  simpl. constructors. do 4 eexists. splits*.
  - simpl. Mem_solve.
  - constructors~.
  - applys~ safe_pointer_may_have_types_all_storable_SExpTypes OKcar.
Qed.

Lemma list_type_safe_ListSxp : forall globals S l_car l_tag l,
  safe_state S ->
  safe_globals S globals ->
  l_car \c all_storable_SExpTypes ->
  l_tag \c [NilSxp; CharSxp] ->
  list_type_safe S ([ListSxp]) l_car l_tag l ->
  safe_pointer S l.
Proof.
  introv OKS OKg Icar Itag L. remember [ListSxp] as l_t.
  induction L as [? ? ? ? L|? ? ? ? p_ h car cdr tag E M H HH A HA L T HT IH] using list_type_ind.
  - applys~ may_have_types_NilSxp_safe_pointer OKg L.
  - rewrite safe_pointer_rewrite. constructors.
    + (** pointer_bound **)
      applys~ read_bound E.
    + (** no_null_pointer_along_path_step **)
      introv N Em. unfolds in Em. rewrite E in Em. rewrite M in Em. simpl in Em.
      destruct s as [|?|[| |]|?|?|?|?]; inverts~ Em; applys* safe_pointer_not_NULL.
      applys~ safe_attrib HH.
    + (** safe_pointer_along_path_step **)
      introv Em D. unfolds in Em. rewrite E in Em. rewrite M in Em. simpl in Em.
      destruct s as [|?|[| |]|?|?|?|?]; inverts~ Em.
      applys~ safe_attrib HH.
    + (** safe_SExpRec_read **)
      rewrite E. introv I. symmetry in I. inverts I.
      subst l_t. eapply BagInSingle_list in H. constructors~.
      rewrite H. constructors~.
      do 4 eexists. splits*.
      * rewrite H. Mem_solve.
      * applys~ may_have_types_weaken A.
      * applys~ list_type_weaken L. solve_incl.
      * applys~ may_have_types_weaken T.
Qed.

Lemma conserve_old_binding_safe_globals : forall S S' globals,
  conserve_old_binding S S' ->
  safe_globals S globals ->
  safe_globals S' globals.
Proof.
  introv C OKglobals. constructors.
  - (** globals_not_NULL **)
    applys~ globals_not_NULL OKglobals.
  - (** globals_not_NULL_safe **)
    introv D. applys~ conserve_old_binding_safe_pointer C. applys~ globals_not_NULL_safe D.
  - (** R_NilValue_may_have_types **)
    applys~ conserve_old_binding_may_have_types C. applys~ R_NilValue_may_have_types.
Qed.


(** * General tactics **)

(** ** Simplifying tactics **)

(** *** Simplifying lists **)

Ltac is_fully_computed l :=
  lazymatch l with
  | nil => constr:(true)
  | _ :: ?l =>
    let r := is_fully_computed l in r
  | _ => constr:(false)
  end.

(** Checks whether [x] is syntactically in the list [l]. **)
Ltac compute_is_in x l :=
  lazymatch l with
  | nil => constr:(false)
  | x :: _ => constr:(true)
  | _ :: ?l =>
    let r := compute_is_in x l in r
  end.

(** This produces a list equal to [l1 \n l2] in Ltac. **)
Ltac compute_list_inter l1 l2 :=
  lazymatch l2 with
  | nil => l2
  | ?a :: ?l =>
    let isi := compute_is_in a l1 in
    let r := compute_list_inter l1 l in
    match isi with
    | true => constr:(a :: r)
    | false => r
    end
  end.

(** The following tactic computes any occurence of [l1 \n l2] in the goal. **)
Ltac simpl_list_inter :=
  let solve_eq :=
    clear; simpl;
    repeat
      (rewrite filter_cons;
       let C := fresh "C" in
       cases_if as C; fold_bool; rew_refl in C; tryfalse~;
       fequals; clear C) in
  repeat match goal with
  | |- context [ ?l1 \n ?l2 ] =>
    let l := compute_list_inter l1 l2 in
    asserts_rewrite (l1 \n l2 = l); [solve_eq|]
  | H : context [ ?l1 \n ?l2 ] |- _ =>
    let l := compute_list_inter l1 l2 in
    asserts_rewrite (l1 \n l2 = l) in H; [solve_eq|]
  end.

(** This produces a list equal to [l1 \u l2] in Ltac. **)
Ltac compute_list_union l1 l2 :=
  let rec inl2butnotinl1 l2 :=
    match l2 with
    | nil => l2
    | ?a :: ?l =>
      let isi := compute_is_in a l1 in
      let r := inl2butnotinl1 l in
      match isi with
      | true => r
      | false => constr:(a :: r)
      end
    end in
  let rec add_to_the_end l1 :=
    lazymatch l1 with
    | nil =>
      let r := inl2butnotinl1 l2 in
      r
    | ?a :: ?l =>
      let r := add_to_the_end l in
      constr:(a :: r)
    end in
  add_to_the_end l1.

(** The following tactic computes any occurence of [l1 \u l2] in the goal. **)
Ltac simpl_list_union :=
  let solve_eq :=
    clear; simpl;
    repeat rewrite app_cons; rewrite app_nil_l;
    repeat
      (rewrite filter_cons;
       let C := fresh "C" in
       cases_if as C; fold_bool; rew_refl in C; try (false C; substs; Mem_solve);
       fequals; clear C) in
  repeat match goal with
  | |- context [ ?l1 \u ?l2 ] =>
    let l := compute_list_union l1 l2 in
    asserts_rewrite (l1 \u l2 = l); [solve_eq|]
  | H : context [ ?l1 \u ?l2 ] |- _ =>
    let l := compute_list_union l1 l2 in
    asserts_rewrite (l1 \u l2 = l) in H; [solve_eq|]
  end.


(** *** Simplifying the context **)

Ltac syntactically_the_same x y :=
  lazymatch x with
  | y => idtac
  end.

Ltac syntactically_different x y :=
  lazymatch x with
  | y => fail
  | _ => idtac
  end.

Ltac simplify_context_base :=
  repeat match goal with
  | T : may_have_types ?S nil ?p |- _ =>
    false; applys~ may_have_types_nil T
  | T1 : may_have_types ?S ?l1 ?p,
    T2 : may_have_types ?S ?l2 ?p |- _ =>
    let T3 := fresh2 T1 T2 in
    forwards T3: may_have_types_merge (rm T1) (rm T2);
    rename T3 into T1
  | T1 : list_type ?S ?l1_t ?l1_car ?l1_tag ?p,
    T2 : list_type ?S ?l2_t ?l2_car ?l2_tag ?p |- _ =>
    let T3 := fresh2 T1 T2 in
    forwards T3: list_type_merge (rm T1) (rm T2);
    rename T3 into T1
  end;
  try fold (list_head_such_that (fun _ => True) (fun _ => True)) in *;
  try fold list_head_such_that in *;
  try fold list_head in *;
  try fold list_type in *;
  repeat match goal with
  | |- context [ list_type_such_that (safe_header safe_pointer ?S) (safe_pointer ?S) (safe_pointer ?S) ?S ] =>
    fold (list_type_safe S)
  | H : context [ list_type_such_that (safe_header safe_pointer ?S) (safe_pointer ?S) (safe_pointer ?S) ?S ] |- _ =>
    fold (list_type_safe S) in H
  | |- context [ list_head_such_that (safe_header safe_pointer ?S) (safe_pointer ?S) (safe_pointer ?S) ?S ] =>
    fold (list_head_safe S)
  | H : context [ list_head_such_that (safe_header safe_pointer ?S) (safe_pointer ?S) (safe_pointer ?S) ?S ] |- _ =>
    fold (list_head_safe S) in H
  end;
  simpl_list_inter;
  simpl_list_union.


(** *** Automatic rewriting **)

(** As this file defines a lot of tactics defining new names, it is
  best to avoid explicitely having to use these new hypotheses by
  their names.  The following tactic tries to automatically rewrites
  what it can. **)

Ltac self_rewrite :=
  repeat match goal with
  | H : _ = _ |- _ => rewrite~ H
  end.

Ltac self_rewrite_in P :=
  repeat match goal with
  | H : _ = _ |- _ =>
    syntactically_different H P;
    rewrite~ H in P
  end.

Ltac self_rewrite_about x :=
  repeat match goal with
  | H : context [ x ] |- _ => rewrite~ H
  end.

Ltac self_rewrite_about_in x P :=
  repeat match goal with
  | H : context [ x ] |- _ =>
    syntactically_different H P;
    rewrite~ H in P
  end.


(** *** Case analysis on lists **)

Ltac explode_list T :=
  lazymatch type of T with
  | ?x \in nil =>
    false; applys~ BagInEmpty_list T
  | ?x \in [?y] =>
    let T' := fresh1 T in
    asserts T': (x = y); [eapply BagInSingle_list; apply T|];
    clear T; rename T' into T
  | ?x \in (?y :: ?l) =>
    apply BagIn_cons in T;
    let T' := fresh1 T in
    lets [T'|T']: (rm T); rename T' into T;
    [|explode_list T]
  | may_have_types ?S nil ?x =>
    false; applys~ may_have_types_nil T
  | may_have_types ?S (?t :: ?l) ?x =>
    apply may_have_types_cons in T;
    let T' := fresh1 T in
    lets [T'|T']: (rm T); rename T' into T;
    [|explode_list T]
  | Mem ?x nil =>
    rewrite Mem_nil_eq in T; false~ T
  | Mem ?x (?y :: ?l) =>
    rewrite Mem_cons_eq in T;
    let T' := fresh1 T in
    lets [T'|T']: (rm T); rename T' into T;
    [|explode_list T]
  | mem ?x nil =>
    rewrite mem_nil in T; false~ T
  | mem ?x (?y :: ?l) =>
    rewrite mem_cons in T;
    rew_refl in T;
    let T' := fresh1 T in
    lets [T'|T']: (rm T); rename T' into T;
    [|explode_list T]
  end.


(** *** Clearing trivial hypotheses **)

Ltac clear_trivial :=
  repeat match goal with
  | T : True |- _ => clear T
  | E : ?x = ?x |- _ => clear E
  | H1 : ?P, H2 : ?P |- _ => clear H2
  | I : ?x \in [?y] |- _ => explode_list I
  end.


(** ** Some tactics about locations **)

(** *** Proving that locations are not [NULL] **)

Lemma noteq_sym : forall A (x y : A), x <> y -> y <> x.
Proof. autos*. Qed.

Ltac prove_not_NULL :=
  let aux p :=
    first [
        apply* no_null_pointer_along_path_step;
        let A := fresh "A" in introv A; inverts~ A
      | apply* no_null_pointer_along_path;
        let A := fresh "A" in introv A; inverts~ A
      | apply* globals_not_NULL;
        let A := fresh "A" in introv A; inverts~ A
      | apply* no_null_pointer_entry_point;
        let A := fresh "A" in introv A; inverts~ A
      | apply* no_null_pointer_along_path_from;
        let I := fresh "I" in let A := fresh "A" in introv I A; inverts A; inverts~ I
      | let E := fresh "E" in introv E; substs;
        match goal with
        | E : move_along_path_step _ _ NULL = Some _ |- _ =>
          rewrite move_along_path_step_NULL in E; inverts~ E
        | E : move_along_path_from _ _ NULL = Some _ |- _ =>
          rewrite move_along_path_from_NULL in E; [discriminate|inverts~ E]
        | E : read_SExp _ NULL = Some _ |- _ =>
          rewrite read_SExp_NULL in E; inverts~ E
        end ] in
  lazymatch goal with
  | |- ?p <> NULL => aux p
  | |- ?p = NULL -> False => aux p
  | |- NULL <> ?p => apply noteq_sym; aux p
  | |- NULL = ?p -> False => apply noteq_sym; aux p
  end.


(** *** Proving locations different **)

(** Generates a proof of [Nth n p l] if possible. **)
Ltac prove_Nth p l :=
  lazymatch l with
  | p :: ?l' => constr:(Nth_here l' p)
  | ?x :: ?l' =>
    let N := prove_Nth p l' in
    constr:(Nth_next x N)
  end.

Ltac get_may_have_types S p cont :=
  lazymatch goal with
  | M : may_have_types S _ p |- _ => cont M
  | L : list_type S _ _ _ p |- _ =>
    let E := fresh L in
    let p' := fresh1 p in
    let p_ := fresh p' "_" in
    forwards (p_&E&_): list_type_may_have_types L;
    simpl_list_union;
    cont E
  | E : read_SExp (state_memory S) p = Some ?p_,
    T : type (get_SxpInfo ?p_) = ?t |- _ =>
    let M := fresh "M" in
    forwards M: read_SExp_may_have_types_read_exact E T;
    cont M
  | E : read_SExp (state_memory S) p = Some ?p_,
    T : type (get_SxpInfo ?p_) \in ?l |- _ =>
    let M := fresh "M" in
    forwards M: read_SExp_may_have_types_read E T;
    cont M
  | E : read_SExp (state_memory S) p = Some ?p_,
    L : list_head S ?l_car ?l_cdr ?l_tag ?p_ |- _ =>
    let T := fresh "T" in
    forwards T: list_head_may_have_types L;
    let M := fresh "M" in
    forwards M: read_SExp_may_have_types_read E T;
    cont M
  | E : read_SExp (state_memory S) p = Some ?p_,
    L : list_head_such_that ?Pcar ?Ptag S ?l_car ?l_cdr ?l_tag ?p_ |- _ =>
    let T := fresh "T" in
    forwards T: list_head_may_have_types L;
    let M := fresh "M" in
    forwards M: read_SExp_may_have_types_read E T;
    cont M
  | |- _ =>
    lazymatch p with
    | read_globals ?globals R_NilValue =>
      lazymatch goal with
      | G : safe_globals S globals |- _ =>
        let T := fresh "T" in
        forwards T: R_NilValue_may_have_types G; [idtac];
        cont T
      end
    end
  end.

Ltac get_may_have_types_no_S p cont :=
  lazymatch goal with
  | M : may_have_types _ _ p |- _ => cont M
  | L : list_type _ _ _ _ p |- _ =>
    let E := fresh L in
    let p' := fresh1 p in
    let p_ := fresh p' "_" in
    forwards (p_&E&_): list_type_may_have_types L;
    simpl_list_union;
    cont E
  | E : read_SExp _ p = Some ?p_,
    T : type (get_SxpInfo ?p_) = ?t |- _ =>
    let M := fresh "M" in
    forwards M: read_SExp_may_have_types_read_exact E T;
    cont M
  | E : read_SExp _ p = Some ?p_,
    T : type (get_SxpInfo ?p_) \in ?l |- _ =>
    let M := fresh "M" in
    forwards M: read_SExp_may_have_types_read E T;
    cont M
  | E : read_SExp (state_memory ?S) p = Some ?p_,
    L : list_head ?S ?l_car ?l_cdr ?l_tag ?p_ |- _ =>
    let T := fresh "T" in
    forwards T: list_head_may_have_types L;
    let M := fresh "M" in
    forwards M: read_SExp_may_have_types_read E T;
    cont M
  | E : read_SExp (state_memory ?S) p = Some ?p_,
    L : list_head_such_that ?Pcar ?Ptag ?S ?l_car ?l_cdr ?l_tag ?p_ |- _ =>
    let T := fresh "T" in
    forwards T: list_head_may_have_types L;
    let M := fresh "M" in
    forwards M: read_SExp_may_have_types_read E T;
    cont M
  | |- _ =>
    lazymatch p with
    | read_globals ?globals R_NilValue =>
      let T := fresh "T" in
      forwards~ T: R_NilValue_may_have_types; [idtac];
      cont T
    end
  end.

Ltac prove_locations_different :=
  let aux p1 p2 :=
    match goal with
    | _ => prove_not_NULL
    | D : No_duplicates ?l |- _ =>
      abstract (
        let N1 := prove_Nth p1 l in
        let N2 := prove_Nth p2 l in
        let E := fresh "E" in
        forwards E: No_duplicates_Nth D N1 N2;
        false~ E )
    | A : alloc_SExp ?S _ = (?S', p1),
      R : read_SExp (state_memory ?S) p2 = Some _ |- _ =>
      applys~ alloc_read_SExp_diff A R
    | A : alloc_SExp ?S _ = (?S', p2),
      R : read_SExp (state_memory ?S) p1 = Some _ |- _ =>
      apply~ noteq_sym;
      applys~ alloc_read_SExp_diff A R
    | A : alloc_SExp ?S _ = (?S', p1),
      B : bound ?S p2 |- _ =>
      let E := fresh B in
      let p2' := fresh1 p2 in
      let p2_ := fresh p2' "_" in
      lets (p2_&E): bound_read B;
      applys~ alloc_read_SExp_diff A (rm E)
    | A : alloc_SExp ?S _ = (?S', p2),
      B : bound ?S p1 |- _ =>
      let E := fresh B in
      let p2' := fresh1 p2 in
      let p2_ := fresh p2' "_" in
      lets (p2_&E): bound_read B;
      apply~ noteq_sym;
      applys~ alloc_read_SExp_diff A (rm E)
    | A : alloc_SExp ?S _ = (?S', p1),
      B : bound_such_that ?S _ p2 |- _ =>
      let E := fresh B in
      let p2' := fresh1 p2 in
      let p2_ := fresh p2' "_" in
      lets (p2_&E&_): B;
      applys~ alloc_read_SExp_diff A (rm E)
    | A : alloc_SExp ?S _ = (?S', p2),
      B : bound_such_that ?S _ p1 |- _ =>
      let E := fresh B in
      let p2' := fresh1 p2 in
      let p2_ := fresh p2' "_" in
      lets (p2_&E&_): B;
      apply~ noteq_sym;
      applys~ alloc_read_SExp_diff A (rm E)
    | A : alloc_SExp ?S _ = (?S', p1) |- _ =>
      get_may_have_types_no_S p2 ltac:(fun M =>
        let E := fresh1 M in
        let p2' := fresh1 p2 in
        let p2_ := fresh p2' "_" in
        lets (p2_&E&_): M;
        applys~ alloc_read_SExp_diff A (rm E))
    | A : alloc_SExp ?S _ = (?S', p2) |- _ =>
      get_may_have_types_no_S p2 ltac:(fun M =>
        let E := fresh1 M in
        let p2' := fresh1 p2 in
        let p2_ := fresh p2' "_" in
        lets (p2_&E&_): M;
        apply~ noteq_sym;
        applys~ alloc_read_SExp_diff A (rm E))
    | _ => discriminate
    | R1 : read_SExp (state_memory ?S) p1 = _,
      R2 : read_SExp (state_memory ?S) p2 = _ |- _ =>
      solve [
        let E := fresh "E" in
        introv E; rewrite E in R2; rewrite R2 in R1; inverts~ R1 ]
    | _ =>
      solve [
          autos~
        | let E := fresh "E" in
          introv E; substs; simplify_context_base; false~ ]
    end in
  lazymatch goal with
  | |- ?p1 <> ?p2 => aux p1 p2
  | |- ?p1 = ?p2 -> False => aux p1 p2
  end.


(** We carry an hypothesis of the form [No_duplicates [p1; …; pn]]
  aiming to differentiate as many pointers [SEXP] as possible. **)

Ltac add_in_No_duplicates p :=
  (** First step: we add it in any hypothesis we can. **)
  repeat match goal with
  | D : No_duplicates ?l |- _ =>
    let already_in := compute_is_in p l in
    match already_in with
    | false =>
      let D' := fresh D in
      forwards D': No_duplicates_cons p D;
      [ abstract (
          let M := fresh "M" in
          introv M;
          explode_list M;
          gen M;
          prove_locations_different)
      | clear D; rename D' into D ]
    end
  end;
  (** Second step: we check that at least one hypothesis **)
  match goal with
  | D : No_duplicates ?l |- _ =>
    match l with
    | context [p] =>
      (** There is at least one hypothesis about this location. **)
      idtac
    end
  | _ =>
    (** There are no hypothesis about this location. **)
    let D := fresh "D" in
    forwards D: (No_duplicates_single p)
  end.

Ltac prepare_No_duplicates_hypothesis :=
  let already_has p :=
    match goal with
    | D : No_duplicates ?l |- _ =>
      let already_in := compute_is_in p l in
      match already_in with
      | true => constr:(true)
      end
    | _ => constr:(false)
    end in
  let must_be_new p :=
    let a := already_has p in
    lazymatch a with
    | false => idtac
    end in
  repeat match goal with
  | B : bound _ ?p |- _ =>
    must_be_new p;
    add_in_No_duplicates p
  | B : bound_such_that _ _ ?p |- _ =>
    must_be_new p;
    add_in_No_duplicates p
  | R : read_SExp _ ?p = Some _ |- _ =>
    must_be_new p;
    add_in_No_duplicates p
  | T : may_have_types _ _ ?p |- _ =>
    must_be_new p;
    add_in_No_duplicates p
  | L : list_type _ _ _ _ ?p |- _ =>
    must_be_new p;
    add_in_No_duplicates p
  | A : alloc_SExp _ _ = (_, ?p) |- _ =>
    must_be_new p;
    add_in_No_duplicates p
  | _ =>
    let r :=
      lazymatch goal with
      | D : @No_duplicates SEXP _ |- _ => constr:(true)
      | _ => constr:(false)
      end in
    lazymatch r with
    | false =>
      let D := fresh "D" in
      forwards D: (No_duplicates_nil SEXP)
    end
  end.

(** This tactic must be call before the [read_SExp] expressions are
  updated to the new state. **)
Ltac prepare_proofs_that_locations_are_different :=
  prepare_No_duplicates_hypothesis;
  repeat progress match goal with
  | A : alloc_SExp ?S ?p_ = (?S', ?p) |- _ =>
    add_in_No_duplicates p
  end.


(** ** Applying the right lemma **)

Ltac solve_premises_lemmae :=
  autos~;
  let deal_with_list_type S p :=
    let try_hypothesis L :=
      solve [ applys~ list_type_weaken L; solve_incl || (intros; solve_premises) ] in
    match goal with
    | L : list_type S _ _ _ p |- _ =>
      try_hypothesis L
    | L : list_type_such_that _ _ _ S _ _ _ p |- _ =>
      try_hypothesis L
    | L : list_type_safe S _ _ _ p |- _ =>
      try_hypothesis L
    | |- _ =>
      solve [
          get_may_have_types S p ltac:(fun M =>
            match type of M with
            | may_have_types S ?l p =>
              let rec allNil l :=
                lazymatch l with
                | nil => constr:(true)
                | NilSxp :: ?l' => let r := allNil l' in r
                | _ => constr:(false)
                end in
              let an := allNil l in
              lazymatch an with
              | true =>
                apply~ list_type_nil; applys~ may_have_types_weaken M; solve_incl
              end
            end)
        | apply list_type_cons; eexists; splits*;
          do 4 eexists; splits*; simplify_context_base;
          (solve_premises_lemmae || constructors; solve_premises_lemmae) ]
    end in
  abstract lazymatch goal with
  | |- bound ?S ?p =>
    match goal with
    | E : read_SExp (state_memory S) p = Some _ |- _ =>
      solve [ applys~ read_bound E; solve_premises ]
    | OKp : safe_pointer S p |- _ =>
      solve [ applys~ pointer_bound OKp; solve_premises ]
    | |- _ =>
      solve [
          get_may_have_types S p ltac:(fun M =>
            applys~ may_have_types_bound M; solve_premises)
        | apply* bound_such_that_weaken; solve_premises ]
    end
  | |- bound_such_that ?S ?p =>
    apply* bound_such_that_weaken; solve_incl || solve_premises
  | |- may_have_types ?S ?l ?p =>
    lazymatch p with
    | read_globals ?globals R_NilValue =>
      applys~ may_have_types_weaken R_NilValue_may_have_types; solve_incl
    | _ =>
      solve [
          get_may_have_types S p ltac:(fun M =>
            applys~ may_have_types_weaken M;
            solve_incl)
        | apply~ may_have_types_weaken; [ autos* | solve_incl ] ]
    end
  | |- list_type ?S ?l_t ?l_car ?l_tag ?p =>
    deal_with_list_type S p
  | |- list_type_such_that ?Pheader ?Pcar ?Ptag ?S ?l_t ?l_car ?l_tag ?p =>
    deal_with_list_type S p
  | |- list_type_safe ?S ?l_t ?l_car ?l_tag ?p =>
    deal_with_list_type S p
  | |- _ <> _ => prove_locations_different
  | |- _ \c _ => substs; solve_incl
  | |- _ \in _ => substs; Mem_solve
  | |- Mem _ _ => substs; Mem_solve
  | |- _ = _ => substs~; apply* BagInSingle_list
  | |- _ => solve_premises
  end.


(** ** Tactics taking advantage of the invariants **)

(** *** Getting the invariant **)

Ltac get_safe_state S cont :=
  match goal with
  | H : safe_state S |- _ => cont H
  | H : result_prop ?P_success _ _ (result_success S _) |- _ =>
    let I := fresh "Impl" in
    asserts I: (forall S r, P_success S r -> safe_state S);
    [solve [autos*]|];
    let R := fresh "Safe" in
    forwards* R: (rm I) H; [idtac];
    cont R
  | H : result_prop _ ?P_error _ (result_error S _) |- _ =>
    let I := fresh "Impl" in
    asserts I: (forall S, P_error S -> safe_state S);
    [solve [autos*]|];
    let R := fresh "Safe" in
    forwards* R: (rm I) H; [idtac];
    cont R
  | H : result_prop _ _ ?P_longjump (result_longjump S _ _) |- _ =>
    let I := fresh "Impl" in
    asserts I: (forall S n c, P_longjump S n c -> safe_state S);
    [solve [autos*]|];
    let R := fresh "Safe" in
    forwards* R: (rm I) H; [idtac];
    cont R
  end.

Ltac get_safe_globals S globals cont :=
  match goal with
  | H : safe_globals S globals |- _ => cont H
  end.

Ltac get_safe_pointer S p cont :=
  match goal with
  | H : safe_pointer S p |- _ => cont H
  | _ =>
    let p' := fresh1 p in
    let OKp := fresh "OK" p' in
    asserts OKp: (safe_pointer S p);
    [ apply* globals_not_NULL_safe; [idtac]; prove_not_NULL | cont OKp ]
  | _ =>
    get_safe_state S ltac:(fun H =>
      let R := fresh "Safe" in
      forwards~ R: safe_entry_points H; [idtac];
      cont R)
  | _ =>
    get_may_have_types S p ltac:(fun M =>
      match type of M with
      | may_have_types S ([NilSxp]) p =>
        let p' := fresh1 p in
        let OKp := fresh "OK" p' in
        asserts OKp: (safe_pointer S p);
        [ applys* may_have_types_NilSxp_safe_pointer M | cont OKp ]
      end)
  end.

Ltac get_safe_SExpRec S e_ cont :=
  let check_case check perform :=
    match goal with
    | _ => check e_; perform e_ cont
    | E : e_ = ?expr |- _ =>
      check expr; perform expr ltac:(fun R =>
        let e_' := fresh1 e_ in
        let R' := fresh "OK" e_' in
        asserts R': (safe_SExpRec S e_);
        [rewrite E; apply~ R|cont R'])
    | E : ?expr = e_ |- _ =>
      check expr; perform expr ltac:(fun R =>
        let e_' := fresh1 e_ in
        let R' := fresh "OK" e_' in
        asserts R': (safe_SExpRec S e_);
        [rewrite <- E; apply~ R|cont R'])
    end in
  match goal with
  | H : safe_SExpRec S e_ |- _ => cont H
  | H : safe_SExpRec_gen _ S e_ |- _ => cont H
  | P : read_SExp (state_memory S) ?e = Some e_ |- _ =>
    get_safe_pointer S e ltac:(fun H =>
      let e_' := fresh1 e_ in
      let R := fresh "OK" e_' in
      (forwards~ R: safe_SExpRec_read H P
       || rewrite safe_pointer_rewrite in H; forwards~ R: safe_SExpRec_read H P); [idtac];
      cont R)
  | _ =>
    check_case ltac:(fun e_ => match e_ with make_SExpRec_list _ _ _ _ => idtac end) ltac:(fun e_ cont =>
      match e_ with
      | make_SExpRec_list ?attrib ?car ?cdr ?tag =>
        get_safe_pointer S car ltac:(fun OKcar =>
          get_may_have_types S tag ltac:(fun Ttag =>
            get_safe_pointer S tag ltac:(fun OKtag =>
              let go L :=
                let e_' := fresh1 e_ in
                let R := fresh "OK" e_' in
                asserts R: (safe_SExpRec S e_);
                [ substs;
                  first [
                      applys~ safe_make_SExpRec_list OKcar L Ttag OKtag
                    | applys~ safe_make_SExpRec_list OKcar OKtag;
                      first [
                          applys~ list_type_weaken L
                        | applys~ may_have_types_weaken Ttag
                        | idtac ] ];
                  solve [ solve_premises_lemmae ]
                | cont R ] in
                match goal with
                | L : list_type S _ _ _ cdr |- _ => go L
                | L : list_type_safe S _ _ _ cdr |- _ => go L
                | L : list_type_such_that _ _ _ S _ _ _ cdr |- _ => go L
                | _ =>
                  get_may_have_types S cdr ltac:(fun Tcdr => go Tcdr)
                end)))
      | _ =>
        let e_' := fresh1 e_ in
        let R := fresh "OK" e_' in
        let T := fresh "T" in
        asserts R: (safe_SExpRec S e_);
        [ constructors; introv T; try solve [ substs; false~ ];
          constructors; do 3 eexists; splits; [autos*|..]; solve_premises_lemmae
        | cont R ]
      end)
  (* TODO: The other cases of the other types. *)
  end.


(** *** Simplifying the context **)

Ltac simplify_context :=
  repeat match goal with
  | T1 : may_have_types ?S ([NilSxp]) ?p1,
    T2 : may_have_types ?S ([NilSxp]) ?p2 |- _ =>
    get_safe_state S ltac:(fun Safe =>
      let E := fresh "E" in
      forwards~ E: only_one_nil Safe T1 (rm T2);
      try rewrite E in *; clear_trivial)
  | R1 : read_SExp (state_memory ?S) ?p1 = Some ?p1_,
    R2 : read_SExp (state_memory ?S) ?p2 = Some ?p2_,
    T1 : type (get_SxpInfo ?p1_) = NilSxp,
    T2 : type (get_SxpInfo ?p2_) = NilSxp |- _ =>
    get_safe_state S ltac:(fun Safe =>
      let E := fresh "E" in
      forwards~ E: only_one_nil_SExprRec Safe R1 R2 T1 T2;
      try rewrite E in *;
      let E_ := fresh "E_" in
      asserts E_: (p1_ = p2_); [rewrite R1 in R2; inverts~ R2|];
      try rewrite E_ in *;
      clear_trivial)
  | _ => simplify_context_base
  end.


(** ** Unfolding tactics **)

(** *** Getting object shapes **)

Ltac clear_useless_type_eq :=
  repeat match goal with
  | T1 : type (get_SxpInfo ?p_) = ?t,
    T2 : type (get_SxpInfo ?p_) = ?t |- _ => clear T2
  | T1 : type (get_SxpInfo ?p_) = ?t1,
    T2 : type (get_SxpInfo ?p_) = ?t2 |- _ =>
    solve [ rewrite T2 in T1; inverts T1 ]
  | T1 : type (get_SxpInfo ?p_) = ?t,
    T2 : type (get_SxpInfo ?p_) \in ?l |- _ =>
    rewrite T1 in T2;
    let isi := compute_is_in t l in
    lazymatch isi with
    | true => clear T2
    | false =>
      try solve [ false; repeat inverts T2 ]
    end
  | T : type (get_SxpInfo ?p_) \in [?t] |- _ => explode_list T
  end.

(** Generates an hypothesis of the form [type p_ = t] or [type p_ \in l]
  in the goal when possible. **)
Ltac put_type_in_context p_ :=
  match goal with
  | T : type (get_SxpInfo p_) = ?t |- _ => idtac
  | T : type (get_SxpInfo p_) \in _ |- _ => idtac
  | R : read_SExp (state_memory ?S) ?p = Some p_ |- _ =>
    get_may_have_types S p ltac:(fun M =>
      let T := fresh "T" in
      forwards T: may_have_types_read_SExp M R;
      put_type_in_context p_)
  end; clear_useless_type_eq.

(** Extracts relevant information for [p_] from an hypothesis
  of the form [safe_SExpRec]. The [explode] arguments tells the
  tactics whether exploding the type into all its possibilities
  is wanted. **)
Ltac force_unfold_shape explode S p_ :=
  let invert_type OKp_ :=
    put_type_in_context p_;
    let aux t :=
      lazymatch explode with
      | true => inverts~ OKp_; t
      | false =>
         try solve [ inverts~ OKp_; t ];
         (inverts~ OKp_; t; [idtac]) || solve [ inverts~ OKp_; t ]
      end in
    lazymatch goal with
    | T : type (get_SxpInfo p_) = ?t |- _ =>
      aux ltac:(try solve [ inverts~ T ])
    | T : type (get_SxpInfo p_) \in _ |- _ =>
      aux ltac:(try solve [ false; repeat inverts T ])
    end in
  lazymatch goal with
  | OKp_ : safe_SExpRec_type _ S (type (get_SxpInfo p_)) p_ |- _ => invert_type OKp_
  | _ =>
    get_safe_SExpRec S p_ ltac:(fun OKp_ =>
      let OKp_' := fresh1 OKp_ in
      forwards~ OKp_': SExpType_corresponds_to_datatype OKp_;
      invert_type OKp_')
  end.


Ltac unfold_shape explode S p_ :=
  lazymatch goal with
  | H : p_ = SExpRec_NonVector _ |- _ => idtac
  | H : p_ = SExpRec_VectorChar _ |- _ => idtac
  | H : p_ = SExpRec_VectorInteger _ |- _ => idtac
  | H : p_ = SExpRec_VectorComplex _ |- _ => idtac
  | H : p_ = SExpRec_VectorReal _ |- _ => idtac
  | H : p_ = SExpRec_VectorPointer _ |- _ => idtac
  | _ => force_unfold_shape explode S p_
  end.

Ltac unfold_may_hide_read_SExp :=
  repeat match goal with
  | E : move_along_path_from ?l _ _ = _ |- _ =>
    let OKl := is_fully_computed l in
    match OKl with
    | true => unfold move_along_path_from in E; rew_list in E; simpl in E
    end
  | E : move_along_path_step _ _ _ = _ |- _ =>
    unfold move_along_path_step in E
  end.

Ltac unfold_shape_pointer explode S p :=
  match goal with
  | R : read_SExp (state_memory S) p = Some ?p_ |- _ =>
    unfold_shape explode S p_
  | |- _ =>
    let p' := fresh1 p in
    let p_ := fresh p' "_" in
    let R := fresh "E" in
    unfold_may_hide_read_SExp;
    destruct (read_SExp (state_memory S) p) as [p_|] eqn: R;
    tryfalse~;
    [idtac];
    unfold_shape explode S p_
  end.

Ltac unfold_shape_pointer_explode := unfold_shape_pointer true.
Ltac unfold_shape_pointer_one := unfold_shape_pointer false.


(** *** Dealing with [read_SExp] **)

Ltac rewrite_read_SExp :=
  match goal with
  | |- context [ read_SExp (state_memory ?S) ?e ] =>
    let bound_such_that_prop T :=
      let e' := fresh1 e in
      let e_ := fresh e' "_" in
      let Ee_ := fresh "E" e_ in
      let Pe_ := fresh T e_ in
      lets (e_&Ee_&Pe_): (rm T);
      try rewrite Ee_ in * in
    lazymatch goal with
    | E : read_SExp (state_memory S) e = _ |- _ => rewrite E
    | B : bound_such_that S ?P e |- _ => bound_such_that_prop B
    | B : bound S e |- _ => bound_such_that_prop B
    | _ =>
      get_may_have_types S e ltac:(bound_such_that_prop)
    end;
    try unfold_shape_pointer false S e
  end; clear_trivial.

(** Tries to prove a new equality of the form [write_SExp S p p_]. **)
Ltac define_write_SExp S p p_ :=
  lazymatch goal with
  | E : write_SExp S p p_ = Some ?S' |- _ => try rewrite E in *
  | _ =>
    let S' := fresh1 S in
    let ES' := fresh "E" S' in
    destruct (write_SExp S p p_) as [S'|] eqn:ES';
    [ solve [
          false;
          match goal with
          | A : alloc_SExp _ _ = (S, p) |- _ =>
            applys~ alloc_write_SExp_not_None A ES'
          | E : read_SExp (state_memory S) p = Some _ |- _ =>
            let R := fresh "R" in
            rewrites >> write_read_SExp_None (rm ES') in E;
            inverts~ E
          end
        | autos~; simpl; autos* ]
    | try rewrite ES'; try assumption ]
  end.


(** ** Dealing with pointer exceptions **)

Ltac prove_no_null_pointer_exceptions :=
  let A := fresh "A" in
  abstract lazymatch goal with
  | |- ~ null_pointer_exceptions_suffix ?path =>
    match goal with
    | N : ~ null_pointer_exceptions_suffix ?l |- _ =>
      apply N || (introv A; apply N; inverts~ A; constructors~)
    | E : move_along_path_from path ?S ?p_ = _ |- _ =>
      introv A; inverts~ A;
      unfold_shape_pointer_explode S p_;
      solve [ inverts E; false~ ]
    | |- _ =>
      introv A; inverts~ A
    end
  | |- ~ null_pointer_exceptions_globals ?g =>
    introv A; inverts~ A
  (* TODO: The other cases. *)
  end.


(** ** Proving expression types different **)

Ltac prove_types_different :=
  simplify_context;
  let aux t1 t2 :=
    let rec rewrite_type t :=
      match t with
      | _ =>
        lazymatch goal with
        | E : t = _ |- _ => rewrite E
        | E : t \in _ |- _ => explode_list E; rewrite E
        end
      | type (get_SxpInfo ?p_) =>
        match goal with
        | E : read_SExp (state_memory ?S) ?p = Some p_ |- _ =>
          get_may_have_types S p ltac:(fun T =>
            let L := fresh "L" in
            forwards L: may_have_types_read_SExp T E;
            explode_list L; rewrite L)
        end
      end in
    solve [
        try rewrite_type t1; try rewrite_type t2; (discriminate || substs~; discriminate)
      | let E := fresh "E" in
        introv E; substs; false~ ] in
  lazymatch goal with
  | |- ?t1 <> ?t2 => aux t1 t2
  | |- ?t1 = ?t2 -> False => aux t1 t2
  end.


(** ** Solving frequent patterns. **)

Ltac solve_premises_smart :=
  lazymatch goal with
  | |- safe_state ?S =>
    get_safe_state S ltac:(fun OKS => apply OKS)
  | |- safe_globals ?S ?globals =>
    get_safe_globals S globals ltac:(fun OKg => apply OKg)
  | |- safe_pointer ?S ?e =>
    get_safe_pointer S e ltac:(fun OKe => apply OKe)
  | |- safe_pointer_gen safe_pointer ?S ?e =>
    get_safe_pointer S e ltac:(fun OKe => rewrite <- safe_pointer_rewrite; apply OKe)
  | |- safe_SExpRec ?S ?e_ =>
    get_safe_SExpRec S e_ ltac:(fun OKe_ => apply OKe_)
  | |- safe_header safe_pointer ?S ?h =>
    constructors; solve_premises_smart
  | |- _ <> _ =>
    first [
        prove_locations_different
      | prove_types_different
      | apply~ safe_pointer_not_NULL; solve_premises_smart ]
  | _ => prove_no_null_pointer_exceptions || solve_premises_lemmae
  end.


(** ** Transitions between states **)

(** Tries to find a term of the form [conserve_old_binding S S']
  in the goal, typically from an allocation. **)
Ltac find_conserve_old_binding S S' cont :=
  lazymatch goal with
  | C : conserve_old_binding S S' |- _ => cont C
  | E : alloc_SExp S ?p_ = (S', ?p) |- _ =>
    let C := fresh "C" in
    forwards~ C: alloc_SExp_conserve_old_binding E;
    cont C
  end.

(** Given two states whose property [conserve_old_binding S S'] is
  producable by the above tactic, this tactic tries to update the
  predicates of the goal about [S] to predicates about [S']. **)
Ltac transition_conserve S S' :=
  prepare_proofs_that_locations_are_different;
  let update_safe_props_from_alloc A S S' p_ :=
    lazymatch goal with
    | OKS : safe_state S |- _ =>
      get_safe_SExpRec S p_ ltac:(fun OKp_ =>
        let S'' := fresh1 S' in
        let OKS' := fresh "OK" S'' in
        let OKp_' := fresh1 OKp_ in
        forwards~ OKS': alloc_SExp_safe_state (rm OKS) OKp_ A;
        try prove_types_different ;
        [idtac];
        forwards~ OKp_': conserve_old_binding_safe_SExpRec (rm OKp_);
        try applys~ alloc_SExp_conserve_old_binding A;
        [idtac])
    end in
  find_conserve_old_binding S S' ltac:(fun C =>
    first [
        syntactically_the_same S S'
      | repeat lazymatch goal with
        | A : alloc_SExp ?S0 ?p_ = (S, ?p) |- _ =>
          try update_safe_props_from_alloc A S0 S p_;
          let E := fresh "E" in
          forwards E: alloc_read_SExp_eq (rm A)
        | E : read_SExp (state_memory S) ?p = Some ?p_ |- _ =>
          let E' := fresh E in
          forwards E': conserve_old_binding_read C (rm E);
          rename E' into E
        | A : alloc_SExp ?S ?p_ = (S', ?p) |- _ =>
          try update_safe_props_from_alloc A S S' p_;
          let E := fresh "E" in
          forwards E: alloc_read_SExp_eq (rm A)
        | B : bound S ?p |- _ =>
          let B' := fresh B in
          forwards B': conserve_old_binding_bound C (rm B);
          rename B' into B
        | E : may_have_types S ?l ?p |- _ =>
          let E' := fresh E in
          forwards E': conserve_old_binding_may_have_types C (rm E);
          rename E' into E
        | E : list_type S ?l_t ?l_car ?l_tag ?p |- _ =>
          let E' := fresh E in
          forwards E': conserve_old_binding_list_type C (rm E);
          rename E' into E
        | E : list_head S ?l_t ?l_car ?l_tag ?p_ |- _ =>
          let E' := fresh E in
          forwards E': conserve_old_binding_list_head C (rm E);
          rename E' into E
        | E : list_type_such_that ?Pheader ?Pcar ?Ptag S ?l_t ?l_car ?l_tag ?p |- _ =>
          let E' := fresh E in
          forwards E': conserve_old_binding_list_type C (rm E);
          rename E' into E
        | E : list_head_such_that ?Pcar ?Ptag S ?l_t ?l_car ?l_tag ?p_ |- _ =>
          let E' := fresh E in
          forwards E': conserve_old_binding_list_head C (rm E);
          rename E' into E
        | E : list_type_safe S ?l_t ?l_car ?l_tag ?p |- _ =>
          let E' := fresh E in
          forwards E': conserve_old_binding_list_type_safe C (rm E);
          rename E' into E
        | E : list_head_safe S ?l_t ?l_car ?l_tag ?p_ |- _ =>
          let E' := fresh E in
          forwards E': conserve_old_binding_list_head_safe C (rm E);
          rename E' into E
        | OKp : safe_pointer S ?p |- _ =>
          let OKp' := fresh OKp in
          forwards OKp': conserve_old_binding_safe_pointer C (rm OKp);
          rename OKp' into OKp
        | G : safe_globals S ?globals |- _ =>
          let G' := fresh G in
          forwards G': conserve_old_binding_safe_globals C (rm G);
          rename G' into G
        end; simplify_context ]).

(** If the state [S'] has been produced from [S] by the
  [write_SExp] function, this tactic tries to update the
  predicates of the goal about [S] to predicates about [S']. **)
Ltac transition_write_SExp S S' :=
  prepare_proofs_that_locations_are_different;
  let find_write cont :=
    lazymatch goal with
    | W : write_SExp S ?p ?p_ = Some S' |- _ => cont W
    | E : Some S' = write_SExp S ?p ?p_ |- _ =>
      let W := fresh E in
      lets W: E; symmetry in W; try clear E;
      cont W
    end in
  find_write ltac:(fun W =>
    let R := fresh "E" in
    forwards~ R: read_write_SExp_eq W;
    repeat match goal with
    | E : read_SExp (state_memory S) ?p = Some ?p_ |- _ =>
      lazymatch type of R with
      | read_SExp (state_memory S') p = _ => clear E
      | _ =>
        let E' := fresh E in
        forwards E': read_write_SExp_neq W E;
        [ prove_locations_different | rewrite E' in E; clear E' ]
      end
    | A : alloc_SExp _ ?p_ = (S, ?p) |- _ =>
      apply alloc_read_SExp_Some in A;
      let E := fresh A in
      forwards E: read_write_SExp_neq R A;
      [ prove_locations_different | rewrite E in A; clear E ]
    | B : bound S ?p |- _ =>
      let B' := fresh B in
      forwards~ B': bound_write W (rm B);
      rename B' into B
    | E : may_have_types S ?l ?p |- _ =>
      match type of W with
      | write_SExp S p ?p_ =>
        clear E;
        try match goal with
        | T : type (get_SxpInfo p_) = ?t |- _ =>
          forwards E: may_have_types_write_SExp_eq_exact W T
        | T : type (get_SxpInfo p_) \in ?t |- _ =>
          forwards E: may_have_types_write_SExp_eq W T
        end
      | _ =>
        let E' := fresh E in
        forwards E': may_have_types_write_SExp W E;
        [ prove_locations_different | rewrite E' in E; clear E' ]
      end
    (*| E : list_type S ?l_t ?l_car ?l_tag ?p |- _ =>
      Unfortunately the lemma for list types is quite complex:
      we have to prove that we did not rewrite any pointer of the list.
      For this, we probably need a stronger logics, like separation logic.
      Although we might still be able to prove it in the case of alloc_SExp
      (which is the most common). TODO *)
    end; simplify_context).


(** * Correctness lemmae of some R functions **)

(** ** [TYPEOF] **)

Lemma TYPEOF_pass : forall S x t,
  may_have_types S ([t]) x ->
  TYPEOF S x = result_success S t.
Proof. introv T. unfolds. rewrite_read_SExp. simplifyR. self_rewrite. Qed.

Lemma TYPEOF_result : forall S x t,
  may_have_types S ([t]) x ->
  result_prop (fun S r => r = t) (fun _ => False) (fun _ _ _ => False) (TYPEOF S x).
Proof. introv T. unfolds TYPEOF. rewrite_read_SExp. simplifyR. Qed.


(** ** [CONS] **)

Lemma CONS_safe : forall globals S S' l_car l_tag car cdr l,
  safe_state S ->
  safe_globals S globals ->
  safe_pointer S car ->
  list_type_safe S ([ListSxp]) l_car l_tag cdr ->
  may_have_types S l_car car ->
  l_car \c all_storable_SExpTypes ->
  l_tag \c [NilSxp; CharSxp] ->
  CONS globals S car cdr = (S', l) ->
  safe_state S' /\ safe_globals S' globals /\ safe_pointer S' l
  /\ list_type_safe S' ([ListSxp]) l_car ([NilSxp] \u l_tag) l.
Proof.
  introv OKS OKG OKcar Lcdr Tcar Icar Itag E. unfolds in E.
  transition_conserve S S'.
  splits; try solve_premises_smart.
  rewrite safe_pointer_rewrite. constructors.
  - (** pointer_bound **)
    applys* read_bound.
  - (** no_null_pointer_along_path_step **)
    introv N Em. unfolds in Em. self_rewrite_in Em. simpl in Em.
    destruct s as [|?|[| |]|?|?|?|?]; inverts~ Em; try solve_premises_smart.
    applys safe_pointer_not_NULL. applys~ list_type_safe_ListSxp OKG Lcdr.
  - (** safe_pointer_along_path_step **)
    introv Em NN. unfolds in Em. rewrite E0 in Em. simpl in Em.
    destruct s as [|?|[| |]|?|?|?|?]; inverts~ Em.
    applys~ list_type_safe_ListSxp OKG Lcdr.
  - (** safe_SExpRec_read **)
    self_rewrite. introv E2. inverts E2. constructors.
    simpl. constructors. simplify_context.
    do 4 eexists. splits*; try solve_premises_smart.
Qed.


(** ** [allocList] **)

Lemma allocList_aux_safe : forall globals S S' n l l0,
  safe_state S ->
  safe_globals S globals ->
  safe_pointer S l0 ->
  list_type_safe S ([ListSxp]) ([NilSxp]) ([NilSxp]) l0 ->
  allocList_aux globals S n l0 = (S', l) ->
  safe_state S' /\ safe_globals S' globals /\ safe_pointer S' l
  /\ list_type_safe S' ([ListSxp]) ([NilSxp]) ([NilSxp]) l.
Proof.
  introv OKS OKG OKl0 L E. gen S S' l. induction n; introv OKS OKG OKl0 L E.
  - inverts E. splits~.
  - simpl in E. destruct allocList_aux as [S2 p] eqn: Ep.
    forwards~ (OKS2&OKG2&OKp&Lp): IHn Ep.
    forwards~ (OKS'&OKG'&OKl&Ll): CONS_safe Lp E; try solve_premises_smart.
    simplify_context. splits*.
Qed.

Lemma allocList_safe : forall globals S S' n l,
  safe_state S ->
  safe_globals S globals ->
  allocList globals S n = (S', l) ->
  safe_state S' /\ safe_globals S' globals /\ safe_pointer S' l
  /\ list_type_safe S' ([ListSxp]) ([NilSxp]) ([NilSxp]) l.
Proof.
  introv OKS OKG E. unfolds in E. applys~ allocList_aux_safe E.
  - applys~ globals_not_NULL_safe OKG. applys~ globals_not_NULL OKG.
    introv A. inverts A.
  - apply list_type_nil. applys~ R_NilValue_may_have_types OKG.
Qed.


(** * Specific tactics **)

Ltac get_result_lemma t :=
  lazymatch get_head t with
  | TYPEOF => constr:(>> TYPEOF_pass TYPEOF_result)
  end.

Ltac apply_result_lemma t :=
  let R := get_result_lemma t in
  let L := list_boxer_of R in
  let rec try_all_lemmae L :=
    lazymatch L with
    | boxer ?R :: ?L' =>
      first [
          rewrite R
        | eapply R
        | let P := fresh "P" in
          eapply if_success_result; [ introv P | solve [ apply* R] ]
        | try_all_lemmae L' ]
    end in
  try_all_lemmae L;
  simplify_context;
  try solve_premises_smart.

Ltac computeR_step :=
  simplifyR;
  rewrite_read_SExp;
  match goal with
  | |- context [ read_SExp (state_memory ?S) ?x ] =>
    rewrite_read_SExp
  | |- context [ write_SExp ?S ?p ?p_ ] =>
    define_write_SExp S p p_;
    match goal with
    | E : write_SExp S p p_ = Some ?S' |- _ =>
      repeat rewrite E;
      transition_write_SExp S S'
    end
  | |- context [ alloc_SExp ?S ?p_ ] =>
    let p := fresh "p" in
    let S' := fresh1 S in
    let E := fresh "E" S' in
    destruct (alloc_SExp S p_) as [S' p] eqn: E;
    transition_conserve S S'
  | |- context [ TYPEOF ?S ?e ] =>
    apply_result_lemma (TYPEOF S e)
  | |- context [ CONS ?globals ?S ?car ?cdr ] =>
    let S' := fresh1 S in
    let l := fresh "l" in
    let E := fresh "E" l in
    destruct (CONS globals S car cdr) as [S' l] eqn: E;
    let OKS' := fresh "OK" S' in
    let OKG' := fresh "OKG" in
    let OKl' := fresh "OK" l in
    let L := fresh "L" in
    forwards (OKS'&OKG'&OKl'&L): CONS_safe E; try solve_premises_smart;
    [idtac];
    simplify_context
  | |- context [ allocList ?globals ?S ?n ] =>
    let S' := fresh1 S in
    let l := fresh "l" in
    let E := fresh "E" l in
    destruct (allocList globals S n) as [S' l] eqn: E;
    let OKS' := fresh "OK" S' in
    let OKG' := fresh "OKG" in
    let OKl' := fresh "OK" l in
    let L := fresh "L" in
    forwards (OKS'&OKG'&OKl'&L): allocList_safe E; try solve_premises_smart;
    [idtac]
  end;
  clear_trivial.

Ltac computeR :=
  repeat computeR_step.
