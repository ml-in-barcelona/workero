import { runCases } from "./lib.mjs";

const cases = [
  { name: "Socket: write, read, close the write side, read the end", request: ["http://test/socket/echo"], status: 200, body: "echo=hello eof=true" },
  { name: "Socket: all 256 byte values echo unchanged", request: ["http://test/socket/bytes"], status: 200, body: "same=true" },
  { name: "Socket: 64 KiB echoes in order over 16 round trips", request: ["http://test/socket/large"], status: 200, body: "size=65536 same=true" },
  { name: "Socket: a server that ends its side closes the write side", request: ["http://test/socket/server-close"], status: 200, body: "eof=true late=refused" },
  { name: "Socket: allow_half_open keeps the write side open", request: ["http://test/socket/server-close?half=true"], status: 200, body: "eof=true late=ok" },
  { name: "Socket.close then closed", request: ["http://test/socket/close"], status: 200, body: "closed" },
  { name: "Socket: reader and writer lock the stream", request: ["http://test/socket/locked"], status: 200, bodyIncludes: "reader=Js_error: TypeError" },
  { name: "Stream.Reader.release and Writer.release unlock the socket streams", request: ["http://test/socket/release"], status: 200, body: "echo=again" },
  { name: "Socket.connect rejects an empty host and bad ports", request: ["http://test/socket/invalid"], status: 200, body: [
    "Invalid_argument: Workero.Socket.connect: host is empty",
    "Invalid_argument: Workero.Socket.connect: port 0 is outside 1 to 65535",
    "Invalid_argument: Workero.Socket.connect: port 65536 is outside 1 to 65535",
  ].join("\n") },
  { name: "Socket: secure_transport On reaches the runtime", request: ["http://test/socket/tls-on"], status: 200, bodyIncludes: "TLS" },
  { name: "Socket.start_tls on a plain socket raises Js_error", request: ["http://test/socket/start-tls"], status: 200, bodyIncludes: "Js_error: TypeError: The `secureTransport` socket option must be set to 'starttls'" },
  { name: "Socket.start_tls on a Starttls socket reaches the runtime", request: ["http://test/socket/start-tls?mode=starttls"], status: 200, bodyIncludes: "startTls() is not supported on this connection" },
];

export default async (env, failures) => {
  await runCases(env, cases, failures);
};
