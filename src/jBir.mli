(*
 * This file is part of SAWJA
 * Copyright (c)2009 Delphine Demange (INRIA)
 * Copyright (c)2009 David Pichardie (INRIA)
 *
 * This program is free software: you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program.  If not, see
 * <http://www.gnu.org/licenses/>.
 *)

(** Stackless, unstructured intermediate representation for Java Bytecode, in which expression trees are reconstructed and method and constructor calls are folded.*)

(** {2 Language} *)

(** {3 Expressions} *)

(** Constants *)
type const =
    [ `ANull
    | `Byte of int
    | `Class of JBasics.object_type
    | `Double of float
    | `Float of float
    | `Int of int32
    | `Long of int64
    | `Short of int
    | `String of string ]

(** Abstract data type for variables *)
type var

(** Catched exception are store in [catch_var]. *)
val catch_var : var

(** [var_orig v] is [true] if and only if the variable [v] was already used at bytecode level. *)
val var_orig : var -> bool

(** [var_equal v1 v2] tests the equality of variables [v1] and [v2]. *)
val var_equal : var -> var -> bool

(** [var_name v] returns a string representation of the variable [v]. *)
val var_name : var -> string

(** [var_name_debug v] returns, if possible the original variable names of [v], 
    if the initial class was compiled using debug information. *)
val var_name_debug : var -> string option

(** [var_name_g v] returns a string representation of the variable [v]. 
    If the initial class was compiled using debug information, original 
    variable names are build on this information. It is equivalent to
    [var_name_g x = match var_name_debug with Some s -> s | _ -> var_name x] *)
val var_name_g : var -> string

(** [bcvar i] returns the canonic var name associated with the [i]th local var. *)
val bcvar : int -> var

(** Conversion operators *)
type conv = I2L  | I2F  | I2D
  | L2I  | L2F  | L2D
  | F2I  | F2L  | F2D
  | D2I  | D2L  | D2F
  | I2B  | I2C  | I2S

(** Unary operators *)
type unop =
    Neg of JBasics.jvm_basic_type
  | Conv of conv
  | ArrayLength
  | InstanceOf of JBasics.object_type
  | Cast of JBasics.object_type

(** Comparison operators *)
type comp = DG | DL | FG | FL | L


(** Binary operators *)
type binop =
    ArrayLoad of JBasics.value_type
  | Add of JBasics.jvm_basic_type
  | Sub of JBasics.jvm_basic_type
  | Mult of JBasics.jvm_basic_type
  | Div of JBasics.jvm_basic_type
  | Rem of JBasics.jvm_basic_type
  | IShl  | IShr  | IAnd  | IOr  | IXor  | IUshr
  | LShl  | LShr  | LAnd  | LOr  | LXor  | LUshr
  | CMP of comp

(** Side-effect free expressions *)
type expr =
    Const of const (** constants *)
  | Var of JBasics.value_type * var (** variables are given a type information *)
  | Unop of unop * expr
  | Binop of binop * expr * expr
  | Field of expr * JBasics.class_name * JBasics.field_signature (** Reading fields of arbitrary expressions *)
  | StaticField of JBasics.class_name * JBasics.field_signature (** Reading static fields *)

(** [type_of_expr e] returns the type of the expression [e]. *)
val type_of_expr : expr -> JBasics.value_type

(** {3 Instructions} *)

type virtual_call_kind =
  | VirtualCall of JBasics.object_type
  | InterfaceCall of JBasics.class_name

(** [check] is the type of JBir assertions. They are generated by the transformation so that execution errors arise 
in the same order in the initial bytecode program and its JBir version. Next to each of them is the informal semantics they should be given. *)
type check =
  | CheckNullPointer of expr  (** [CheckNullPointer e] checks that the expression [e] is not a null pointer and raises the Java NullPointerException if this not the case. *)
  | CheckArrayBound of expr * expr (** [CheckArrayBound(a,idx)] checks the index [idx] is a valid index for the array denoted by the expression [a] and raises the Java IndexOutOfBoundsException if this is not the case. *)
  | CheckArrayStore of expr * expr (** [CheckArrayStore(a,e)] checks [e] can be stored as an element of the array [a] and raises the Java ArrayStoreException if this is not the case. *)
  | CheckNegativeArraySize of expr (** [CheckNegativeArray e] checks that [e], denoting an array size, is positive or zero and raises the Java NegativeArraySizeException if this is not the case.*)
  | CheckCast of expr * JBasics.object_type (** [CheckCast(e,t)] checks the object denoted by [e] can be casted to the object type [t] and raises the Java ClassCastException if this is not the case. *)
  | CheckArithmetic of expr (** [CheckArithmetic e] checks that the divisor [e] is not zero, and raises ArithmeticExcpetion if this is not the case. *)


(** JBir instructions are register-based and unstructured. Next to them is the informal semantics (using a traditional instruction notations) they should be given. *)
type instr =
    Nop
  | AffectVar of var * expr (** [AffectVar(x,e)] denotes x := e.  *)
  | AffectArray of expr * expr * expr (** [AffectArray(a,idx,e)] denotes   a\[idx\] := e. *)
  | AffectField of expr * JBasics.class_name * JBasics.field_signature * expr (** [AffectField(e,c,fs,e')] denotes   e.<c:fs> := e'. *)
  | AffectStaticField of JBasics.class_name * JBasics.field_signature * expr  (** [AffectStaticField(c,fs,e)] denotes   <c:fs> := e .*)
  | Goto of int (** [Goto pc] denotes goto pc. (absolute address) *)
  | Ifd of ([ `Eq | `Ge | `Gt | `Le | `Lt | `Ne ] * expr * expr) * int (** [Ifd((op,e1,e2),pc)] denotes    if (e1 op e2) goto pc. (absolute address) *)
  | Throw of expr (** [Throw e] denotes throw e.  *)
  | Return of expr option (** [Return opte] denotes 
- return void when [opte] is [None] 
- return opte otherwise 
*)
  | New of var * JBasics.class_name * JBasics.value_type list * expr list (** [New(x,c,tl,args)] denotes x:= new c<tl>(args),  [tl] gives the type of [args]. *)
  | NewArray of var * JBasics.value_type * expr list  (** [NewArray(x,t,el)] denotes x := new c\[e1\]...\[en\] where ei are the elements of [el] ; they represent the length of the corresponding dimension. Elements of the array are of type [t].  *)
  | InvokeStatic of var option * JBasics.class_name *  JBasics.method_signature * expr list (** [InvokeStatic(x,c,ms,args)] denotes 
- c.m<ms>(args) if [x] is [None] (void returning method)
-  x :=  c.m<ms>(args) otherwise 
*)
  | InvokeVirtual of var option * expr * virtual_call_kind * JBasics.method_signature * expr list (** [InvokeVirtual(x,e,k,ms,args)] denotes the [k] call
-  e.m<ms>(args) if [x] is [None]  (void returning method)
-  x := e.m<ms>(args) otherwise 
*)
  | InvokeNonVirtual of var option * expr * JBasics.class_name * JBasics.method_signature * expr list (** [InvokeNonVirtual(x,e,c,ms,args)] denotes the non virtual call
-  e.C.m<ms>(args) if [x] is [None]  (void returning method)
-  x := e.C.m<ms>(args) otherwise 
*)
  | MonitorEnter of expr (** [MonitorEnter e] locks the object [e]. *)
  | MonitorExit of expr (** [MonitorExit e] unlocks the object [e]. *)
  | MayInit of JBasics.class_name (** [MayInit c] initializes the class [c] whenever it is required. *)
  | Check of check (** [Check c] evaluates the assertion [c]. *)

(** [t] is the parameter type for JBir methods. *)
type t = {
  params : (JBasics.value_type * var) list; (** [params] contains the method parameters (including the receiver this for virtual methods). *)
  code : (int * instr list) list; (** Each element of [code] is a pair [(pc,instrs)] where 
				      each [pc] indexes an [instr] list corresponding to the instructions generated from the  bytecode  at [pc]. *)
  exc_tbl : JCode.exception_handler list; (** [exc_tbl] is the exception table of the method code. *)
  line_number_table : (int * int) list option; (** [line_number_table] contains debug information. It is a list of pairs [(i,j)] meaning the code line [i] corresponds to the line [j] at the java source level. *) 
  jump_target : bool array (** [jump_target] indicates whether program points are join points or not. *) 
}


(** {2 Printing functions} *)

(** [print_expr e] returns a string representation for expression [e]. *)
val print_expr : expr -> string

(** [print_instr ins] returns a string representation for instruction [ins]. *)
val print_instr : instr -> string

(** [print_instrs (pc,insl)] returns a string representation for instructions [insl] at program point [pc]. *)
val print_instrs : (int * instr list) -> string

(** [print c] returns a list of string representations for instruction of [c] (one string for each program point of the code [c]). *)
val print : t -> string list

(** {2 Bytecode transformation} *)

(** [transform b cm jcode] transforms the code [jcode] into its JBir representation. The transformation is performed in the context of a given concrete method [cm]. According to the boolean [~compress:b], all program points made of a single [Nop] instruction are removed from the obtained JBir representation. 
[transform b cm jcode] can raise several exceptions. See exceptions below for details. *) 
val transform : ?bcv:bool -> ?compress:bool -> JCode.jcode Javalib.concrete_method -> JCode.jcode -> t

val flatten_code : t -> instr array * int array * int Ptmap.t * JCode.exception_handler list

(** {2 Exceptions} *)

(** {3 Exceptions due to the transformation limitations} *)

exception Uninit_is_not_expr (** [Uninit_is_not_expr] is raised in case an uninitialised reference is used as a traditional expression (variable assignment, field reading etc).*)
exception NonemptyStack_backward_jump (** [NonemptyStack_backward_jump] is raised when a backward jump on a non-empty stack is encountered. This should not happen if you compiled your Java source program with the javac compiler *)
exception Type_constraint_on_Uninit (** [Type_constraint_on_Uninit] is raised when the requirements about stacks for folding constructors are not satisfied. *)
exception Content_constraint_on_Uninit (** [Content_constraint_on_Uninit] is raised when the requirements about stacks for folding constructors are not satisfied. *)
exception Subroutine (** [Subroutine] is raised in case the bytecode contains a subroutine. *)


(** {3 Exceptions due to a non-Bytecode-verifiable bytecode} *)

exception Bad_stack (** [Bad_stack] is raised in case the stack does not fit the length/content constraint of the bytecode instruction being transformed. *)
exception Bad_Multiarray_dimension (** [Bad_Multiarray_dimension] is raise when attempting to transforming a multi array of dimension zero. *)




