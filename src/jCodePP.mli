open Javalib_pack
open JBasics
open Javalib
open JProgram
open JControlFlow
open JCode

type t

val get_class : t -> jcode node

val get_meth : t -> jcode concrete_method

val get_pc : t -> int

val get_pp : jcode node -> jcode concrete_method -> int -> t

(** [get_first_pp p cn ms] gets a pointer to the first instruction
    of the method [ms] of the class [cn].

    @raise Not_found if [cn] is not a class of [p], or [ms] is not a
    method of [cn].

    @raise NoCode if the method [ms] has no associated code.*)
val get_first_pp : jcode program -> class_name -> method_signature -> t

(** [get_first_pp_wp n ms] gets a pointer to the first instruction
    of the method [ms] of the node [n].

    @raise NoCode if the method [ms] has no associated code.*)
val get_first_pp_wp : jcode node -> method_signature -> t

(** get internal representation. *)
val get_ir : t -> jcode

val get_opcode : t -> jopcode 

(** [goto_absolute pp i]: return the program pointer at instruction [i] in
   the method of program pointer [pp].*)
val goto_absolute : t -> int -> t

(** [goto_relative pp i]: return the program pointer at instruction [i'+i]
    (with i' the current program point of pp)in the method of program pointer
    [pp].*)
val goto_relative : t -> int -> t

val equal : t -> t -> bool

val compare : t ->  t -> int

val hash : t -> int

(** get the instruction at the next program point (do not follow control
  flow). *)
val next_instruction: t ->  t

(**[static_pp_lookup program pp]: Return a list of method entries which can be
  reached by a call from the current program pointer. It returns fully
  implemented methods pp only. The computation is based on the RTA or CRA 
  result (depending on the one used to build the program).*)
val static_pp_lookup : jcode program -> t -> t list

(**[static_lookup program pp]: Return a list of class in which a method called
* from [pp] might be defined. None means that [pp] does not contains an
  instruction which can lead to a method call. *)
val static_lookup : jcode program -> t -> jcode node list option

(** [handlers pp] returns the list of exception handlers which can be raised at
  program point [pp]. This is a surapproximation.*)
val handlers : t -> exception_handler list

(** Return the list of possible successors.*)
val normal_successors : t -> t list 

(** Return the list of possible exceptionnal successors.*)
val exceptional_successors : t -> t list

val to_string : t -> string

val pprint : Format.formatter -> t -> unit

(** [get_successors program cl meth] returns the possible methods
  that may be invoked from the current program point (it uses
  [static_lookup'] function).  For the static initialization,
  only the topmost class initializer is returned (and the successors
  of a clinit methods includes the clinit methods that are
  beneath). *)
val get_successors : jcode program -> jcode node -> jcode concrete_method -> ClassMethodSet.t
