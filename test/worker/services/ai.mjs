import { WorkerEntrypoint } from "cloudflare:workers";

export class Ai extends WorkerEntrypoint {
  async run(model, input, options) {
    switch (model) {
      case "@test/options":
        return { options: options ?? null };
      case "@test/stream-echo": {
        const encoder = new TextEncoder();
        const chunks = [`data: ${JSON.stringify({ input, options: options ?? null })}\n\n`, "data: [DONE]\n\n"];
        return new ReadableStream({
          start(controller) {
            for (const chunk of chunks) controller.enqueue(encoder.encode(chunk));
            controller.close();
          },
        });
      }
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
