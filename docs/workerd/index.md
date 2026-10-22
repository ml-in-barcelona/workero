
# workerd

workerd is the runtime that runs Cloudflare Workers. This opam package installs the prebuilt `workerd` binary from Cloudflare. It does not build workerd from source, because the workerd build needs Bazel.


## Install

```
opam install workerd
```
opam downloads the binaries for all four platforms (Linux and macOS, x86\_64 and arm64), about 154 MiB, and installs the one for your system.

Linux needs glibc 2\.35 or later. Windows is not supported.

Check the install:

```
workerd --version
```

## Why opam downloads four files

opam cannot select a download by platform. The `url` and `extra-source` fields have no filter. For this reason, the package lists the four npm tarballs, and a filtered command unpacks the one that fits your `os` and `arch`. The `workerd` package installs a single file, `bin/workerd`.


## Versions

The version of the opam package is the version of the npm package `workerd`, for example `1.20261019.1`. The date in the version is the workerd release date. The file `CHANGES-workerd.md` in the repository lists the releases.

The package `wrangler` needs the exact workerd version that its npm package pins. For this reason, you may need an older workerd than the latest one.


## Use with workero

The workero tests run Workers in `workerd`. They need `workerd` on `PATH`.


## Source of the binaries

The package downloads four tarballs from the npm registry, from the packages `@cloudflare/workerd-<platform>`. opam checks the SHA-512 sum of each one. The install copies `bin/workerd` to the `bin` directory of the switch.


## Release

A CI job checks the npm registry every day. It releases the `workerd` version that the latest `wrangler` pins, without manual steps: the tag is `workerd-<version>`. Other `workerd` versions are not released. See `CONTRIBUTING.md` in the repository.
