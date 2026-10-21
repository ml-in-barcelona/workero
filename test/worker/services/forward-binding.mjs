export default ({ TARGET, METHODS }) =>
  Object.fromEntries(METHODS.split(",").map((m) => [m, (...args) => TARGET[m](...args)]));
