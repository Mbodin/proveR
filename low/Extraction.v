(** Extraction.
  Extract R interpreter into OCaml. **)

Require Export Rinit Rparsing.

Extraction Language Ocaml.

Require Import ExtrOcamlBasic.
Require Import ExtrOcamlNatInt.
Require Import ExtrOcamlString.

Set Extraction AccessOpaque.

(* TODO: Clean. *)
(* As classical logic statements are now unused, they should not be extracted
   (otherwise, useless errors will be launched). *)
Extraction Inline (*epsilon epsilon_def*) classicT arbitrary indefinite_description (*Inhab_witness*) Fix isTrue.

Extract Inductive positive => "int"
[ "(fun p -> 1 + (2 * p))"
  "(fun p -> 2 * p)"
  "1" ]
"(fun f2p1 f2p f1 p ->
  if p <= 1 then f1 () else if p mod 2 = 0 then f2p (p / 2) else f2p1 (p / 2))".

Extract Inductive Z => "int" [ "0" "" "(~-)" ]
"(fun f0 fp fn z -> if z = 0 then f0 () else if z > 0 then fp z else fn (~- z))".

Extract Inductive N => "int" [ "0" "" ]
"(fun f0 fp n -> if n = 0 then f0 () else fp n)".

Extract Constant Z.add => "(+)".
Extract Constant Z.succ => "(+) 1".
Extract Constant Z.pred => "(fun x -> x - 1)".
Extract Constant Z.sub => "(-)".
Extract Constant Z.mul => "( * )".
Extract Constant Z.opp => "(~-)".
Extract Constant Z.abs => "abs".
Extract Constant Z.min => "min".
Extract Constant Z.max => "max".
Extract Constant Z.compare =>
 "fun x y -> if x = y then Eq else if x < y then Lt else Gt".

Extract Constant Pos.add => "(+)".
Extract Constant Pos.succ => "(+) 1".
Extract Constant Pos.pred => "(fun x -> x - 1)".
Extract Constant Pos.sub => "(-)".
Extract Constant Pos.mul => "( * )".
Extract Constant Pos.min => "min".
Extract Constant Pos.max => "max".
Extract Constant Pos.compare =>
 "fun x y -> if x = y then Eq else if x < y then Lt else Gt".
Extract Constant Pos.compare_cont =>
 "fun c x y -> if x = y then c else if x < y then Lt else Gt".

Extract Constant N.add => "(+)".
Extract Constant N.succ => "(+) 1".
Extract Constant N.pred => "(fun x -> x - 1)".
Extract Constant N.sub => "(-)".
Extract Constant N.mul => "( * )".
Extract Constant N.min => "min".
Extract Constant N.max => "max".
Extract Constant N.div => "(fun x y -> if x = 0 then 0 else (x / y)".
Extract Constant N.modulo => "mod".
Extract Constant N.compare =>
 "fun x y -> if x=y then Eq else if x<y then Lt else Gt".

Extract Inductive Fappli_IEEE.binary_float => "float" [
  "(fun s -> if s then (0.) else (-0.))"
  "(fun s -> if s then infinity else neg_infinity)"
  "(fun _ -> nan)"
  "(fun (s, m, e) -> failwith ""FIXME: No extraction from binary float allowed yet."")"
].

Extract Constant int_to_double => "float_of_int".

Extract Constant HeapList.heap "'a" "'b" => "('a, 'b) PMap.t".
Extract Constant HeapList.empty => "Obj.magic PMap.create compare".
Extract Constant HeapList.write => "fun h k v -> PMap.add k v h".
Extract Constant HeapList.to_list => "fun h -> PMap.foldi (fun k v l -> (k, v) :: l) h []".
Extract Constant HeapList.read => "fun comparable h k -> PMap.find k h".
Extract Constant HeapList.read_option => "fun comparable h k -> try Some (PMap.find k h) with Not_found -> None".
Extract Constant HeapList.rem => "fun comparable h k -> PMap.remove k h".
Extract Constant HeapList.indom_decidable => "fun comparable h k -> PMap.mem k h".

(*Extract Constant ascii_comparable => "(=)".
Extract Constant lt_int_decidable => "(<)".
Extract Constant le_int_decidable => "(<=)".
Extract Constant ge_nat_decidable => "(>=)".*)

(* The following functions make pattern matches with floats and shall thus be removed. *)
Extraction Inline Fappli_IEEE.Bplus Fappli_IEEE.binary_normalize Fappli_IEEE_bits.b64_plus.
Extraction Inline Fappli_IEEE.Bmult Fappli_IEEE.Bmult_FF Fappli_IEEE_bits.b64_mult.
Extraction Inline Fappli_IEEE.Bdiv Fappli_IEEE_bits.b64_div.

(* LATER: When the parser will be in Coq, most of what is forcely being extracted here will be useless. *)
Extraction "low.ml" NBits all_GlobalVariables
  Parsing ScalarReal ScalarInteger mkNA alloc_vector_cplx R_PosInf R_NaN NA_INTEGER NA_REAL make_Rcomplex mkString
  setup_Rmainloop empty_state eval_global.

