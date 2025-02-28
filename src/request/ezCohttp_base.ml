open Lwt.Infix

let meth_of_str = function
  | "GET" -> `GET
  | "HEAD" -> `HEAD
  | "PUT" -> `PUT
  | "POST" -> `POST
  | "CONNECT" -> `CONNECT
  | "PATCH" -> `PATCH
  | "TRACE" -> `TRACE
  | "DELETE" -> `DELETE
  | "OPTIONS" -> `OPTIONS
  | s -> `Other s

let log ?(meth="GET") url = function
  | None -> ()
  | Some msg -> Printf.printf "[>%s %s %s ]\n%!" msg meth url

module Make(Client:Cohttp_lwt.S.Client) = struct

  let make ?msg ?content ?content_type ~meth ~headers url =
    log ~meth url msg;
    if !Verbose.v land 2 <> 0 then Format.printf "[ez_api] sent:\n%s@." (Option.value ~default:"" content);
    let r () =
      let body = Option.map Cohttp_lwt.Body.of_string content in
      let headers = Option.fold ~none:Cohttp.Header.(add_list (init ()) headers)
          ~some:(fun ct -> Cohttp.Header.(add_list (init_with "Content-Type" ct) headers))
          content_type in
      Client.call ?body ~headers (meth_of_str meth)
        (Uri.of_string url) >>= fun (resp, body) ->
      let code = resp |> Cohttp.Response.status |> Cohttp.Code.code_of_status in
      Cohttp_lwt.Body.to_string body >|= fun body ->
      log ~meth:("RECV " ^ string_of_int code) url msg;
      if !Verbose.v land 1 <> 0 then Format.printf "[ez_api] received:\n%s@." body;
      if code >= 200 && code < 300 then Ok body
      else Error (code, Some body)
    in
    Lwt.catch r (fun exn -> Lwt.return (Error (-1, Some (Printexc.to_string exn))))


  let get ?(meth="GET") ?(headers=[]) ?msg url =
    make ?msg ~meth ~headers url

  let post ?(meth="POST") ?(content_type = "application/json") ?(content="{}") ?(headers=[])
      ?msg url =
    make ?msg ~content ~content_type ~meth ~headers url
end
