export async function loadWasmOCaml(modules, importLoader) {
  const saved = {
    process: globalThis.process,
    fetch: globalThis.fetch,
    instantiateStreaming: WebAssembly.instantiateStreaming,
    promising: WebAssembly.promising,
    consoleError: console.error,
  };
  const errors = [];
  const format = (value) => {
    if (typeof value === "string") return value;
    if (value instanceof Error) return value.stack ?? String(value);
    try {
      return JSON.stringify(value) ?? String(value);
    } catch {
      return String(value);
    }
  };
  console.error = (...args) => {
    errors.push(args.map(format).join(" ").replace(/\n$/, ""));
    saved.consoleError.apply(console, args);
  };
  let init;
  let callback;
  let callbackPromising;
  let settle;
  const done = new Promise((resolve, reject) => (settle = { resolve, reject }));
  globalThis.process = undefined;
  globalThis.fetch = async (path) => {
    const module = modules[path];
    if (!module) throw new Error("unknown wasm module: " + path);
    return { module };
  };
  WebAssembly.instantiateStreaming = async (response, imports) => {
    try {
      const { module } = await response;
      const sys = imports.bindings;
      const exit = sys.exit;
      sys.exit = (code) => {
        const what =
          code === 0
            ? "OCaml program exited during initialisation"
            : "OCaml initialisation failed";
        settle.reject(
          new Error(`${what} (exit code ${code}):\n${errors.join("\n").trim()}`),
        );
        return exit(code);
      };
      const instance = await WebAssembly.instantiate(module, imports);
      init = instance.exports._initialize ?? init;
      callback = instance.exports.caml_callback ?? callback;
      return { instance };
    } catch (error) {
      settle.reject(error);
      throw error;
    }
  };
  if (saved.promising) WebAssembly.promising = (f) => {
    const promising = saved.promising(f);
    if (f !== init) return promising;
    return async (...args) => {
      try {
        return await promising(...args);
      } finally {
        settle.resolve();
      }
    };
  };
  globalThis.__promisify = (f) => async (...args) => {
    callbackPromising ??= saved.promising(callback);
    const arity = args.length || ((args = [undefined]), 1);
    return await (await callbackPromising(f, arity, args, 1));
  };
  try {
    await importLoader();
    await done;
  } finally {
    globalThis.process = saved.process;
    globalThis.fetch = saved.fetch;
    WebAssembly.instantiateStreaming = saved.instantiateStreaming;
    if (saved.promising) WebAssembly.promising = saved.promising;
    console.error = saved.consoleError;
  }
}
