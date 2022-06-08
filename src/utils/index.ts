import { sqrt as s, getNearestTick as GNT } from "./sqrt";

export const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

export const sqrt = s;
export const getNearestTick = GNT;
