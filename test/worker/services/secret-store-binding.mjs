export default ({ VALUE, MODE }) => ({
  async get() {
    if (MODE === "fail") throw new Error("secret store unavailable");
    if (MODE === "null") return null;
    if (MODE === "undefined") return undefined;
    return VALUE;
  },
});
