open Js_of_ocaml
open Js

let log ?(meth="GET") url = function
  | None -> ()
  | Some msg ->
    Firebug.console##log (string ("[>" ^ msg ^ " " ^ meth ^ " " ^ url ^ "]"))

let make ?msg ?content ?content_type ~meth ~headers url f =
  log ~meth url msg;
  if !Verbose.v land 2 <> 0 then Format.printf "[ez_api] sent:\n%s@." (Option.value ~default:"" content);
  let xhr = XmlHttpRequest.create () in
  xhr##_open (string meth) (string url) _true ;
  Option.iter (fun ct -> xhr##setRequestHeader (string "Content-Type") (string ct)) content_type;
  List.iter (fun (name, value) ->  xhr##setRequestHeader (string name) (string value)) headers;
  xhr##.onreadystatechange :=
    wrap_callback (fun _ ->
        if xhr##.readyState = XmlHttpRequest.DONE then
          let status = xhr##.status in
          log ~meth:("RECV " ^ string_of_int status) url msg;
          let res = Opt.case xhr##.responseText (fun () -> "") to_string in
          if !Verbose.v land 1 <> 0 then Format.printf "[ez_api] received:\n%s@." res;
          if status >= 200 && status < 300 then f @@ Ok res
          else
            f @@ Result.error @@ (status, if res = "" then None else Some res));
  xhr##send (Opt.option (Option.map string content))

module Interface = struct
  let get ?(meth="GET") ?(headers=[]) ?msg url f =
    make ?msg ~meth ~headers url f

  let post ?(meth="POST") ?(content_type="application/json") ?(content="{}")
      ?(headers=[]) ?msg url f =
    make ?msg ~content ~content_type ~meth ~headers url f
end

include EzRequest.Make(Interface)

let () =
  Unsafe.global##.set_verbose_ := wrap_callback Verbose.set_verbose;
  EzDebug.log "ezXhr Loaded"
