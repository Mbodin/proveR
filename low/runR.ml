(** RunR
 * Main file. It runs the interactive Coq R interpreter. **)

(** * References to Options **)

let interactive = ref true
let max_steps = ref max_int

let readable_pointers = ref true
let show_memory = ref false
let show_globals = ref true
let show_initials = ref false
let show_gp = ref false
let gp_opt = ref true
let show_attrib = ref false
let show_data = ref false
let show_details = ref false
let vector_line = ref false
let charvec_string = ref false
let no_temporary = ref false
let show_context = ref true

let show_globals_initial = ref false
let show_result_after_computation = ref true
let show_state_after_computation = ref false

(** * Generating List of Options **)

let boolean_switches =
  let make_boolean_switch categories dep verb_small_on verb_small_off verb_verbatim_on verb_verbatim_off pointer command noun =
    (categories, dep, verb_small_on, verb_small_off, verb_verbatim_on, verb_verbatim_off, pointer, command, noun) in
  let category_print = ("show", "hide", "all", "Show", "Hide", "every available information about the state", false) in
  let category_read = ("human", "computer", "readable", "human", "computer", "Makes the output easily readable by a", true) in
  let category_computation = ("show", "hide", "computations", "Show", "Hide", "intermediate computations", false) in
  let print_switch categories dep =
    make_boolean_switch (category_print :: categories) dep "show" "hide" "Show" "Hide" in
  let write_switch categories dep =
    make_boolean_switch (category_read :: categories) dep "use" "no" "Write" "Do not write" in
  let computation_switch categories dep =
    make_boolean_switch (category_computation :: categories) dep "show" "hide" "Show" "Do not show" in
  let show_data_switch = print_switch [] [] show_data "data" "the data of vectors" in
  let show_gp_switch = print_switch [] [] show_gp "gp" "the general purpose field of basic language elements" in
  [
    print_switch [] [] show_memory "memory" "the state of the memory" ;
    print_switch [] [] show_context "context" "the execution context" ;
    print_switch [] [] show_globals "globals" "the value of (non-constant) global variables" ;
    print_switch [] [] show_initials "initials" "the value of constant global variables" ;
    show_gp_switch ;
    print_switch [] [] show_attrib "attrib" "the attribute field of basic language elements" ;
    show_data_switch ;
    print_switch [] [] show_details "details" "the pointers stored in each basic language element" ;
    write_switch [] [] readable_pointers "abr" "pointers in a human readable way" ;
    write_switch [] [show_data_switch] vector_line "inline-vector" "vectors as line instead of column" ;
    write_switch [] [show_data_switch] charvec_string "string" "character vectors as strings instead of a list of characters" ;
    write_switch [] [show_gp_switch] gp_opt "num-gp" "the general purpose field as a number instead of a bit vector" ;
    computation_switch [] [] show_result_after_computation "result" "the result of intermediate computation" ;
    computation_switch [] [] show_state_after_computation "state" "the intermediate state after each computation" ;
    computation_switch [] [] show_globals_initial "globals-initial" "the value of constant global variables in the beginning"
  ]

let get_pointer (_, _, _, _, _, _, p, _, _) = p
let get_categories (l, _, _, _, _, _, _, _, _) = l
let get_dependencies (_, d, _, _, _, _, _, _, _) = d

let name_switch v (_, _, vsy, vsn, vvy, vvn, p, c, n) =
  (if v then vsy else vsn) ^ "-" ^ c

let base_suffix = "-base"
let name_switch_base v b =
  name_switch v b ^ if get_dependencies b = [] then "" else base_suffix

let all_categories =
  let rec aux c = function
    | x :: l ->
      aux (c @ List.filter (fun x -> not (List.mem x c)) (get_categories x)) l
    | [] -> c
  in aux [] boolean_switches

