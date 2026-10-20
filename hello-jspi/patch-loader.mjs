import { readFileSync, writeFileSync } from "node:fs";
const [src, dst] = process.argv.slice(2);
let s = readFileSync(src, "utf8");
const rep = (from, to) => {
  if (!s.includes(from)) throw new Error("pattern not found: " + from);
  s = s.replace(from, to);
};
rep("}(Object));(ag=>async a=>", "}(Object));globalThis.__ready=(ag=>async a=>");
rep("const\nW=g?X:P;", "const\nW=a=>a;");
rep(
  "async function\nT(a){return g?WebAssembly.instantiate(await\na,e,p):WebAssembly.instantiateStreaming(a,e,p)}",
  "async function\nT(a){return WebAssembly.instantiate(globalThis.__wasm[await\na],e,p).then(a=>({instance:a}))}",
);
rep(
  "S();var{caml_callback:i,",
  "S();globalThis.__promisify=b=>{const p=WebAssembly.promising(i);return async(...a)=>await(await p(b,a.length||(a=[undefined],1),a,1))};var{caml_callback:i,",
);
writeFileSync(dst, s);
