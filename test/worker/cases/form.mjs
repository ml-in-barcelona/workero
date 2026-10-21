import { runCases } from "./lib.mjs";

const multipart = () => {
  const form = new FormData();
  form.append("title", "hello é");
  form.append("title", "second");
  form.append("file", new File([new Uint8Array([0, 255, 1])], "a.bin", { type: "application/octet-stream" }));
  form.append("blob", new Blob(["text"], { type: "text/plain" }));
  return form;
};

const post = (body, headers) => ["http://test/form/dump", { method: "POST", body, headers }];

export default async (env, failures) => {
  await runCases(
    env,
    [
      {
        name: "form: multipart with text, duplicates, file and blob",
        request: post(multipart()),
        status: 200,
        body: [
          'title=text:"hello \\195\\169"',
          'title=text:"second"',
          'file=file name="a.bin" type="application/octet-stream" size=3 bytes=0,255,1 streamed=3',
          'blob=file name="blob" type="text/plain" size=4 bytes=116,101,120,116 streamed=4',
          'first=hello é',
          'all=hello é|second',
        ].join("\n"),
      },
      {
        name: "form: urlencoded",
        request: post("title=x+y&other=1&title=2", { "content-type": "application/x-www-form-urlencoded" }),
        status: 200,
        body: [
          'title=text:"x y"',
          'other=text:"1"',
          'title=text:"2"',
          "first=x y",
          "all=x y|2",
        ].join("\n"),
      },
      {
        name: "form: a JSON body raises Js_error",
        request: post('{"a":1}', { "content-type": "application/json" }),
        status: 400,
        body: "not a form",
      },
    ],
    failures,
  );
};