let make_options prefix switch_on switch_off set_int as_function =
  let name_switch v b = prefix ^ name_switch v b in
  let name_switch_base v b = prefix ^ name_switch_base v b in
  [(prefix ^ "no-temporary", switch_on no_temporary, "Do not show basic element with a temporary named field") ;
   (prefix ^ "steps", set_int max_steps, "Set the maximum number of steps of the interpreter") ]
  @ List.concat (List.map (fun b ->
      let (_, d, vsy, vsn, vvy, vvn, p, c, n) = b in
      let deps = String.concat " " (List.map (name_switch true) d) in
      let print_dep =
        " (to be used in combination with " ^ deps ^ ")" in
      let default b =
        if b then " (default)" else "" in
      let ret dep_text print_dep = [
          (name_switch true b ^ dep_text, switch_on p, vvy ^ " " ^ n ^ print_dep ^ default !p) ;
          (name_switch false b ^ dep_text, switch_off p, vvn ^ " " ^ n ^ print_dep ^ default (not !p))
        ] in
      let set_with_dep v _ =
        List.iter (fun b -> get_pointer b := true) d ;
        p := v in
      if d = [] then
        ret "" ""
      else
        ret base_suffix print_dep @ [
            (name_switch true b, as_function (set_with_dep true),
              vvy ^ " " ^ n ^ " (equivalent to " ^ deps ^ " " ^ name_switch_base true b ^ ")") ;
            (name_switch false b, as_function (set_with_dep false),
              vvn ^ " " ^ n ^ " (equivalent to " ^ deps ^ " " ^ name_switch_base false b ^ ")")
          ]) boolean_switches)
  @ List.concat (List.map (fun c ->
      let this_category =
        List.filter (fun b -> List.mem c (get_categories b)) boolean_switches in
      let (vsy, vsn, c, vvy, vvn, e, r) = c in
      let equivalent v =
        " (equivalent to " ^ String.concat " " (List.map (name_switch_base v) this_category) ^ ")" in
      let all v _ =
        List.iter (fun b -> get_pointer b := v) this_category in [
        (prefix ^ vsy ^ "-" ^ c, as_function (all true), (if r then e ^ " " ^ vvy else vvy ^ " " ^ e) ^ equivalent true) ;
        (prefix ^ vsn ^ "-" ^ c, as_function (all false), (if r then e ^ " " ^ vvn else vvn ^ " " ^ e) ^ equivalent false) ;
      ]) all_categories)

(** * Reading Arguments **)

let _ =
    Arg.parse
      (("-non-interactive", Arg.Clear interactive, "Non-interactive mode")
        :: make_options "-" (fun p -> Arg.Set p) (fun p -> Arg.Clear p) (fun p -> Arg.Set_int p) (fun f -> Arg.Unit f))
      (fun str -> prerr_endline ("I do not know what to do with “" ^ str ^ "”."))
      "This programs aims at mimicking the core of R. Usage:\n\trunR.native [OPTIONS]\nCommands are parsed from left to right.\nDuring interactive mode, type “#help” to get some help."

(** * Main Loop **)

let print_and_continue g r s pr cont =
  Print.print_defined r s (fun s r ->
    if !show_state_after_computation then (
      print_endline "State:" ;
      print_endline (Print.print_state 2 !show_context !show_memory !show_globals !show_initials !no_temporary
        (!show_gp, !gp_opt, !show_attrib, !show_data, !show_details, !vector_line, !charvec_string)
        !readable_pointers s g)) ;
    if !show_result_after_computation then
      print_endline ("Result: " ^ pr 8)) cont

let _ =
  Print.print_defined (Low.setup_Rmainloop !max_steps Low.empty_state) Low.empty_state (fun s g ->
    if !show_globals_initial then
      print_endline (Print.print_state 2 !show_context !show_memory!show_globals !show_initials !no_temporary
        (!show_gp, !gp_opt, !show_attrib, !show_data, !show_details, !vector_line, !charvec_string)
        !readable_pointers s g)) (fun s g ->
    (** Initialing the read-eval-print-loop **)
    let buf = Lexing.from_channel stdin in
    print_string "> "; flush stdout;
    try
        let _ = Parser.main Lexer.lex buf in ()
    with
    | Parser.Error ->
      print_endline ("Parser error at offset " ^ string_of_int (Lexing.lexeme_start buf) ^ "."))

