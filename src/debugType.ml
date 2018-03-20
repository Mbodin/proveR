(** Debug Type **)

open Extract

type funtype =
  | Result_unit of (globals -> runs_type -> state -> unit result)
  | Result_bool of (globals -> runs_type -> state -> bool result)
  | Result_int of (globals -> runs_type -> state -> int result)
  | Result_int_list of (globals -> runs_type -> state -> int list result)
  | Result_float of (globals -> runs_type -> state -> float result)
  | Result_string of (globals -> runs_type -> state -> char list result)
  | Result_pointer of (globals -> runs_type -> state -> sEXP result)

  | Argument_unit of (unit -> funtype)
  | Argument_bool of (bool -> funtype)
  | Argument_int of (int -> funtype)
  | Argument_float of (float -> funtype)
  | Argument_pointer of (sEXP -> funtype)
