import { WorkerEntrypoint } from "cloudflare:workers";

export class Ai extends WorkerEntrypoint {
  async run(model, input) {
    switch (model) {
      case "@test/echo":
        return { model, input };
      case "@test/bytes":
        return new Uint8Array([1, 2, 3, 0, 255]);
      case "@test/stream":
        return new ReadableStream({
          start(controller) {
            controller.enqueue(new TextEncoder().encode("data: x\n\n"));
            controller.close();
          },
        });
      case "@test/undefined":
        return undefined;
    }
    throw new Error(`no such model: ${model}`);
  }
}
