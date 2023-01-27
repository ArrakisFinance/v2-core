import { sqrt, getNearestTick } from "./sqrt";

export const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

export { sqrt, getNearestTick };
