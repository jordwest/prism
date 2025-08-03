import {
  FresnelExports,
  FresnelState,
  OdinSlicePointer,
  OdinStringPointer,
  Pointer,
} from "./types";
import { readOdinString, getSlice } from "./util";
import basex from "base-x";

const ENCODING =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz !\"#$%&'()*+,-./0123456789:;<=>?@[]^_`{|}~";
var base94 = basex(ENCODING);

export type FresnelInstance = {
  wasmInstance: WebAssembly.Instance;
  memory: ArrayBufferLike;
  state: FresnelState;
  metrics: Record<string, any>;
  exports: FresnelExports;
};

export async function instantiate(
  state: FresnelState,
): Promise<FresnelInstance> {
  // Need to set up a reference here so it can be passed in to the exports
  const instance = {} as FresnelInstance;

  instance.wasmInstance = (
    await WebAssembly.instantiateStreaming(
      fetch("assets/app.wasm"),
      createImports(instance),
    )
  ).instance;
  const memoryObj = instance.wasmInstance.exports.memory as WebAssembly.Memory;
  instance.memory = memoryObj.buffer;
  instance.state = state;
  instance.metrics = {};
  instance.exports = instance.wasmInstance.exports as FresnelExports;

  instance.exports.boot(state.canvas.width, state.canvas.height);

  return instance;
}

function createImports(instance: FresnelInstance): WebAssembly.Imports {
  return {
    debug: createDebugImports(instance),
    env: createEnvImports(),
    core: createCoreImports(instance),
    net: createNetImports(instance),
  };
}

function createDebugImports(
  instance: FresnelInstance,
): WebAssembly.ModuleImports {
  return {
    log_panic(
      prefix: OdinStringPointer,
      message: OdinStringPointer,
      file: OdinStringPointer,
      lineNumber: number,
    ) {
      console.error(
        `${readOdinString(instance.memory, prefix)}: ${readOdinString(instance.memory, message)}\n${readOdinString(instance.memory, file)}:${lineNumber}`,
      );
    },

    metric_str(name: OdinStringPointer, s: OdinStringPointer) {
      instance.metrics[readOdinString(instance.memory, name)!] = readOdinString(
        instance.memory,
        s,
      );
    },

    metric_i32(name: OdinStringPointer, num: number) {
      instance.metrics[readOdinString(instance.memory, name)!] = num;
    },

    log_slice(name: OdinStringPointer, ptr: OdinSlicePointer) {
      const groupName = readOdinString(instance.memory, name);

      const view = new DataView(instance.memory, ptr);
      const dataPtr = view.getUint32(0, true);

      const slice = getSlice(instance.memory, ptr);

      console.group("👉", groupName, dataPtr, "0x" + dataPtr.toString(16));
      console.info(slice);

      var chars = [];
      for (var b of slice) {
        if (b >= 32 && b <= 126) {
          chars.push(String.fromCharCode(b));
        } else {
          chars.push("0x" + b.toString(16).padStart(2, "0"));
        }
      }

      console.info(chars.join(" "));
      console.groupEnd();
    },
  };
}

function createEnvImports() {
  return {
    sinf: (x: number) => Math.sin(x),
    cosf: (x: number) => Math.cos(x),
  };
}

function createCoreImports(instance: FresnelInstance) {
  return {
    print: (ptr: OdinStringPointer, lvl: number) => {
      const s = readOdinString(instance.memory, ptr);
      switch (lvl) {
        case 0:
          return console.log(s);
        case 1:
          return console.info(s);
        case 2:
          return console.warn(s);
        case 3:
          return console.error(s);
      }
    },
    clear: () => {
      instance.state.canvasContext.clearRect(
        0,
        0,
        instance.state.canvas.width,
        instance.state.canvas.height / 2,
      );
    },
    storage_set: (keyPtr: OdinStringPointer, slice: OdinSlicePointer) => {
      const key = readOdinString(instance.memory, keyPtr);
      const data = getSlice(instance.memory, slice);

      const b94encoded = base94.encode(data);

      instance.state.storage[key] = b94encoded;
    },
    storage_get: (
      keyPtr: OdinStringPointer,
      slice: OdinSlicePointer,
    ): number => {
      const key = readOdinString(instance.memory, keyPtr);
      const destination = getSlice(instance.memory, slice);
      const b94encoded = instance.state.storage[key];
      if (b94encoded != null) {
        if (b94encoded.length > destination.length) {
          return -2; // ERROR Slice not big enough
        }

        const data = base94.decode(b94encoded);
        destination.set(data);

        return data.length;
      }
      return -1; // ERROR Key not found
    },
    measure_text: (size: number, strPtr: OdinStringPointer) => {
      const text = readOdinString(instance.memory, strPtr);
      instance.state.canvasContext.font = `${size}px CompaqThin`;
      return instance.state.canvasContext.measureText(text).width;
    },
    fill: (r: number, g: number, b: number, a: number) => {
      instance.state.canvasContext.fillStyle = `rgba(${r}, ${g}, ${b}, ${a})`;
    },
    draw_rect: (x: number, y: number, w: number, h: number) => {
      instance.state.canvasContext.fillRect(x, y, w, h);
    },
    draw_text: (
      x: number,
      y: number,
      size: number,
      strPtr: OdinStringPointer,
    ) => {
      const text = readOdinString(instance.memory, strPtr);
      instance.state.canvasContext.font = `${size}px CompaqThin`;
      instance.state.canvasContext.fillText(text, x, y);
    },
  };
}

function createNetImports(instance: FresnelInstance) {
  let messages: Uint8Array<ArrayBuffer>[] = [];

  return {
    client_send_message: (msgPtr: Pointer, size: number) => {
      const messageContent = new Uint8Array(instance.memory, msgPtr, size);
      messages.push(messageContent.slice());
      return 1;
    },
    client_poll_message: (msgPtr: Pointer, size: number) => {
      const message = messages.shift();
      if (message == null) {
        return 0;
      }

      if (message.length !== size) {
        return 0;
      }

      const memView = new Uint8Array(instance.memory, msgPtr, size);
      console.log(memView);

      memView.set(message);
      return size;
    },
  };
}
