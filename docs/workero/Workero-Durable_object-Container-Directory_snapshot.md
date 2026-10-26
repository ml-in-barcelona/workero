
# Module `Container.Directory_snapshot`

```ocaml
type t = {
  id : string;
  size : int;
  dir : string;
  name : string option;
}
```
A snapshot of one directory of the container, taken at `dir`. `size` is in bytes.

```ocaml
type restore = {
  snapshot : t;
  mount_point : string option;
}
```
Restores `snapshot` at `mount_point`, or at `snapshot.dir` when `mount_point` is `None`.
