
# Cloudflare Workers limits

Cloudflare sets these platform limits for Workers. Check the [current Workers limits](https://developers.cloudflare.com/workers/platform/limits/) before deployment; the plan and trigger type affect some limits.


## Worker size and startup

- The uncompressed Worker bundle limit is 64 MiB on both Free and Paid plans. There is no compressed-size limit. `wrangler deploy --outdir bundled/ --dry-run` prints `Total Upload` for the bundle that Wrangler would upload.
- Worker startup must finish within 1 second. Keep expensive work out of module initialization. `workero build` also initializes your program in `workerd` to discover Durable Object, entrypoint and Workflow classes, with a separate 30-second default probe timeout. That local probe is not the Cloudflare startup limit.

## Memory and CPU

- An isolate has 128 MB of memory, shared by concurrent requests and including JavaScript and WebAssembly allocations. Stream large bodies instead of collecting them in memory. See [Streams](./streams.md).
- An HTTP request on the Free plan has 10 ms of CPU time. On Paid, the default is 30 seconds and the configurable maximum is 5 minutes. CPU time counts execution, not time spent waiting for network I/O. Limits for Cron Triggers depend on trigger interval; see Cloudflare's [CPU time table](https://developers.cloudflare.com/workers/platform/limits/#cpu-time).

## HTTP duration and background work

Cloudflare sets no hard wall-time limit on an HTTP request while its client remains connected. A response stream still in progress keeps the invocation active. After the response completes or the client disconnects, [`Workero.Context.wait_until`](./Workero-Context.md#val-wait_until) tasks for that request share up to 30 seconds. This is not a 30-second cap on active streaming. Cloudflare can interrupt work during shutdown, runtime updates or resource pressure. See [Duration](https://developers.cloudflare.com/workers/platform/limits/#duration) and [waitUntil](https://developers.cloudflare.com/workers/runtime-apis/context/#waituntil).


## Requests and subrequests

- Cloudflare allows 50 subrequests per invocation on Free and 10,000 by default on Paid. A redirect chain can use several subrequests.
- Up to six outgoing connections per invocation can wait for response headers at the same time. A connection no longer counts toward this limit after its response headers arrive.
- Request body size depends on your Cloudflare account plan. Cloudflare does not enforce a response-body size limit, though cache limits still apply.
These are platform limits, not measured workero performance figures. Test your Worker's behavior with [Testing a worker](./testing.md) and check the current Cloudflare documentation for your account plan and deployment.
