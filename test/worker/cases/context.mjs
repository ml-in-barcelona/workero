import { runCases } from "./lib.mjs";

const cases = [
  {
    name: "pass_through_on_exception returns",
    request: ["http://test/context/pass-through"],
    status: 200,
    body: "passed",
  },
  {
    name: "an exception after pass_through_on_exception still gives 500",
    request: ["http://test/context/pass-through-raise"],
    status: 500,
  },
];

export default async (env, failures) => {
  await runCases(env, cases, failures);
};
