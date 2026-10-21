import { readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, extname, join, relative, resolve, sep } from "node:path";

const [markdownArgument, htmlArgument] = process.argv.slice(2);
if (!markdownArgument || !htmlArgument) {
  throw new Error("Usage: node doc/markdown.mjs <markdown-directory> <html-directory>");
}
const markdownRoot = resolve(markdownArgument);
const htmlRoot = resolve(htmlArgument);
const site = "https://ml-in-barcelona.github.io/workero/";
const ids = new Map();
let checked = 0;

function files(directory, extension) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? files(path, extension) : path.endsWith(extension) ? [path] : [];
  });
}

function check(path, fragment, source) {
  if (statSync(path, { throwIfNoEntry: false })?.isDirectory()) path = join(path, "index.html");
  if (!statSync(path, { throwIfNoEntry: false })?.isFile()) {
    throw new Error(`${source}: missing link target ${path}`);
  }
  if (fragment) {
    if (!ids.has(path)) {
      const content = readFileSync(path, "utf8");
      ids.set(path, new Set([...content.matchAll(/\bid="([^"]+)"/g)].map((match) => match[1])));
    }
    if (!ids.get(path).has(decodeURIComponent(fragment))) {
      throw new Error(`${source}: missing anchor ${path}#${fragment}`);
    }
  }
  checked++;
}

function htmlPath(markdownPath) {
  const path = relative(markdownRoot, markdownPath);
  if (path.startsWith(`..${sep}`) || path === "..") {
    throw new Error(`Markdown link leaves the documentation directory: ${markdownPath}`);
  }
  const stem = path.slice(0, -extname(path).length);
  return /(?:^|\/)Workero(?:-|$)/.test(stem)
    ? `${stem.replaceAll("-", "/")}/index.html`
    : `${stem}.html`;
}

for (const file of files(markdownRoot, ".md")) {
  const source = readFileSync(file, "utf8");
  const result = source.replace(/\]\(([^\s)]+)\)/g, (link, destination) => {
    if (destination.startsWith(site)) {
      const [path, fragment] = destination.slice(site.length).split("#");
      check(resolve(htmlRoot, decodeURIComponent(path)), fragment, file);
      return link;
    }
    if (/^(?:[a-z][a-z\d+.-]*:|\/\/)/i.test(destination)) return link;
    const [path, fragment] = destination.split("#");
    const target = !path || path === "./" ? file : resolve(dirname(file), decodeURIComponent(path));
    if (!fragment) {
      check(target, undefined, file);
      return link;
    }
    const html = htmlPath(target);
    check(resolve(htmlRoot, html), fragment, file);
    return `](${site}${html}#${fragment})`;
  });
  if (result !== source) writeFileSync(file, result);
}

for (const file of files(htmlRoot, ".html")) {
  for (const [, destination] of readFileSync(file, "utf8").matchAll(/\b(?:href|src)="([^"]+)"/g)) {
    if (/^(?:[a-z][a-z\d+.-]*:|\/\/)/i.test(destination)) continue;
    const [path, fragment] = destination.split("#");
    check(path ? resolve(dirname(file), decodeURIComponent(path)) : file, fragment, file);
  }
}

console.log(`Checked ${checked} local documentation links and anchors.`);
