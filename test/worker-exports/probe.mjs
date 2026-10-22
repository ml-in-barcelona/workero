import handlers from "./index.js";

export default {
  fetch: () => Response.json(Object.keys(handlers)),
};
