import basex from "base-x";

const ENCODING =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz !\"#$%&'()*+,-./0123456789:;<=>?@[]^_`{|}~";

export const base94 = basex(ENCODING);

export type Base94EncodedString = string & { __base94: never };

export const toBase94 = (data: Uint8Array<ArrayBufferLike>): Base94EncodedString =>
  base94.encode(data) as Base94EncodedString

export const fromBase94 = (data: Base94EncodedString): Uint8Array<ArrayBufferLike> =>
  base94.decode(data)
