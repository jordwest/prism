import { createAudioImports } from "./audio";
import { createInputImports } from "./input";
import { createNetImports } from "./net";
import { HostNetPeer, ClientNetPeer } from "../net-interface/interface";
import {
  FresnelExports,
  FresnelState,
  InputBoxState,
  OdinSlicePointer,
  OdinStringPointer,
  Pointer,
} from "./types";
import { readOdinString, getSlice } from "./util";
import { DummyNetPeer } from "../net-interface/dummy";
import { NET_FAKE_DELAY, WS_RELAY } from "..";
import { base94 } from "../base94";
import { WebSocketRelayHostNetPeer, WebSocketRelayClientNetPeer } from "../net-interface/websocket";

export type FresnelInstance = {
  connected: boolean;
  wasmInstance: WebAssembly.Instance;
  memory: ArrayBufferLike;
  hostPeer: HostNetPeer;
  peer: ClientNetPeer;
  state: FresnelState;
  metrics: Record<string, any>;
  exports: FresnelExports;
  instanceId: number;
  region: { y: number; height: number };
  tests: {
    name: string | null;
    hasAssertionFailure: boolean;
    passed: number;
    failed: number;
  };

  input: {
    pressedActions: Set<number>;
    pressedActionsThisFrame: Set<number>;
    inputBoxState: InputBoxState,
  };
};

export async function instantiate(
  state: FresnelState,
  instanceId: number,
  region: { y: number; height: number },
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
  instance.instanceId = instanceId;
  instance.region = region;
  instance.tests = {
    hasAssertionFailure: false,
    name: null,
    passed: 0,
    failed: 0,
  };
  // instance.peer = new DummyNetPeer(NET_FAKE_DELAY, instanceId);
  instance.peer = new WebSocketRelayClientNetPeer();
  instance.hostPeer = new WebSocketRelayHostNetPeer(WS_RELAY);
  instance.hostPeer.onClientConnected(clientId => instance.exports.on_client_connected?.(clientId))
  instance.hostPeer.onListening(() => instance.exports.on_listening?.())
  instance.input = {
    inputBoxState: createInputElement(instance),
    pressedActions: new Set(),
    pressedActionsThisFrame: new Set(),
  };

  instance.exports.tests?.();

  console.info("Instance exported memory is ", memoryObj.buffer.byteLength);

  return instance;
}

function createImports(instance: FresnelInstance): WebAssembly.Imports {
  return {
    debug: createDebugImports(instance),
    env: createEnvImports(),
    core: createCoreImports(instance),
    audio: createAudioImports(instance),
    input: createInputImports(instance),
    net: createNetImports(instance),
  };
}

function createInputElement(instance: FresnelInstance): InputBoxState {
  const state: InputBoxState = {
    element: document.createElement('input'),
    isComposing: false,
    size: 0,
    value: '',
    visible: false,
    x: 0,
    y: 0,
  }
  document.querySelector('#overlays')!.appendChild(state.element)
  state.element.type = 'text';
  state.element.value = '';
  state.element.style = 'position: absolute; z-index: 99; background-color: transparent; color: white; border: 0; left: 0, top: 0; outline: none; padding: 0;';
  state.element.hidden = true;
  state.element.addEventListener('input', e => {
    if (state.isComposing) return;
    state.value = (e.currentTarget as HTMLInputElement).value
    instance.exports.on_input?.();
  })
  state.element.addEventListener('compositionstart', e => {
    state.isComposing = true;
  })
  state.element.addEventListener('compositionend', e => {
    state.isComposing = false;
    state.value = (e.currentTarget as HTMLInputElement).value
  })
  return state;
}

