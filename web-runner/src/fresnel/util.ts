import {
  I32Pointer,
  OdinSlicePointer,
  OdinStringPointer,
  Pointer,
} from "./types";

export const readOdinString = (
  buffer: ArrayBufferLike,
  ptr: OdinStringPointer,
) => {
  const bytes = getSlice(buffer, ptr);

  const string = new TextDecoder().decode(bytes);
  return string;
};

export const readCString = (buffer: ArrayBufferLike, ptr: Pointer) => {
  const data = new Uint8Array(buffer, ptr);
  let i = 0;
  while (true) {
    if (data[i] === 0) {
      break;
    }
    i++;
  }

  const bytes = new Uint8Array(buffer, ptr, i);

  const string = new TextDecoder().decode(bytes);
  return string;
};

export const writeI32 = (
  buffer: ArrayBufferLike,
  ptr: I32Pointer,
  val: number,
) => {
  const data = new DataView(buffer);
  data.setInt32(ptr, val, true);
};

export const getSlice = (buffer: ArrayBufferLike, ptr: OdinSlicePointer) => {
  const data = new DataView(buffer);
  const bytesPtr = data.getInt32(ptr, true);
  const bytesLen = data.getInt32(ptr + 4, true);

  const bytes = new Uint8Array(buffer, bytesPtr, bytesLen);

  return bytes;
};
