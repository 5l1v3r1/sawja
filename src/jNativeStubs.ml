(*
 * This file is part of SAWJA
 * Copyright (c)2007, 2008 Tiphaine Turpin (Université de Rennes 1)
 * Copyright (c)2007, 2008, 2009 Laurent Hubert (CNRS)
 * Copyright (c)2009 Nicolas Barre (INRIA)
 *
 * This program is free software: you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program.  If not, see
 * <http://www.gnu.org/licenses/>.
 *)

type jmethod = { m_type : string;
		 m_class : string;
		 m_name : string;
		 m_signature : string
	       }

let jmethod_compare m1 m2 =
  if (m1.m_type = m2.m_type) then
    if (m1.m_class = m2.m_class) then
      if (m1.m_name = m2.m_name) then
	if (m1.m_signature = m2.m_signature) then 0
	else compare m1.m_signature m2.m_signature
      else compare m1.m_name m2.m_name
    else compare m1.m_class m2.m_class
  else compare m1.m_type m2.m_type

module ClassSignatureSet = Set.Make(
  struct
    type t = string
    let compare = compare
  end)

module MethodSet = Set.Make(
  struct
    type t = jmethod
    let compare = jmethod_compare
  end)

module MethodMap = Map.Make(
  struct
    type t = jmethod
    let compare = jmethod_compare
  end)

module StringMap = Map.Make(
  struct
    type t = string
    let compare = compare
  end)

type native_method_info = { native_alloc : ClassSignatureSet.t;
			    native_calls : MethodSet.t }

type native_info = native_method_info MethodMap.t

let indent_size = 4
let indent = String.make indent_size ' '

let string_of_method jmethod =
  "Method{type=\"" ^ jmethod.m_type
  ^ "\" class=\"" ^ jmethod.m_class
  ^ "\" name=\"" ^ jmethod.m_name
  ^ "\" signature=\"" ^ jmethod.m_signature ^ "\"}"

let fprint_native_info native_info file =
  let oc = open_out file in
    MethodMap.iter
      (fun jmethod meth_info ->
	 Printf.fprintf oc "%s{\n" (string_of_method jmethod);
	 if (meth_info.native_alloc <> ClassSignatureSet.empty) then
	   begin
	     Printf.fprintf oc "%sVMAlloc{\n%s" indent (indent ^ indent);
	     Printf.fprintf oc "%s"
	       (String.concat ("\n" ^ indent ^ indent)
		  (List.map
		     (fun x -> "\"" ^ x ^ "\"")
		     (ClassSignatureSet.elements meth_info.native_alloc)));
	     Printf.fprintf oc "\n%s}\n" indent;
	   end;
	 if (meth_info.native_calls <> MethodSet.empty) then
	   begin
	     Printf.fprintf oc "%sInvokes{\n%s" indent (indent ^ indent);
	     Printf.fprintf oc "%s"
	       (String.concat ("\n" ^ indent ^ indent)
		  (List.map (fun jmeth -> string_of_method jmeth)
		     (MethodSet.elements meth_info.native_calls)));
	     Printf.fprintf oc "\n%s}\n" indent;
	   end;
	 Printf.fprintf oc "}\n\n";
      ) native_info;
    close_out oc

type t = native_info
let make_t x = x

let empty_info = MethodMap.empty

let get_native_methods info =
  let methods = ref [] in
    MethodMap.iter
      (fun jmethod _ ->
	 if (jmethod.m_type = "Native") then
	   methods := (jmethod.m_class,jmethod.m_name,jmethod.m_signature)
	   :: !methods) info;
    List.rev !methods

let get_native_method_allocations (m_class,m_name,m_signature) info =
  let native_alloc =
    (MethodMap.find { m_type = "Native";
		      m_class = m_class;
		      m_name = m_name;
		      m_signature = m_signature } info).native_alloc in
    ClassSignatureSet.elements native_alloc

let get_native_method_calls (m_class,m_name,m_signature) info =
  let native_calls =
    (MethodMap.find { m_type = "Native";
		      m_class = m_class;
		      m_name = m_name;
		      m_signature = m_signature } info).native_calls in
    List.map (fun jmethod ->
		(jmethod.m_class,jmethod.m_name,jmethod.m_signature)
	     ) (MethodSet.elements native_calls)

let merge_native_info info1 info2 =
  MethodMap.fold
    (fun jmeth methinfo1 native_info ->
       if (MethodMap.mem jmeth native_info) then
	 let methinfo2 = MethodMap.find jmeth native_info in
	 let new_methinfo =
	   { native_alloc = ClassSignatureSet.union
	       methinfo1.native_alloc methinfo2.native_alloc;
	     native_calls = MethodSet.union
	       methinfo1.native_calls methinfo2.native_calls } in
	   MethodMap.add jmeth new_methinfo native_info
       else
	 MethodMap.add jmeth methinfo1 native_info) info1 info2
