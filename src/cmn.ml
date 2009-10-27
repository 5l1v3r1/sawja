open JBasics
open JCode


type mode = Normal | Flat | Addr3

type const =
    [ `ANull
    | `Byte of int
    | `Class of object_type
    | `Double of float
    | `Float of float
    | `Int of int32
    | `Long of int64
    | `Short of int
    | `String of string ]

type conv = I2L | I2F | I2D   | L2I | L2F | L2D   | F2I | F2L | F2D  | D2I | D2L | D2F  | I2B | I2C | I2S

type unop =
  | Neg of jvm_basic_type
  | Conv of conv
  | ArrayLength
  | InstanceOf of JBasics.object_type

type comp =  DG | DL | FG | FL | L

type typ = Ref | Num

type var =
  | OriginalVar of int * string option  (* register number, name (debug if available) *)
  | TempVar of int
  | RetVar
  | BranchVar of int * int
  | BranchVar2 of int * int

let catch_var = TempVar 0

let print_const = function
  | `ANull -> "null"
  | `Int i -> Printf.sprintf "%ld" i
  | `Long i -> Printf.sprintf "%Ld" i
  | `Float f -> Printf.sprintf "%f" f
  | `Double f -> Printf.sprintf "%f" f
  | `Byte n -> Printf.sprintf "%d" n
  | `Short a -> Printf.sprintf "%d " a
  | `Class c -> Printf.sprintf "%s" (JDumpBasics.object_value_signature c)
  | `String s -> Printf.sprintf "'%s'" s

let varname =  "$bcvar"
let tempname =  "$irvar"
let branchvarname =  "$T"
let branchvarname2 =  "$T'"

let var_name_debug = function
  | OriginalVar (_,s) -> s
  | _ -> None

let var_name = function
  | OriginalVar (j,_) -> Printf.sprintf  "%s%d" varname j
  | TempVar i -> Printf.sprintf "%s%d" tempname i
  | RetVar -> "RetVar"
  | BranchVar (i,j) -> Printf.sprintf "%s%d_%d" branchvarname j i
  | BranchVar2 (i,j) -> Printf.sprintf "%s%d_%d" branchvarname2 j i

let var_name_g x =
  match var_name_debug x with
    | Some s -> s
    | None -> var_name x

let print_unop = function
  | Neg t -> Printf.sprintf "%cNeg" (JDumpBasics.jvm_basic_type t)
  | Conv conv ->
      begin
	match conv with
	  | I2L -> "I2L"  | I2F -> "I2F"  | I2D -> "I2D"
	  | L2I -> "L2I"  | L2F -> "L2F"  | L2D -> "L2D"
	  | F2I -> "F2I"  | F2L -> "F2L"  | F2D -> "F2D"
	  | D2I -> "D2I"  | D2L -> "D2L"  | D2F -> "D2F"
	  | I2B -> "I2B"  | I2C -> "I2C"  | I2S -> "I2S"
      end
  | ArrayLength -> "ArrayLength"
  | InstanceOf ot -> Printf.sprintf "InstanceOf %s" (Javalib.JPrint.object_type ot)

let print_typ t =
  let bt2ss = function
    | `Long -> "J"
    | `Float -> "F"
    | `Double -> "D"
    | `Int -> "I"
    | `Short -> "S"
    | `Char -> "C"
    | `Byte -> "B"
    | `Bool -> "Z"
  in
  let rec ot2ss = function
    | TClass _ -> "O"
    | TArray t -> "["^ vt2ss t
  and vt2ss = function
    | TBasic t -> bt2ss t
    | TObject t -> ot2ss t
  in vt2ss t

(* Tests if two variable expressions denote the same variable *)
(* todo : compare reg number then strings, true is conservative *)
let var_equal tvar svar =
    match tvar, svar with
      | OriginalVar (n,s1), OriginalVar (m,s2) ->  m = n && s1 = s2
      | x, y  -> x=y

let var_orig = function
  | OriginalVar _ -> true
  | _ -> false

