(*
 * This file is part of SAWJA
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

open Javalib_pack
open JBasics
open Javalib

(** Common code for SSA representations*)

(** Signature of IR to transform in SSA*)
module type IRSig = sig
  (** Abstract data type for variables *)
  type var

  (** [var_equal v1 v2] is equivalent to [v1 = v2], but is faster.  *)
  val var_equal : var -> var -> bool

  (** [var_orig v] is [true] if and only if the variable [v] was already used at
      bytecode level. *)
  val var_orig : var -> bool

  (** Used only for internal transformations. *)
  val var_ssa : var -> bool

  (** [var_name v] returns a string representation of the variable [v]. *)
  val var_name : var -> string

  (** [var_name_debug v] returns, if possible, the original variable name of [v], 
      if the initial class was compiled using debug information. *)
  val var_name_debug : var -> string option

  (** [var_name_g v] returns a string representation of the variable [v]. 
      If the initial class was compiled using debug information, original 
      variable names are build on this information. It is equivalent to
      [var_name_g x = match var_name_debug with Some s -> s | _ -> var_name x] *)
  val var_name_g : var -> string

  (** [bc_num v] returns the local var number if the variable comes from the initial bytecode program. *)
  val bc_num : var -> int option

  (** [index v] returns the hash value of the given variable. *)
  val index : var -> int

  type instr

  val print_instr : ?show_type:bool -> instr -> string

  type exception_handler = {
    e_start : int;
    e_end : int;
    e_handler : int;
    e_catch_type : JBasics.class_name option;
    e_catch_var : var
  }

  (** [t] is the parameter type for JBir methods. *)
  type t = {
    vars : var array;  
    (** All variables that appear in the method. [vars.(i)] is the variable of
	index [i]. *)
    params : (JBasics.value_type * var) list;
    (** [params] contains the method parameters (including the receiver this for
	virtual methods). *)
    code : instr array;
    (** Array of instructions the immediate successor of [pc] is [pc+1].  Jumps
	are absolute. *)
    exc_tbl : exception_handler list;
    (** [exc_tbl] is the exception table of the method code. Jumps are
	absolute. *)
    line_number_table : (int * int) list option;
    (** [line_number_table] contains debug information. It is a list of pairs
	[(i,j)] where [i] indicates the index into the bytecode array at which the
	code for a new line [j] in the original source file begins.  *)
    pc_bc2ir : int Ptmap.t;
    (** map from bytecode code line to ir code line (very sparse). *)
    pc_ir2bc : int array; 
    (** map from ir code line to bytecode code line *)
  }

  (** [jump_target m] indicates whether program points are join points or not in [m]. *)
  val jump_target : t -> bool array

  (** [exception_edges m] returns a list of edges [(i,e);...] where
      [i] is an instruction index in [m] and [e] is a handler whose
      range contains [i]. *)
  val exception_edges :  t -> (int * exception_handler) list

  module InstrRep : functor(Var : Cmn.VarSig) -> Bir.InstrSig

end

module type VarSig =
sig
  type ir_var
  type var = ir_var * int
  val var_equal : var -> var -> bool
  val var_orig : var -> bool
  val var_name_debug: var -> string option
  val var_name: var -> string
  val var_name_g: var -> string
  val bc_num: var -> int option
  val var_origin : var -> ir_var
  val var_ssa_index : var -> int
end

module Var (IR:IRSig) : VarSig with type ir_var = IR.var

module T (Var : VarSig) 
  (Instr : Bir.InstrSig) 
  : sig
    type var_t = Var.var
    type instr_t = Instr.instr
    type exception_handler = {
      e_start : int;
      e_end : int;
      e_handler : int;
      e_catch_type : class_name option;
      e_catch_var : Var.var
    }
	
    type t = {
      params : (JBasics.value_type * Var.var) list;
      code : Instr.instr array;
      phi_nodes : (Var.var * Var.var array) list array;
      (** Array of phi nodes assignments. Each phi nodes assignments at point [pc] must
	  be executed before the corresponding [code.(pc)] instruction. *)
      exc_tbl : exception_handler list;
      line_number_table : (int * int) list option;
      pc_bc2ir : int Ptmap.t;
      pc_ir2bc : int array; 
    }

    (** [print_handler exc] returns a string representation for
	exception handler [exc]. *)
    val print_handler : exception_handler -> string
      

    val jump_target : t -> bool array

    (** [print_phi_node phi] returns a string representation for phi node [phi]. *)
    val print_phi_node : Var.var * Var.var array -> string

    (** [print_phi_nodes phi_list] returns a string representation for phi nodes 
	[phi_list]. *)
    val print_phi_nodes : (Var.var * Var.var array) list -> string

    (** [print c] returns a list of string representations for instruction of [c]
	(one string for each program point of the code [c]). *)
    val print : t -> string list
      
    (** [exception_edges m] returns a list of edges [(i,e);...] where
	[i] is an instruction index in [m] and [e] is a handler whose
	range contains [i]. *)
    val exception_edges :  t -> (int * exception_handler) list
  end

module type TSsaSig = 
sig
  type var_t
  type instr_t
  type exception_handler
  type t = {
    params : (JBasics.value_type * var_t) list;
    (** [params] contains the method parameters (including the receiver this for
	virtual methods). *)
    code : instr_t array;
    (** Array of instructions the immediate successor of [pc] is [pc+1].  Jumps
	are absolute. *)
    phi_nodes : (var_t * var_t array) list array;
    (** Array of phi nodes assignments. Each phi nodes assignments at point [pc] must
	be executed before the corresponding [code.(pc)] instruction. *)
    exc_tbl : exception_handler list;
    (** [exc_tbl] is the exception table of the method code. Jumps are
	absolute. *)
    line_number_table : (int * int) list option;
    (** [line_number_table] contains debug information. It is a list of pairs
	[(i,j)] where [i] indicates the index into the bytecode array at which the
	code for a new line [j] in the original source file begins.  *)
    pc_bc2ir : int Ptmap.t;
    (** map from bytecode code line to ir code line (very sparse). *)
    pc_ir2bc : int array; 
    (** map from ir code line to bytecode code line *)
  }  
end 

module type IR2SsaSig = sig
  type ir_t
  type ir_var
  type ir_instr
  type ir_exc_h
  type ssa_var
  type ssa_instr
  type ssa_exc_h
  type live_res
  val use_bcvars : ir_instr -> Ptset.t
  val def_bcvar : ir_instr -> Ptset.t
  val var_defs : ir_t -> Ptset.t Ptmap.t
  val map_instr : (ir_var -> ssa_var) -> (ir_var -> ssa_var) -> ir_instr -> ssa_instr
  val map_exception_handler : ir_exc_h -> ssa_exc_h
  val preds : ir_t -> int -> int list
  val succs : ir_t -> int -> int list
  val live_analysis : ir_t -> int -> live_res
  val live_result : (int -> live_res) -> int -> ir_var -> bool
end


module SSA 
  (IR:IRSig) 
  (TSSA:TSsaSig with type var_t = IR.var * int)
  (IR2SSA:IR2SsaSig
   with type ir_t = IR.t
   and type ir_var = IR.var
   and type ir_instr = IR.instr
   and type ir_exc_h = IR.exception_handler
   and type ssa_var = IR.var * int
   and type ssa_instr = TSSA.instr_t
   and type ssa_exc_h = TSSA.exception_handler
  )
  : 
sig
  val transform_from_ir : IR.t -> TSSA.t
end
