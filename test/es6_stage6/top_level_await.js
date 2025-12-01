import dataLoader from "./data-loader.js";
import { hydrate } from "./helpers.js";

const payload = await dataLoader();
const result = hydrate(payload);

export { result as hydrated };
export default await Promise.resolve(result.value);
