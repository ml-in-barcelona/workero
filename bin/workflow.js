import { WorkflowEntrypoint } from "cloudflare:workers";
import { NonRetryableError } from "cloudflare:workflows";

(globalThis.__workero ??= {}).NonRetryableError = NonRetryableError;

export class WorkeroWorkflow extends WorkflowEntrypoint {
  constructor(ctx, env, name) {
    super(ctx, env);
    const run = globalThis.__workero?.workflows?.[name];
    if (typeof run !== "function")
      throw new Error(
        `workero: class ${name} is exported but the OCaml program did not call Workero.Workflow.register "${name}"`,
      );
    this[Symbol.for("workero.run")] = run;
  }

  run(event, step) {
    return this[Symbol.for("workero.run")](this.env, event, step);
  }
}
