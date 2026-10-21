let js_global name = Js_of_ocaml.Js.Unsafe.get Js_of_ocaml.Js.Unsafe.global name

let js_new name args =
  Js_of_ocaml.Js.Unsafe.new_obj (js_global name) (Array.of_list args)

let inject = Js_of_ocaml.Js.Unsafe.inject
let jstr s = inject (Js_of_ocaml.Js.string s)
let obj = Js_of_ocaml.Js.Unsafe.obj
let js_eval src = Js_of_ocaml.Js.Unsafe.eval_string src

let request ?(init = []) url =
  Workero.Request.of_js
    (js_new "Request" [ jstr url; obj (Array.of_list init) ])

let method_t =
  Alcotest.testable
    (fun ppf m -> Format.pp_print_string ppf (Workero.Method.to_string m))
    ( = )

let js_instance_of v name =
  Js_of_ocaml.Js.to_bool
    (Js_of_ocaml.Js.Unsafe.fun_call
       (js_eval "(function (v, c) { return v instanceof globalThis[c]; })")
       [| v; jstr name |])

let raises_js_error name f =
  match f () with
  | _ -> Alcotest.failf "%s: no exception" name
  | exception Workero.Js_error _ -> ()
