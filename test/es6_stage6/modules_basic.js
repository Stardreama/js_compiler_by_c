import defaultValue from "./defaults.js";
import defaultValueAgain, { fallback as aliasFallback, primary } from "./named.js";
import { widget, gadget as renamedGadget, default as feature } from "./feature.js";
import * as toolkit from "./toolkit.js";
import "./side-effects.js";

const aggregated = defaultValue + defaultValueAgain + toolkit.total(widget, renamedGadget) + feature + primary + aliasFallback;

export { aggregated };
export { widget, renamedGadget as gadgetAlias } from "./feature.js";
export * from "./legacy.js";
export * as LegacyTools from "./legacy.js";
