(*
 * Copyright (c) 2013 Richard Mortier <mort@cantab.net>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

open Mirage_types.V1
open Lwt

let sp = Printf.sprintf

module Main
  (C: CONSOLE) (ASSETS: KV_RO) (SLIDES: KV_RO) (S: Cohttp_lwt.Server) =
struct

  let start c assets slides http =
    let read_assets name =
      ASSETS.size assets name >>= function
      | `Error (ASSETS.Unknown_key _) ->
        fail (Failure ("read_assets_size " ^ name))
      | `Ok size ->
        ASSETS.read assets name 0 (Int64.to_int size) >>= function
        | `Error (ASSETS.Unknown_key _) ->
          fail (Failure ("read_assets " ^ name))
        | `Ok bufs -> return (Cstruct.copyv bufs)
    in

    let read_slides name =
      SLIDES.size slides name >>= function
      | `Error (SLIDES.Unknown_key _) ->
        fail (Failure ("read_slides_size " ^ name))
      | `Ok size ->
        SLIDES.read slides name 0 (Int64.to_int size) >>= function
        | `Error (SLIDES.Unknown_key _) ->
          fail (Failure ("read_slides " ^ name))
        | `Ok bufs -> return (Cstruct.copyv bufs)
    in

    let callback conn_id ?body req =
      let path = Uri.path (S.Request.uri req) in
      let path_elem =
        let rec remove_empty_tail = function
          | [] | [""] -> []
          | hd::tl    -> hd :: remove_empty_tail tl
        in
        remove_empty_tail (Re_str.(split_delim (regexp_string "/") path))
      in
      C.log_s c (sp "URL: '%s'" path)
      >> try_lwt
        read_assets path >>= fun body ->
        S.respond_string ~status:`OK ~body ()
      with
      | Failure m ->
        Printf.printf "EXN: '%s'%!" m;
        Slides.dispatch read_slides req path_elem
    in

    let conn_closed conn_id () =
      (* XXX shouldn't i be able to use the Console logging here?
            C.log_s c (sp "conn %s closed\n%!" (Cohttp.Connection.to_string conn_id))
      *)
      Printf.printf "conn %s closed\n%!" (Cohttp.Connection.to_string conn_id)
    in

    let spec = {
      S.callback;
      conn_closed;
    } in
    http spec

end
