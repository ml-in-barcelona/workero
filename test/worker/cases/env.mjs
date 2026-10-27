import { runCases } from "./lib.mjs";

const secretShape = (name, found) =>
  `invalid: Workero.Secret_store.of_env: binding "${name}" ${found}`;

const cases = [
  { name: "Env.secret reads a text binding", request: ["http://test/env/secret?name=API_TOKEN"], status: 200, body: "tok-123" },
  {
    name: "Env.secret raises for a missing name",
    request: ["http://test/env/secret?name=NOPE"],
    status: 200,
    body: 'invalid: Workero.Env.secret: "NOPE" not found',
  },
  {
    name: "Env.secret raises for a binding that is not a string and names its type",
    request: ["http://test/env/secret?name=SETTINGS"],
    status: 200,
    body: 'invalid: Workero.Env.secret: "SETTINGS" is an object, not a string',
  },
  {
    name: "Env.json reads an object variable",
    request: ["http://test/env/json?name=SETTINGS"],
    status: 200,
    body: '{"foo":42,"nested":{"list":[1,2]},"name":"x"}',
  },
  { name: "Env.json reads an array variable", request: ["http://test/env/json?name=LIMITS"], status: 200, body: '[1,"two",null]' },
  { name: "Env.json of a string variable", request: ["http://test/env/json?name=GREETING"], status: 200, body: "none" },
  { name: "Env.json of a missing name", request: ["http://test/env/json?name=NOPE"], status: 200, body: "none" },
  {
    name: "Env.json reads integers outside the int range as floats",
    request: ["http://test/env/json?name=BIG"],
    status: 200,
    body: '{"hi":4294967296000.0,"lo":-4294967296000.0,"e":1e+20,"i":5,"m":-5,"z":0}',
  },
  {
    name: "JSON.of_js reads integers outside the int range as floats",
    request: ["http://test/json/of-js?name=BIG"],
    status: 200,
    body: '{"hi":4294967296000.0,"lo":-4294967296000.0,"e":1e+20,"i":5,"m":-5,"z":0}',
  },
  { name: "Secret_store.get", request: ["http://test/secret-store/get?name=STORE"], status: 200, body: "store-value" },
  { name: "Secret_store.get of null", request: ["http://test/secret-store/get?name=STORE_NULL"], status: 200, body: "none" },
  { name: "Secret_store.get of undefined", request: ["http://test/secret-store/get?name=STORE_UNDEFINED"], status: 200, body: "none" },
  {
    name: "Secret_store.get raises Js_error when the store fails",
    request: ["http://test/secret-store/get?name=STORE_BROKEN"],
    status: 502,
    body: "Error: secret store unavailable",
  },
  {
    name: "Secret_store.of_env rejects a variable",
    request: ["http://test/secret-store/shape?name=GREETING"],
    status: 200,
    body: secretShape("GREETING", "is a string, not a Secrets Store secret"),
  },
  {
    name: "Secret_store.of_env rejects an object without get",
    request: ["http://test/secret-store/shape?name=SETTINGS"],
    status: 200,
    body: secretShape("SETTINGS", "is an object without method get, not a Secrets Store secret"),
  },
  {
    name: "Secret_store.of_env of a missing binding",
    request: ["http://test/secret-store/shape?name=NOPE"],
    status: 200,
    body: secretShape("NOPE", "not found"),
  },
];

export default async (env, failures) => {
  await runCases(env, cases, failures);
};
