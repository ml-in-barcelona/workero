
# Module `Container.Snapshot`

```ocaml
type t = {
  id : string;
  size : int;
  name : string option;
}
```
A snapshot of the whole container. `size` is in bytes.
