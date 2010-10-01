open Javalib_pack
open JBasics
open JCode 
open Javalib

module Env = struct
  (* lattice of powerset of JBir variables *)
  include Set.Make(struct type t = A3Bir.var let compare = compare end)

  let print_key  = A3Bir.var_name_g

  let bot = empty

  let vars acc = function
    | A3Bir.Const _ -> acc
    | A3Bir.Var (_,x) -> add x acc


  let expr = function
    | A3Bir.BasicExpr e
    | A3Bir.Field (e,_,_) 
    | A3Bir.Unop (_,e) -> vars empty e
    | A3Bir.Binop (_,e1,e2) -> vars (vars empty e1) e2
    | A3Bir.StaticField _ -> empty

  (* [vars e] computes the set of variables that appear in expression [e]. *)
  let vars = vars empty

  let to_string ab =
    let ab = elements ab in
      match List.map print_key ab with
	| [] -> "{}"
	| [x] -> Printf.sprintf "{%s}" x
	| x::q -> Printf.sprintf "{%s%s}" x (List.fold_right (fun x s -> ","^x^s) q "")	 
end
  
type transfer_fun =
  | GenVars of A3Bir.basic_expr list 
     (* [GenVars l] : generate the set of variables that appear in some expressions in list [l] *)
  | GenVarsExpr of A3Bir.expr list
  | Kill of A3Bir.var
     (* [Kill x] : remove variable [x] *)
      
type transfer = transfer_fun list
type pc = int

let fun_to_string = function
  | GenVars e ->
      Printf.sprintf "GenVars(%s)" (String.concat "::" (List.map A3Bir.print_basic_expr e))
  | GenVarsExpr e ->
      Printf.sprintf "GenVars(%s)" (String.concat "::" (List.map A3Bir.print_expr e))
  | Kill x ->
      Printf.sprintf "Kill(%s)" (A3Bir.var_name_g x)

let transfer_to_string = function
  | [] -> ""
  | [f] -> fun_to_string f
  | f::q -> (fun_to_string f)^(List.fold_right (fun f s -> ";"^(fun_to_string f)^s) q "")
      
let eval_transfer = function
  | GenVars l -> (fun ab -> List.fold_right (fun e -> Env.union (Env.vars e)) l ab)
  | GenVarsExpr l -> (fun ab -> List.fold_right (fun e -> Env.union (Env.expr e)) l ab)
  | Kill x -> fun ab -> Env.remove x ab

(* [gen_instrs last i] computes a list of transfert function
   [(f,j);...] with [j] the successor of [i] for the transfert
   function [f]. [last] is the end label of the method; *)
let gen_instrs last i = 
  function
  | A3Bir.Ifd ((_,e1,e2), j) -> 
      let gen = GenVars [e1;e2] in [([gen],j);([gen],i+1)]
  | A3Bir.Goto j -> [[],j]
  | A3Bir.Throw _
  | A3Bir.Return None  -> []
  | A3Bir.Return (Some e)  ->  [[GenVars [e]],last]
  | A3Bir.AffectVar (x,e) -> [[GenVarsExpr [e]; Kill x],i+1]
  | A3Bir.NewArray (x,_,le)
  | A3Bir.New (x,_,_,le) 
  | A3Bir.InvokeStatic (Some x,_,_,le) ->  [[GenVars le;Kill x],i+1]
  | A3Bir.InvokeVirtual (Some x,e,_,_,le) 
  | A3Bir.InvokeNonVirtual (Some x,e,_,_,le) -> [[GenVars (e::le); Kill x],i+1]
  | A3Bir.MonitorEnter e 
  | A3Bir.MonitorExit e -> [[GenVars [e]],i+1]
  | A3Bir.AffectStaticField (_,_,e) -> [[GenVarsExpr [e]],i+1]
  | A3Bir.AffectField (e1,_,_,e2) -> [[GenVars [e1;e2]],i+1]
  | A3Bir.AffectArray (e1,e2,e3) -> [[GenVars [e1;e2;e3]],i+1]
  | A3Bir.InvokeStatic (None,_,_,le) -> [[GenVars le],i+1]
  | A3Bir.InvokeVirtual (None,e,_,_,le) 
  | A3Bir.InvokeNonVirtual (None,e,_,_,le) -> [[GenVars (e::le)],i+1]
  | A3Bir.MayInit _ 
  | A3Bir.Nop -> [[],i+1]
  | A3Bir.Check c -> begin
      match c with
	| A3Bir.CheckArrayBound (e1,e2)
	| A3Bir.CheckArrayStore (e1,e2) -> [[GenVars [e1;e2]],i+1]
	| A3Bir.CheckNullPointer e
	| A3Bir.CheckNegativeArraySize e
	| A3Bir.CheckCast (e,_)
	| A3Bir.CheckArithmetic e -> [[GenVars [e]],i+1]
	| A3Bir.CheckLink _ -> [[],i+1]
    end

(* generate a list of transfer functions *)
let gen_symbolic (m:A3Bir.t) : (pc * transfer * pc) list = 
  let length = Array.length m.A3Bir.code in
    JUtil.foldi 
      (fun i ins l ->
	 List.rev_append
	   (List.map (fun (c,j) -> (j,c,i)) (gen_instrs length i ins))
	   l) 
      (List.map (fun (i,e) -> (e.A3Bir.e_handler,[],i)) (A3Bir.exception_edges m))
      m.A3Bir.code

let run m =
  Iter.run 
    {
      Iter.bot = Env.bot ;
      Iter.join = Env.union;
      Iter.leq = Env.subset;
      Iter.eval = List.fold_right eval_transfer;
      Iter.normalize = (fun x -> x);
      Iter.size = 1 + Array.length m.A3Bir.code;
      Iter.workset_strategy = Iter.Decr;
      Iter.cstrs = gen_symbolic m;
      Iter.init_points = [Array.length m.A3Bir.code];
      Iter.init_value = (fun _ -> Env.empty); (* useless here since we iterate from bottom *)
      Iter.verbose = false;
      Iter.dom_to_string = Env.to_string;
      Iter.transfer_to_string = transfer_to_string
    }


let to_string = Env.to_string