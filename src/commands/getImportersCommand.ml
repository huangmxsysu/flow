(**
 * Copyright (c) 2014, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "flow" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

(***********************************************************************)
(* flow get importers command *)
(***********************************************************************)

open CommandUtils

let spec = {
  CommandSpec.
  name = "get-importers";
  doc = "Gets a list of all importers for one or more given modules";
  usage = Printf.sprintf
    "Usage: %s get-importers [OPTION]... [FILE]...\n\n\
      Gets a list of all importers for one or more given modules\n\n\
      Example usage:\n\
      \t%s get-importers FirstModule SecondModule\n"
      CommandUtils.exe_name
      CommandUtils.exe_name;
  args = CommandSpec.ArgSpec.(
    empty
    |> server_flags
    |> root_flag
    |> json_flags
    |> anon "modules" (required (list_of string))
        ~doc:"Module name(s) to find"
  )
}

let main option_values root json modules () =
  let root = guess_root root in

  let ic, oc = connect option_values root in

  ServerProt.cmd_to_channel oc (ServerProt.GET_IMPORTERS modules);
  let importers_map = Marshal.from_channel ic in
  if json
  then (
    let json_list =
      Utils.SMap.fold (fun module_name importers json_list ->
        let importer_list = List.map (fun entry ->
          Hh_json.JSON_String entry
        ) (Utils.SSet.elements importers) in
        (module_name, Hh_json.JSON_Array importer_list) :: json_list
      ) importers_map [] in
    let json_output = Hh_json.JSON_Object json_list in
    output_string stdout (Hh_json.json_to_string json_output);
    flush stdout
  ) else (
    List.iter (fun module_name ->
      if (Utils.SMap.mem module_name importers_map)
      then begin
        let import_files =
          Utils.SMap.find_unsafe module_name importers_map in
        Printf.printf "Modules importing module '%s':\n" module_name;
        Utils.SSet.iter (fun file ->
          Printf.printf "\t%s\n" file
        ) import_files
      end else
        Printf.printf "Module '%s' could not be found!\n" module_name
    ) modules;
    flush stdout
  )

let command = CommandSpec.command spec main
