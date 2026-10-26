
# Module `Crypto.Digest_stream`

```ocaml
type t
```
The runtime `DigestStream`: a writable stream that hashes what you write to it, without keeping the data.

```ocaml
val create : hash -> t
```
```ocaml
val writer : t -> Stream.Writer.t
```
Locks the stream. Write the data, then [`Stream.Writer.close`](./Workero-Stream-Writer.md#val-close).

```ocaml
val digest : t -> string
```
The raw digest. Suspends until the writer is closed.
