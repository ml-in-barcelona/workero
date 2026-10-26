import { report } from "./lib.mjs";

const bytes = (text) => [...new TextEncoder().encode(text)];

const message = (to, extra = {}) => ({
  from: "sender@example.org",
  to,
  headers: [],
  chunks: [bytes("Subject: hi\r\n\r\nbody")],
  ...extra,
});

const run = async (env, spec) => {
  const response = await env.EMAIL.fetch("http://harness/", { method: "POST", body: JSON.stringify(spec) });
  return response.json();
};

const rejectOnly = (reason) => ({ calls: [{ op: "setReject", reason }], error: null });

const cases = [
  {
    name: "Email accessors read from, to, raw size and headers without regard to case",
    spec: message("accessors@example.com", {
      headers: [
        ["Subject", "Hello"],
        ["X-Tag", "a"],
        ["X-Tag", "b"],
      ],
      chunks: [bytes("0123456789")],
    }),
    expected: rejectOnly("from=sender@example.org;to=accessors@example.com;size=10;subject=Hello;tag=a, b;tags=a, b;missing=none;count=2"),
  },
  {
    name: "Email.headers lists lower case names sorted by name",
    spec: message("headers@example.com", {
      headers: [
        ["Zeta", "1"],
        ["Alpha", "2"],
      ],
    }),
    expected: rejectOnly("alpha=2;zeta=1"),
  },
  {
    name: "Email.raw_text reads the whole raw message across chunks as UTF-8",
    spec: message("raw-text@example.com", { chunks: [bytes("Subject: hé"), bytes("\r\n\r\nbody ✓")] }),
    expected: rejectOnly("text=Subject: hé\r\n\r\nbody ✓"),
  },
  {
    name: "Email.raw_bytes reads the raw bytes exactly",
    spec: message("raw-bytes@example.com", { chunks: [[0, 255], [128, 10]] }),
    expected: rejectOnly("bytes=00ff800a"),
  },
  {
    name: "Email.raw streams the chunks",
    spec: message("raw-stream@example.com", { chunks: [bytes("aaa"), bytes("bb"), bytes("c")] }),
    expected: rejectOnly("chunks=3;total=6"),
  },
  {
    name: "the raw message can be read once",
    spec: message("raw-twice@example.com"),
    expected: rejectOnly("first=19;second=error"),
  },
  {
    name: "Email.forward forwards to the address",
    spec: message("forward@example.com"),
    expected: { calls: [{ op: "forward", recipient: "dest@example.com", headers: null }], error: null },
  },
  {
    name: "Email.forward passes the headers",
    spec: message("forward-headers@example.com"),
    expected: {
      calls: [{ op: "forward", recipient: "dest@example.com", headers: [["x-seen", "yes"], ["x-via", "workero"]] }],
      error: null,
    },
  },
  {
    name: "Email.forward raises Js_error when the runtime rejects",
    spec: message("forward-fails@example.com", { forwardError: "address not verified" }),
    expected: rejectOnly("caught Error: address not verified"),
  },
  {
    name: "Email.reply builds an EmailMessage from the cloudflare:email module and replies",
    spec: message("reply@example.com"),
    expected: {
      calls: [
        {
          op: "reply",
          isEmailMessage: true,
          from: "support@example.com",
          to: "sender@example.org",
          rawIsStream: false,
          raw: "From: support@example.com\r\nTo: a@example.org\r\nIn-Reply-To: <1@example.org>\r\n\r\nthanks é\r\n",
        },
      ],
      error: null,
    },
  },
  {
    name: "Email.reply with a `Stream builds an EmailMessage with a stream as the raw message",
    spec: message("reply-stream@example.com"),
    expected: {
      calls: [
        {
          op: "reply",
          isEmailMessage: true,
          from: "support@example.com",
          to: "sender@example.org",
          rawIsStream: true,
          raw: "From: support@example.com\r\nIn-Reply-To: <1@example.org>\r\n\r\nstreamed é\r\n",
        },
      ],
      error: null,
    },
  },
  {
    name: "Email.set_reject rejects with the reason",
    spec: message("reject@example.com"),
    expected: rejectOnly("no thanks"),
  },
  {
    name: "an email handler can await a timer and fetch",
    spec: message("await@example.com"),
    expected: rejectOnly("upstream=203"),
  },
  {
    name: "an email handler that raises rejects the event",
    spec: message("raise@example.com"),
    check: (result) => (result.error?.includes("Failure") && result.error.includes("email failed") ? undefined : `error ${JSON.stringify(result.error)}`),
  },
];

export default async (env, failures) => {
  for (const c of cases) {
    const problems = [];
    const { exported, ...result } = await run(env, c.spec);
    if (!exported.includes("email")) problems.push(`exports ${JSON.stringify(exported)}`);
    if (c.check) {
      const problem = c.check(result);
      if (problem !== undefined) problems.push(problem);
    } else if (JSON.stringify(result) !== JSON.stringify(c.expected))
      problems.push(`result ${JSON.stringify(result)}, expected ${JSON.stringify(c.expected)}`);
    report(c.name, problems, failures);
  }
};
