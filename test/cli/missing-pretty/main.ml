external missing_one : int -> int = "workero_test_missing_one"
external missing_two : int -> int = "workero_test_missing_two"

let () = print_int (missing_one 1 + missing_two 2)
