{
    (** This file mainly translates the functions [token] and [yylex] from File gram.y. **)

    (* Copyright © 2018 Martin Bodin

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

    open Extract
    open ParserUtils
    open Parser

    exception SyntaxError of string
}

(** * Definitions **)

(** ** Numerical **)

let digit = ['0'-'9']
let sign = ['+' '-']
let floating_point =
  ((digit+ '.'? digit* ) | (digit* '.'? digit+))
  (['e' 'E'] sign? digit+)?
let octal_digit = ['0'-'7']
let hexadecimal_digit = ['0'-'9' 'a'-'f' 'A'-'F']
let hexadecimal =
  ("0x" | "0X") hexadecimal_digit*
  (('.' hexadecimal_digit* )? ['p' 'P'] sign? digit+)?
let reg_numeric = (floating_point | hexadecimal)
let reg_integer = (reg_numeric as value) 'L'
let reg_imaginary = (reg_numeric as value) 'i'

(** ** Strings **)

let string_enclosing = ['\'' '"' '`']
let escapable_char = ['\'' '"' 'n' 'r' 't' 'b' 'a' 'f' 'v' '\\' '\n' '`']
let normal_character = [^ '\\' '\'' '"' '`' '\x00'] (* This is improvable. *)

(** ** Language Features **)

(** *** Identifiers **)
let reg_identifier =
  (** For simplicity, we do not deal with locales. **)
  "." | (
    ('.' ['_' '.' 'a'-'z' 'A'-'Z'] | ['a'-'z' 'A'-'Z'])
    ['_' '.' 'a'-'z' 'A'-'Z' '0'-'9']* )

let reserved_keywords =
  "if" | "else" | "repeat" | "while" | "function" | "for" | "in" | "next" | "break"
  | "TRUE" | "FALSE" | "NULL" | "Inf" | "NaN"
  | "NA" | "NA_integer_" | "NA_real_" | "NA_complex_" | "NA_character_"
  | "..." | ".." ['0'-'9']+

(** *** Special Operators **)
let reg_special_operator =
  '%' [^ '%']* '%'

let operator_arithmetic =
  "+" | "-" | "*" | '/' | "%%" | "^"
let operator_relational =
  ">" | ">=" | "<" | "<=" | "==" | "!="
let operator_logical =
  "!" | "&" | "|"
let operator_model_formulae =
  "~"
let operator_assignment =
  "->" | "<-"
let operator_list_indexing =
  "$"
let operator_sequence =
  ":"

(** ** Miscellaneous **)

(** *** Spaces **)
let space = ' ' | '\t' | '\x0c' (** Form feed **) | '\xa0' (** Replacement character **)


(** * Rules **)

rule lex = parse

  (** ** Special Symbols **)
  | "NULL"              { eatLines := false ; NULL_CONST nilValue }
  | "NA"                { eatLines := false ; NUM_CONST (no_runs mkNA) }
  | "TRUE"              { eatLines := false ; NUM_CONST (no_runs mkTrue) }
  | "FALSE"             { eatLines := false ; NUM_CONST (no_runs mkFalse) }
  | "Inf"               { eatLines := false ; NUM_CONST (no_runs (fun g -> alloc_vector_real g (ArrayList.from_list [r_PosInf]))) }
  | "NaN"               { eatLines := false ; NUM_CONST (no_runs (fun g -> alloc_vector_real g (ArrayList.from_list [r_NaN]))) }
  | "NA_integer_"       { eatLines := false ; NUM_CONST (no_runs (fun g -> alloc_vector_int g (ArrayList.from_list [nA_INTEGER]))) }
  | "NA_real_"          { eatLines := false ; NUM_CONST (no_runs (fun g -> alloc_vector_real g (ArrayList.from_list [nA_REAL]))) }
  | "NA_character_"     { eatLines := false ; NUM_CONST (no_runs (fun g -> alloc_vector_str g (ArrayList.from_list [read_globals g NA_STRING]))) }
  | "NA_complex_"       { eatLines := false ; NUM_CONST (no_runs (fun g -> alloc_vector_cplx g (ArrayList.from_list [make_Rcomplex nA_REAL nA_REAL]))) }
  | "function"          { eatLines := true ; FUNCTION (install_and_save "function") }
  | "while"             { eatLines := true ; WHILE (install_and_save "while") }
  | "repeat"            { eatLines := true ; REPEAT (install_and_save "repeat") }
  | "for"               { eatLines := true ; FOR (install_and_save "for") }
  | "if"                { ifpush () ; eatLines := true ; IF (install_and_save "if") }
  | "in"                { eatLines := true ; IN }
  | "else"              { ifpop () ; eatLines := true ; ELSE }
  | "next"              { eatLines := false ; NEXT (install_and_save "next") }
  | "break"             { eatLines := false ; BREAK (install_and_save "break") }
  | "..."               { eatLines := false ; SYMBOL (install_and_save "...") }

  (** ** Strings **)
  | string_enclosing as c           { string c [] lexbuf }

  (** ** Special Values **)
  | reg_special_operator as name    { eatLines := true ; SPECIAL (install_and_save name) }
  | reg_integer                     { eatLines := false ; NUM_CONST (mkIntCheck value) }
  | reg_numeric as value            { eatLines := false ; NUM_CONST (mkFloat value) }
  | reg_imaginary                   { eatLines := false ; NUM_CONST (mkComplex value) }

  (** ** Operators **)
  | "?"         { eatLines := true ; QUESTION_MARK (install_and_save "?") }
  | "<-"        { eatLines := true ; LEFT_ASSIGN (install_and_save "<-") }
  | "->"        { eatLines := true ; RIGHT_ASSIGN (install_and_save "<-") }
  | "<<-"       { eatLines := true ; LEFT_ASSIGN (install_and_save "<<-") }
  | "->>"       { eatLines := true ; RIGHT_ASSIGN (install_and_save "<<-") }
  | ":="        { eatLines := true ; LEFT_ASSIGN (install_and_save ":=") }
  | "="         { eatLines := true ; EQ_ASSIGN (install_and_save "=") }
  | "~"         { eatLines := true ; TILDE (install_and_save "~") }
  | "+"         { eatLines := true ; PLUS (install_and_save "+") }
  | "-"         { eatLines := true ; MINUS (install_and_save "-") }
  | "*"         { eatLines := true ; TIMES (install_and_save "*") }
  | "/"         { eatLines := true ; DIV (install_and_save "/") }
  | "^" | "**"  { eatLines := true ; EXP (install_and_save "^") }
  | "<"         { eatLines := true ; LT (install_and_save "<") }
  | "<="        { eatLines := true ; LE (install_and_save "<=") }
  | ">"         { eatLines := true ; GT (install_and_save ">") }
  | ">="        { eatLines := true ; GE (install_and_save ">=") }
  | "=="        { eatLines := true ; EQ (install_and_save "==") }
  | "!="        { eatLines := true ; NE (install_and_save "!=") }
  | "!"         { eatLines := true ; NOT (install_and_save "!") }
  | "&&"        { eatLines := true ; AND2 (install_and_save "&&") }
  | "&"         { eatLines := true ; AND (install_and_save "&") }
  | "||"        { eatLines := true ; OR2 (install_and_save "||") }
  | "|"         { eatLines := true ; OR (install_and_save "|") }
  | "$"         { eatLines := true ; DOLLAR (install_and_save "$") }
  | "@"         { eatLines := true ; AT (install_and_save "@") }
  | ":::"       { NS_GET_INT (install_and_save ":::") }
  | "::"        { NS_GET (install_and_save "::") }
  | ":"         { eatLines := true ; COLON (install_and_save ":") }

  (** ** Parentheses **)
  | "("     { contextp := Contextp_Par :: !contextp ; LPAR (install_and_save "(") }
  | ")"     { wifpop () ; contextp_pop () ; eatLines := false ; RPAR }
  | "{"     { contextp := Contextp_Bra :: !contextp ; eatLines := true ; LBRACE (install_and_save "{") }
  | "}"     { wifpop () ; contextp_pop () ; RBRACE }
  | "[["    { contextp := Contextp_SqBra :: Contextp_SqBra :: !contextp ; LBB (install_and_save "[[") }
  | "["     { contextp := Contextp_SqBra :: !contextp ; LSQBRACKET (install_and_save "[") }
  | "]"     { wifpop () ; contextp_pop () ; eatLines := false ; RSQBRACKET }

  (** ** Miscellaneous **)
  | reg_identifier as str           { eatLines := false ; SYMBOL (install_and_save str) }
  | ";"                             { ifpop () ; SEMICOLON }
  | ","                             { ifpop () ; COMMA }
  | ('#' [^ '\n']* as cmd)? '\n'    { if !eatLines
                                         || contextp_hd () = Contextp_Par
                                         || contextp_hd () = Contextp_SqBra
                                      then lex lexbuf
                                      else if contextp_hd () = Contextp_If then
                                        new_line_if_case lexbuf
                                      else NEW_LINE (match cmd with Some s -> s | None -> "") }
  | space+                          { lex lexbuf }
  | _                               { raise (SyntaxError ("Unexpected char: " ^ Lexing.lexeme lexbuf)) }
  | eof                             { END_OF_INPUT }

and new_line_if_case = parse
  | ('#' [^ '\n']* )? '\n'  { new_line_if_case lexbuf }
  | space+                  { new_line_if_case lexbuf }
  | "}"                     { wifpop () ; contextp_pop () ; RBRACE }
  | ")"                     { wifpop () ; contextp_pop () ; RPAR }
  | "]"                     { wifpop () ; contextp_pop () ; RSQBRACKET }
  | ","                     { ifpop () ; COMMA }
  | "else"                  { eatLines := true ; ifpop () ; ELSE }
  | ""                      { ifpop () ; NEW_LINE "" }

and string enclos rev = parse

  | normal_character as c           { string enclos (c :: rev) lexbuf }
  | "\\x" (hexadecimal_digit as h1) (hexadecimal_digit as h2)
                                    { string enclos (unescaped_R_x2 h1 h2 :: rev) lexbuf }
  | "\\x" (hexadecimal_digit as h)  { string enclos (unescaped_R_x1 h :: rev) lexbuf }
  | "\\" (octal_digit as o1) (octal_digit as o2) (octal_digit as o3)
                                    { string enclos (unescaped_R_o3 o1 o2 o3 :: rev) lexbuf }
  | "\\" (octal_digit as o1) (octal_digit as o2)
                                    { string enclos (unescaped_R_o2 o1 o2 :: rev) lexbuf }
  | "\\" (escapable_char as c)      { match unescaped_char c with
                                      | Some c -> string enclos (c :: rev) lexbuf
                                      | None -> assert false }
  (** We ignore multibyte locales for now (N.B., only for [enclos <> '`'). **)

  | string_enclosing as c           { if c = enclos then (
                                        eatLines := false ;
                                        if enclos = '`' then
                                          SYMBOL (fun g r -> install g r (List.rev rev))
                                        else
                                          STR_CONST (no_runs (fun g -> mkString g (List.rev rev)))
                                      ) else string enclos (c :: rev) lexbuf }

  | '\\' _                          { raise (SyntaxError ("Unrecognised escape in character string: " ^ Lexing.lexeme lexbuf)) }
  | eof                             { raise (SyntaxError "Incomplete string") }
  | _                               { raise (SyntaxError ("Unexpected char: " ^ Lexing.lexeme lexbuf)) }

