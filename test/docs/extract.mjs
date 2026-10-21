import { readFileSync, readdirSync, mkdirSync, writeFileSync } from "node:fs";
import { join, basename } from "node:path";

const [root, projects] = process.argv.slice(2);
if (!root || !projects) throw new Error("usage: node extract.mjs ROOT PROJECTS");

const files = readdirSync(join(root, "doc"))
  .filter((name) => name.endsWith(".mld"))
  .map((name) => `doc/${name}`)
  .concat("README.md");
const manifest = [];
for (const file of files) {
  const text = readFileSync(join(root, file), "utf8");
  const open = file === "README.md" ? /```ocaml\r?\n/g : /\{@ocaml\[/g;
  const close = file === "README.md" ? "```" : "]}";
  let match;
  let index = 0;
  while ((match = open.exec(text))) {
    const end = text.indexOf(close, open.lastIndex);
    if (end < 0) throw new Error(`${file}: unclosed OCaml block`);
    const code = text.slice(open.lastIndex, end).trim() + "\n";
    const line = text.slice(0, match.index).split("\n").length;
    const id = `${basename(file, file === "README.md" ? ".md" : ".mld")}-${++index}`;
    const dir = join(projects, id);
    mkdirSync(join(dir, "src"), { recursive: true });
    writeFileSync(join(dir, "dune-project"), "(lang dune 3.24)\n(name docs_example)\n");
    writeFileSync(join(dir, "src", "dune"),
      `(executable\n (name main)\n (modes wasm)\n (libraries workero js_of_ocaml${file === "doc/json.mld" ? " jsonkit" : ""})${file === "doc/json.mld" ? "\n (preprocess (pps jsonkit.ppx))" : ""})\n`);
    writeFileSync(join(dir, "src", "main.ml"), code);
    manifest.push({ id, file, line });
    open.lastIndex = end + close.length;
  }
  if ((text.match(file === "README.md" ? /```ocaml\r?\n/g : /\{@ocaml\[/g) ?? []).length !== index)
    throw new Error(`${file}: some OCaml blocks were not extracted`);
}
if (manifest.length === 0) throw new Error("No OCaml examples found");
writeFileSync(join(projects, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
console.log(`Extracted ${manifest.length} OCaml blocks from ${files.length} documents`);
