# workero template

This directory is a Cloudflare Worker project written in OCaml. Copy it to a
directory outside the workero source checkout before running Dune or Wrangler.

With an active opam switch running OCaml 5.4 or later, Node.js 22 or later,
and Git installed, start from a directory outside any Dune project:

```sh
eval "$(opam env)"
git clone https://github.com/ml-in-barcelona/workero.git workero-source
opam pin add workero ./workero-source -y
cp -R workero-source/template my-worker
cd my-worker
npm install
npx wrangler dev
```

The source pin installs the `workero` CLI and library; the package is not yet
on the opam package index. `npm install` installs Wrangler and binaryen. The
server prints a local URL, usually `http://127.0.0.1:8787`. In another
terminal, check the routes:

```sh
curl http://127.0.0.1:8787/
curl -d ping http://127.0.0.1:8787/echo
curl http://127.0.0.1:8787/env
```

Expected responses are `Hello from OCaml on Cloudflare Workers`, `ping`, and
`hello from vars`, respectively. Edit `src/main.ml` and check the local
server again. The `GREETING` variable comes from `[vars]` in `wrangler.toml`.

To publish, sign in to a Cloudflare account and deploy from `my-worker`:

```sh
npx wrangler login
npx wrangler deploy
```

Wrangler prints the deployed URL. Login is not needed for local development.
For the complete path, see the
[getting started guide](https://ml-in-barcelona.github.io/workero/workero/getting_started.html).