function createDebugImports(
  instance: FresnelInstance,
): WebAssembly.ModuleImports {
  return {
    now() {
      return performance.now();
    },
    breakpoint() {
      debugger;
    },
    test_case(namePtr: OdinStringPointer) {
      const name = readOdinString(instance.memory, namePtr);
      instance.tests.hasAssertionFailure = false;
      instance.tests.name = name;

      console.group(name);
    },
    test_assert(name: OdinStringPointer, pass: boolean) {
      if (!pass) {
        instance.tests.hasAssertionFailure = true;
        console.error(
          "🔴 Assertion failed: ",
          readOdinString(instance.memory, name),
        );
      }
    },
    test_complete(pass: boolean) {
      const failed = !pass || instance.tests.hasAssertionFailure;
      instance.tests.failed += failed ? 1 : 0;
      instance.tests.passed += failed ? 0 : 1;

      if (failed) {
        console.error("🔴 Test ", instance.tests.name, " failed");
      }
      console.groupEnd();
    },
    test_report(): number {
      if (instance.tests.failed > 0) {
        console.error(
          "🔴 ",
          instance.tests.failed,
          " tests failed, ",
          instance.tests.passed,
          " tests passed",
        );
      } else {
        console.info(
          `%c  ✅ All ${instance.tests.passed} tests passed`,
          "background-color: #226622; display: block; padding: 4px;",
        );
      }
      return instance.tests.failed;
    },
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

    log_i32(name: OdinStringPointer, val: number) {
      const str = readOdinString(instance.memory, name)
      if (str.includes("ptr") || str.includes("pointer")) {
        const bytes = new Uint8Array(instance.memory, val - 10, 20)
        console.log(name, bytes)
      } else {
        console.log(str, val);
      }
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
    powf: (x: number, y: number) => Math.pow(x, y),
    pow: (x: number, y: number) => Math.pow(x, y),
    exp2: (x: number, y: number) => Math.pow(x, y),
  };
}

function createCoreImports(instance: FresnelInstance) {
  return {
    fill_slice_random: (ptr: OdinSlicePointer) => {
      const slice = getSlice(instance.memory, ptr);
      crypto.getRandomValues(slice);
    },
    print: (ptr: OdinStringPointer, lvl: number) => {
      const id = `[INS:${instance.instanceId}] `;
      const s = readOdinString(instance.memory, ptr);
      switch (lvl) {
        case 0:
          return console.log(id, s);
        case 1:
          return console.info(id, s);
        case 2:
          return console.warn(id, s);
        case 3:
          return console.error(id, s);
      }
    },
    cursor_hide: () => {
      instance.state.canvas.style.cursor = 'none';
    },
    cursor_show: () => {
      instance.state.canvas.style.cursor = 'auto';
    },
    clear: () => {
      instance.state.canvasContext.clearRect(
        0,
        instance.state.canvas.height * instance.region.y,
        instance.state.canvas.width,
        instance.state.canvas.height * instance.region.height,
      );
    },
    storage_set: (keyPtr: OdinStringPointer, slice: OdinSlicePointer) => {
      const key = `${instance.instanceId}:${readOdinString(instance.memory, keyPtr)}`;
      const data = getSlice(instance.memory, slice);

      const b94encoded = base94.encode(data);

      try {
        localStorage.setItem(key, b94encoded)
      } catch (e) {
        sessionStorage.setItem(key, b94encoded)
      }
    },
    storage_get: (
      keyPtr: OdinStringPointer,
      slice: OdinSlicePointer,
    ): number => {
      const key = `${instance.instanceId}:${readOdinString(instance.memory, keyPtr)}`;
      const destination = getSlice(instance.memory, slice);
      let b94encoded: string | null;
      try {
        b94encoded = localStorage.getItem(key)
      } catch {
        b94encoded = sessionStorage.getItem(key)
      }
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
      instance.state.canvasContext.font = `${size}px ${instance.state.font}`;
      return instance.state.canvasContext.measureText(text).width;
    },
    fill: (r: number, g: number, b: number, a: number) => {
      instance.state.canvasContext.fillStyle = `rgba(${r}, ${g}, ${b}, ${a})`;
    },
    draw_rect: (x: number, y: number, w: number, h: number) => {
      instance.state.canvasContext.fillRect(
        x,
        y + instance.state.canvas.height * instance.region.y,
        w,
        h,
      );
    },
    draw_image: (args_ptr: number) => {
      const view = new DataView(instance.memory, args_ptr);

      const imageId = view.getInt32(0, true);
      const sx = view.getFloat32(4, true);
      const sy = view.getFloat32(8, true);
      const sw = view.getFloat32(12, true);
      const sh = view.getFloat32(16, true);
      const dx = view.getFloat32(20, true);
      const dy = view.getFloat32(24, true);
      const dw = view.getFloat32(28, true);
      const dh = view.getFloat32(32, true);
      const alpha = view.getUint8(36);

      const image = instance.state.assets[imageId];
      if (image == null || image.type != "image") {
        instance.state.canvasContext.fillRect(
          sx,
          dy + instance.state.canvas.height * instance.region.y,
          dw,
          dh,
        );
        return;
      }
      // --- This works for rotation ---
      // instance.state.canvasContext.translate(
      //   dx,
      //   dy + instance.state.canvas.height * instance.region.y,
      // );
      // instance.state.canvasContext.rotate((15 * Math.PI) / 180);
      // instance.state.canvasContext.translate(
      //   -dx,
      //   -(dy + instance.state.canvas.height * instance.region.y),
      // );
      //
      const opacity = instance.state.canvasContext.globalAlpha;
      instance.state.canvasContext.globalAlpha = alpha / 255;

      instance.state.canvasContext.drawImage(
        image.image,
        sx,
        sy,
        sw,
        sh,
        Math.round(dx),
        Math.round(dy + instance.state.canvas.height * instance.region.y),
        dw,
        dh,
      );

      instance.state.canvasContext.globalAlpha = opacity;
      // Needed if rotation enabled
      // instance.state.canvasContext.resetTransform();
    },
    draw_text: (
      x: number,
      y: number,
      size: number,
      strPtr: OdinStringPointer,
    ) => {
      const text = readOdinString(instance.memory, strPtr);
      instance.state.canvasContext.font = `${size}px ${instance.state.font}`;
      instance.state.canvasContext.fillText(
        text,
        x,
        y + instance.state.canvas.height * instance.region.y,
      );
    },
  };
}
