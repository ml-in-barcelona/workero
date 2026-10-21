
# Module `Workero.Crypto`

The Web Crypto random functions of the global `crypto` object.

```ocaml
val random_uuid : unit -> string
```
`crypto.randomUUID()`: a random version 4 UUID, for example `"1b4e28ba-2fa1-41d2-883f-0016d3cca427"`.

```ocaml
val random_bytes : int -> string
```
`random_bytes n` is `n` cryptographically random bytes, from `crypto.getRandomValues`.

Raises `Invalid_argument` when `n` is negative or more than 65536, the limit of `getRandomValues`.
