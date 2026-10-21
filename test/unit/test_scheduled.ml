open Helpers

let test_scheduled () =
  let c =
    Workero.Scheduled.of_js
      (obj [| ("cron", jstr "*/5 * * * *"); ("scheduledTime", inject 1.7e12) |])
  in
  Alcotest.(check string) "cron" "*/5 * * * *" (Workero.Scheduled.cron c);
  Alcotest.(check (float 0.)) "time" 1.7e12 (Workero.Scheduled.scheduled_time c);
  let empty = Workero.Scheduled.of_js (obj [||]) in
  Alcotest.(check string) "no cron" "" (Workero.Scheduled.cron empty);
  Alcotest.(check (float 0.))
    "no time" 0.
    (Workero.Scheduled.scheduled_time empty)

let () =
  Alcotest.run "workero.scheduled"
    [ ("scheduled", [ Alcotest.test_case "fields" `Quick test_scheduled ]) ]
