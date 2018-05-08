(** Features.FNames.
  The function names of this file correspond to the function names
  in the file main/names.c. **)

(* Copyright © 2018 Martin Bodin, Tomás Díaz

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA *)

Set Implicit Arguments.
Require Import Rcore.
Require Import FUtil.

Section Parameters.

Variable globals : Globals.

Let read_globals := read_globals globals.
Local Coercion read_globals : GlobalVariable >-> SEXP.

Variable runs : runs_type.

Local Coercion Pos.to_nat : positive >-> nat.

Local Coercion int_to_double : Z >-> double.


Definition do_internal S (call op args env : SEXP) : result SEXP :=
  add%stack "do_internal" in
  run%success Rf_checkArityCall globals runs S op args call using S in
  read%list args_car, _, _ := args using S in
  let s := args_car in
  let%success pl := isPairList S s using S in
  if negb pl then
    result_error S "Invalid .Internal() argument."
  else
    read%list s_car, s_cdr, _ := s using S in
    let sfun := s_car in
    let%success isym := isSymbol S sfun using S in
    if negb isym then
      result_error S "Invalid .Internal() argument."
    else
      read%sym _, sfun_sym := sfun using S in
      ifb sym_internal sfun_sym = R_NilValue then
        result_error S "There is no such .Internal function."
      else
        let%success args :=
          let args := s_cdr in
          let%success sfun_internal_type := TYPEOF S (sym_internal sfun_sym) using S in
          ifb sfun_internal_type = BuiltinSxp then
            evalList globals runs S args env call 0
          else result_success S args using S in
        let%success f := PRIMFUN runs S (sym_internal sfun_sym) using S in
        let%success ans := f S s (sym_internal sfun_sym) args env using S in
        result_success S ans.

Fixpoint R_Primitive_loop S R_FunTab primname lmi :=
  let i := ArrayList.length R_FunTab - lmi in
  (** For termination, the loop variable has been reversed.
    In C, the loop variable is [i] and not [lmi = ArrayList.length R_FunTab - i]. **)
  match lmi with
  | 0 =>
    (** [i = ArrayList.length R_FunTab] **)
    result_success S (R_NilValue : SEXP)
  | S lmi =>
    let c := ArrayList.read R_FunTab i in
    ifb fun_name c = primname then
      if funtab_eval_arg_internal (fun_eval c) then
        result_success S (R_NilValue : SEXP)
      else
        let%success prim :=
          mkPRIMSXP globals runs S i (funtab_eval_arg_eval (fun_eval c)) using S in
        result_success S prim
    else R_Primitive_loop S R_FunTab primname lmi
  end.

Definition R_Primitive S primname :=
  add%stack "R_Primitive" in
  let%success R_FunTab := get_R_FunTab runs S using S in
  R_Primitive_loop S R_FunTab primname (ArrayList.length R_FunTab).

Definition do_primitive S (call op args env : SEXP) : result SEXP :=
  add%stack "do_primitive" in
  run%success Rf_checkArityCall globals runs S op args call using S in
  read%list args_car, _, _ := args using S in
  let name := args_car in
  let%success ist := isString S name using S in
  let%success len := LENGTH globals S name using S in
  ifb ~ ist \/ len <> 1 then
    result_error S "String argument required."
  else
    let%success strel := STRING_ELT S name 0 using S in
    ifb strel = R_NilValue then
      result_error S "String argument required."
    else
      let%success strel_ := CHAR S strel using S in
      let%success prim := R_Primitive S strel_ using S in
      ifb prim = R_NilValue then
        result_error S "No such primitive function."
      else result_success S prim.


(** In contrary to the original C, this function here takes as argument
  the structure of type [funtab_cell] in addition to its range in the
  array [R_FunTab]. **)
Definition installFunTab S c offset : result unit :=
  add%stack "installFunTab" in
  let%success prim :=
    mkPRIMSXP globals runs S offset (funtab_eval_arg_eval (fun_eval c)) using S in
  let%success p := install globals runs S (fun_name c) using S in
  read%sym p_, p_sym := p using S in
  let p_sym :=
    if funtab_eval_arg_internal (fun_eval c) then {|
        sym_pname := sym_pname p_sym ;
        sym_value := sym_value p_sym ;
        sym_internal := prim
      |}
    else {|
        sym_pname := sym_pname p_sym ;
        sym_value := prim ;
        sym_internal := sym_internal p_sym
      |} in
  let p_ := {|
      NonVector_SExpRec_header := NonVector_SExpRec_header p_ ;
      NonVector_SExpRec_data := p_sym
    |} in
  write%defined p := p_ using S in
  result_success S tt.

Definition Spec_name :=
  [ "if" ; "while" ; "repeat" ; "for" ; "break" ; "next" ; "return" ; "function" ;
    "(" ; "{" ;
    "+" ; "-" ; "*" ; "/" ; "^" ; "%%" ; "%/%" ; "%*%" ; ":" ;
    "==" ; "!=" ; "<" ; ">" ; "<=" ; ">=" ;
    "&" ; "|" ; "&&" ; "||" ; "!" ;
    "<-" ; "<<-" ; "=" ;
    "$" ; "[" ; "[[" ;
    "$<-" ; "[<-" ; "[[<-" ]%string.

End Parameters.

