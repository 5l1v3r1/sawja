(*
 * This file is part of SAWJA
 * Copyright (c)2011 Vincent Monfort (INRIA)
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

(** Printer for Eclipse plugin for SAWJA *)

open Javalib_pack
open JBasics
open Javalib
open JProgram


(** This module allows to generate information data for the Eclipse
    plugin for SAWJA. It allows to add warning on source code in the
    JDT (Java Development Toolkit) of Eclipse and to attach
    information on the analysis state on the code in order to help
    Java programmer or for debugging purpose on analysis.*)

 
(** {2 Program information.} *)



(** This module is an adapted and simplified version of
    org.eclipse.jdt.core.dom.AST grammar, it allows to produce
    detailed warnings in order to try to find the exact node concerned
    in Java source code*)
module AdaptedASTGrammar :
sig
  type identifier = 
      SimpleName of string * value_type option
	(** It could be a variable identifier, field name, class name,
	    etc. Only use the shortest name possible (no package name
	    before class name, no class name before a field name, etc.).*)
  type expression = 
    (*| NullLiteral 
    | StringLiteral of string
    | TypeLiteral of identifier
    | OtherLiteral of float*)
	(* Others constants (impossible to differenciate int and bool in bytecode, ...)*)
    | Assignment of identifier
	(** Corresponds to assignement instructions ('*store' (except
	    array), 'put*field').Identifier must be the identifier of
	    the left_side of assignment (field's name or variable's
	    name)*)
    | ClassInstanceCreation of class_name
	(** Corresponds to a 'new' instruction and <init> method calls*)
    | ArrayCreation of value_type
	(** Corresponds to '*newarray' instructions *)
    | MethodInvocationNonVirtual of class_name * method_signature (* ms ? *)
	(** Corresponds to 'invokestatic', 'invokespecial' or 'invokeinterface' instructions*)
    | MethodInvocationVirtual of object_type * method_signature 
	(** Corresponds to 'invokevirtual' instruction only*)
    | ArrayAccess of value_type option
	(** Corresponds to 'arrayload' instructions with optional exact type of value accessed (not array type!)*)
    | ArrayStore of value_type option
	(** Corresponds to 'arraystore' instructions with type of
	    array, only difference with ArrayAccess is that it will be
	    searched only in left_side of assignements*)
	(*| InfixExpression of infix_operator (* ? => no because we do not know if it appears in source ...*)*)
    | InstanceOf of object_type
	(** Corresponds to 'instanceof' instructions*)
    | Cast of object_type
	(** Corresponds to 'checkcast' instructions*)
  type statement = 
      If
	(** Corresponds to 'if+goto' instructionsIncludes all If 'like' statements (If, For, While, ConditionnalExpr, etc.) *)
    | Catch of class_name (*type given by handlers table*)
	(** Corresponds to handlers entrypoints with a filtered type of exception (not finally clause) *)
    | Finally 
	(** Corresponds to a finally handlers entrypoints *)
    | Switch 
	(** Corresponds to 'tableswitch' and 'lookupswitch' instructions*)
    | Synchronized of bool
	(** Corresponds to 'monitor*' instructions, with true value
	    for 'monitorenter' and false for 'monitorexit'*)
    | Return
	(** Corresponds to 'return' instruction.*)
    | Throw
	(** Corresponds to 'throw' instruction.*)
	(*| AssertStat (*How to find them in bytecode: creation of a field
	  in class + creation of exception to throw*)*)
  type node_unit = 
      Statement of statement 
    | Expression of expression 
    | Name of identifier

end

(** Information on a method signature*)
type method_info = 
  | MethodSignature of string
  | Argument of int * string
  | Return of string
  | This of string

(** Warning on a program point, 2 types are allowed. The type variable
    'a could be used if location of warning is more precise than an
    program point instruction (i.e.: expr in JBir representation).*)
type 'a warning_pp = 
    LineWarning of string * 'a option
      (**warning description * optional precision depending of code
	 representation (used for PreciseLineWarning generation)*)
  | PreciseLineWarning of string * AdaptedASTGrammar.node_unit 
      (** same as LineWarning * AST information *)

(** This type represents warnings and information that will
    be displayed with the Java source code. *)
type 'a plugin_info = 
    {
      p_infos : 
	(string list 
	 * string list FieldMap.t 
	 * method_info list MethodMap.t 
	 * string list Ptmap.t MethodMap.t) 
	ClassMap.t;
      (** infos that could be displayed for a class (one entry in ClassMap.t): 
	  (class_infos * fields_infos * methods_infos * pc_infos)*)

      p_warnings : 
	(string list 
	 * string list FieldMap.t 
	 * method_info list MethodMap.t 
	 * 'a warning_pp list Ptmap.t MethodMap.t) 
	ClassMap.t;
      (** warnings to display for a class (one entry in ClassMap.t): 
	  (class_warnings * fields_warnings * methods_warnings * pc_warnings)*)
    }

(**{3 Utility functions to construct the {!plugin_info} structure}*)

type ('c,'f,'m,'p) info = ('c list 
	     * 'f list FieldMap.t 
	     * 'm list MethodMap.t 
	     * 'p list Ptmap.t MethodMap.t)

val add_class_info : 'c -> class_name -> ('c,'f,'m,'p) info ClassMap.t -> ('c,'f,'m,'p) info ClassMap.t

val add_field_info : 'f -> class_name -> field_signature -> 
  ('c,'f,'m,'p) info ClassMap.t -> ('c,'f,'m,'p) info ClassMap.t

val add_method_info : 'm -> class_name -> method_signature -> 
  ('c,'f,'m,'p) info ClassMap.t -> ('c,'f,'m,'p) info ClassMap.t

val add_pp_info : 'p -> class_name -> method_signature -> int -> 
  ('c,'f,'m,'p) info ClassMap.t -> ('c,'f,'m,'p) info ClassMap.t

(** {2 Building a Printer for any program representation.} *)


module type PrintInterface =
sig

  type instr
  type code

  type expr

  (** [get_source_line_number pc code] returns the source line number corresponding the program point pp of the method code m.*)
  val get_source_line_number : int -> code -> int option

  (*  [iter_code f code] iter on code and apply [f] on [pc instr_list]. *)
  (*val iter_code : (int -> instr list -> unit) -> code Lazy.t -> unit*)

  (** instr -> display * line*)
  val inst_disp : int -> code -> string

  (** Function to provide in order to display the source variable
      names in the method signatures. *)
  val method_param_names : code Javalib.interface_or_class -> method_signature
    -> string list option

  (** Allows to construct detailed warning but it requires good
      knowledge of org.eclipse.jdt.core.dom.AST representation. See
      existant implementation of to_plugin_warning or simply return the same Ptmap.t.
*)    
  val to_plugin_warning : code jmethod ->  expr warning_pp list Ptmap.t 
    -> expr warning_pp list Ptmap.t

end

module type PluginPrinter =
sig
  type code
  type expr

  (** [print_class ?html info ioc outputdir] generates plugin's
      information files for the interface or class [ioc] in the output
      directory [outputdir], given the plugin's information [info]. If
      [html] is given and true then string data in
      {!plugin_info.p_infos} (only) must be valid html (between <div>
      tags). @raise Invalid_argument if the name corresponding to
      [outputdir] is a file.*)
  val print_class: ?html_info:bool -> expr plugin_info -> code interface_or_class -> string -> unit

  (** [print_program ?html info program outputdir] generates plugin's
      information files for the program [p] in the output directory
      [outputdir], given the plugin's information [info]. If [html] is
      given and true then string data in {!plugin_info.p_infos} (only)
      must be valid html (between <div> tags). @raise Invalid_argument
      if the name corresponding to [outputdir] is a file. *)
  val print_program: ?html_info:bool -> expr plugin_info -> code program -> string -> unit
    
end

module Make (S : PrintInterface) : PluginPrinter

(** {2 Built printers for Sawja program representations.} *)

module JCodePrinter : PluginPrinter with type code = JCode.jcode and type expr = unit

module JBirPrinter : PluginPrinter with type code = JBir.t and type expr = JBir.expr

module A3BirPrinter : PluginPrinter with type code = A3Bir.t and type expr = A3Bir.expr

module JBirSSAPrinter : PluginPrinter with type code = JBirSSA.t and type expr = JBirSSA.expr

module A3BirSSAPrinter : PluginPrinter with type code = A3BirSSA.t and type expr = A3BirSSA.expr

