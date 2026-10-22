# workero template

This directory is a Cloudflare Worker project written in OCaml. Copy it
outside the workero source checkout so Dune treats the copy as its own project.
You need an active OCaml 5.4 or later opam switch, Node.js and npm. Install
workero from a source clone before you run the copy:

```sh
eval "$(opam env)"
git clone https://github.com/ml-in-barcelona/workero.git workero-source
opam pin add workero ./workero-source -y
cp -R workero-source/template my-worker
cd my-worker
npm install
npx wrangler dev
```

In another terminal, run `curl http://127.0.0.1:8787/`. Expect
`Hello from OCaml on Cloudflare Workers`. `POST /echo` returns the request
body. `GET /env` returns `hello from vars` from `[vars]` in `wrangler.toml`.
You do not need a Cloudflare account for local development. See the
[getting started guide](https://ml-in-barcelona.github.io/workero/workero/getting_started.html)
for editing and deployment.
