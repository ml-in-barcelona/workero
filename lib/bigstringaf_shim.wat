(module
   (import "env" "caml_bigstring_blit_ba_to_bytes"
      (func $caml_bigstring_blit_ba_to_bytes (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (result (ref eq))))
   (import "env" "caml_bigstring_blit_ba_to_ba"
      (func $caml_bigstring_blit_ba_to_ba (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (result (ref eq))))
   (import "env" "caml_bigstring_blit_string_to_ba"
      (func $caml_bigstring_blit_string_to_ba (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (result (ref eq))))
   (import "env" "caml_bigstring_memcmp"
      (func $caml_bigstring_memcmp (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (result (ref eq))))
   (import "env" "caml_bigstring_memcmp_string"
      (func $caml_bigstring_memcmp_string (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (result (ref eq))))
   (import "env" "caml_bigstring_memchr"
      (func $caml_bigstring_memchr (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (result (ref eq))))
   (func (export "bigstringaf_blit_to_bytes")
      (param $a (ref eq)) (param $b (ref eq)) (param $c (ref eq)) (param $d (ref eq)) (param $e (ref eq)) (result (ref eq))
      (return_call $caml_bigstring_blit_ba_to_bytes (local.get $a) (local.get $b) (local.get $c) (local.get $d) (local.get $e)))
   (func (export "bigstringaf_blit_to_bigstring")
      (param $a (ref eq)) (param $b (ref eq)) (param $c (ref eq)) (param $d (ref eq)) (param $e (ref eq)) (result (ref eq))
      (return_call $caml_bigstring_blit_ba_to_ba (local.get $a) (local.get $b) (local.get $c) (local.get $d) (local.get $e)))
   (func (export "bigstringaf_blit_from_bytes")
      (param $a (ref eq)) (param $b (ref eq)) (param $c (ref eq)) (param $d (ref eq)) (param $e (ref eq)) (result (ref eq))
      (return_call $caml_bigstring_blit_string_to_ba (local.get $a) (local.get $b) (local.get $c) (local.get $d) (local.get $e)))
   (func (export "bigstringaf_memcmp_bigstring")
      (param $a (ref eq)) (param $b (ref eq)) (param $c (ref eq)) (param $d (ref eq)) (param $e (ref eq)) (result (ref eq))
      (return_call $caml_bigstring_memcmp (local.get $a) (local.get $b) (local.get $c) (local.get $d) (local.get $e)))
   (func (export "bigstringaf_memcmp_string")
      (param $a (ref eq)) (param $b (ref eq)) (param $c (ref eq)) (param $d (ref eq)) (param $e (ref eq)) (result (ref eq))
      (return_call $caml_bigstring_memcmp_string (local.get $a) (local.get $b) (local.get $c) (local.get $d) (local.get $e)))
   (func (export "bigstringaf_memchr")
      (param $s (ref eq)) (param $pos (ref eq)) (param $c (ref eq)) (param $len (ref eq)) (result (ref eq))
      (return_call $caml_bigstring_memchr (local.get $s) (local.get $c) (local.get $pos) (local.get $len)))
)
