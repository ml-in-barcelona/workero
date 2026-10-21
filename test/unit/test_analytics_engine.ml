open Helpers
module Analytics_engine = Workero.Analytics_engine

let recorder =
  js_eval
    {|({
        points: [],
        writeDataPoint(point) {
          this.points.push({
            keys: Object.keys(point),
            indexes: point.indexes,
            doubles: point.doubles,
            blobs: point.blobs.map((b) =>
              typeof b === "string" ? b : { buffer: b instanceof ArrayBuffer, bytes: [...new Uint8Array(b)] }),
          });
        },
      })|}

let dataset () =
  let env = Workero.Env.of_js (obj [| ("DATA", recorder) |]) in
  Analytics_engine.of_env env "DATA"

let points () =
  Js_of_ocaml.Js.to_string
    (Js_of_ocaml.Js.Unsafe.fun_call
       (js_eval "(r => JSON.stringify(r.points))")
       [| recorder |])

let test_of_env () =
  let env =
    Workero.Env.of_js (obj [| ("DATA", recorder); ("TEXT", jstr "plain") |])
  in
  ignore (Analytics_engine.of_env env "DATA");
  Alcotest.check_raises "missing"
    (Invalid_argument
       "Workero.Analytics_engine.of_env: binding \"NOPE\" not found") (fun () ->
      ignore (Analytics_engine.of_env env "NOPE"));
  Alcotest.check_raises "a variable"
    (Invalid_argument
       "Workero.Analytics_engine.of_env: binding \"TEXT\" is a string, not an \
        Analytics Engine dataset") (fun () ->
      ignore (Analytics_engine.of_env env "TEXT"))

let test_write () =
  let d = dataset () in
  Analytics_engine.write ~index:"user" ~doubles:[ 1.5; -2.; 3. ]
    ~blobs:[ Text "page"; Bytes "\x00\xff" ]
    d;
  Analytics_engine.write d;
  Analytics_engine.write ~index:"only" d;
  Alcotest.(check string)
    "points"
    ({|[{"keys":["indexes","doubles","blobs"],"indexes":["user"],"doubles":[1.5,-2,3],"blobs":["page",{"buffer":true,"bytes":[0,255]}]},|}
   ^ {|{"keys":["doubles","blobs"],"doubles":[],"blobs":[]},|}
   ^ {|{"keys":["indexes","doubles","blobs"],"indexes":["only"],"doubles":[],"blobs":[]}]|}
    )
    (points ())

let test_write_throws () =
  let env =
    Workero.Env.of_js
      (obj
         [|
           ("DATA", js_eval "({ writeDataPoint() { throw new Error('x'); } })");
         |])
  in
  raises_js_error "write" (fun () ->
      Analytics_engine.write (Analytics_engine.of_env env "DATA"))

let () =
  Alcotest.run "workero.analytics_engine"
    [
      ( "analytics_engine",
        [
          Alcotest.test_case "of_env" `Quick test_of_env;
          Alcotest.test_case "write" `Quick test_write;
          Alcotest.test_case "write throws" `Quick test_write_throws;
        ] );
    ]
