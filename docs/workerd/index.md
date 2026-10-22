
# workerd

workerd is the runtime that runs Cloudflare Workers. This opam package installs the prebuilt `workerd` binary from Cloudflare. It does not build workerd from source, because the workerd build needs Bazel.


## Install

```
opam install workerd
```
The `workerd` package depends on one binary package for your platform.

- `workerd-linux-64`: Linux x86\_64.
- `workerd-linux-arm64`: Linux arm64.
- `workerd-darwin-64`: macOS x86\_64.
- `workerd-darwin-arm64`: macOS arm64.
Linux needs glibc 2\.35 or later. Windows is not supported.

Check the install:

```
workerd --version
```

## Why there are five packages

opam can select a download for one platform only with a package, not with a filter on a download. Each platform has its own package. The `workerd` package has no files; it selects the right one. Install `workerd`, not the platform packages.


## Versions

The version of the opam package is the version of the npm package `workerd`, for example `1.20261019.1`. The date in the version is the workerd release date. The file `CHANGES.md` in the `workerd` directory of the repository lists the releases.

The package `wrangler` needs the exact workerd version that its npm package pins. For this reason, you may need an older workerd than the latest one.


## Use with workero

The workero tests run Workers in `workerd`. They need `workerd` on `PATH`.


## Source of the binaries

Each platform package downloads one tarball from the npm registry, from the package `@cloudflare/workerd-<platform>`. opam checks its SHA-512 sum. The package copies `bin/workerd` to the `bin` directory of the switch.


## Release

The maintainers release `workerd` separately from `workero`. Tag `workerd-<version>` starts the release. See `CONTRIBUTING.md` in the repository.
