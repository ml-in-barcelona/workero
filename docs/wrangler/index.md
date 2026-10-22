
# wrangler

Wrangler is the Cloudflare command line tool. It runs a Worker on your machine, and it deploys a Worker. This opam package installs Wrangler without `npm install`.


## Install

```
opam install wrangler
```
The package installs the `wrangler` command and the `workerd` package. Wrangler needs Node.js 22 or later. The package `conf-npm` checks that `npm` is on your system, but it does not check the Node.js version. The install fails with a message when Node.js is older than 22\.

Check the install:

```
wrangler --version
```

## What the package contains

The package contains a bundle of Wrangler and its JavaScript dependencies. The release job of the repository builds the bundle with `npm install` and attaches it to the GitHub release. opam downloads this file, and no `npm` command runs when you install.

The bundle has these differences from `npm install wrangler`:

- It has no `workerd` binary. The `workerd` opam package provides it. The install links the binary into the place where Wrangler looks for it. The workerd version is the version that Wrangler pins.
- It has the `esbuild` binaries for Linux and macOS, x86\_64 and arm64.
- It has no `sharp` binaries. Local development of the Images binding does not work.

## Versions

The version of the opam package is the version of the npm package `wrangler`, for example `4.151.3`. The file `CHANGES-wrangler.md` in the repository lists the releases.


## Use with workero

A workero project can use `wrangler dev` and `wrangler deploy` with the `wrangler` command from opam. The template in the workero repository lists `wrangler` in its `package.json`; with this package you can remove it.


## Release

A CI job checks the npm registry every day. For a new `wrangler` version, it releases the package without manual steps: the tag is `wrangler-<version>`. It waits until the tag of the workerd version that `wrangler` pins exists. See `CONTRIBUTING.md` in the repository.
