/** @type ArrayBufferLike */
let mem;

const readString = (ptr) => {
  const data = new Uint8Array(mem, ptr);
  let i = 0;
  while (true) {
    if (data[i] === 0) {
      break;
    }
    i++;
  }

  const bytes = new Uint8Array(mem, ptr, i);

  const string = new TextDecoder().decode(bytes);
  return string;
};

const readU32 = (address) => {
  const u32 = new Uint32Array(mem, address, 4);
  return u32[0];
};

const importObject = {
  debug: {
    log_u8(info, num) {
      console.log(readString(info), num);
    },
    log_pointer(ptr, size) {
      const arr = new Uint8Array(mem, ptr, size);
      // Blah

      console.warn("👉 Pointer at ", ptr, " size ", size, arr);

      const nextPtr = readU32(ptr);
      if (nextPtr < mem.byteLength) {
        const nextArr = new Uint8Array(mem, nextPtr, 10);
        console.warn("👉", nextPtr, nextArr);
      }
    },
  },
  my_namespace: {
    test: (ptr) => {
      console.log(ptr, mem);

      const struct = new Uint8Array(mem, ptr, 6);

      console.log("pointer", struct[0], struct[1], struct[5], struct);
      return ptr[1];
    },
    print: (ptr) => {
      console.warn(readString(ptr));
    },
  },
};

function startWasm() {
  WebAssembly.instantiateStreaming(fetch("optimized.wasm"), importObject).then(
    (obj) => {
      // Do something with the results!
      console.log(obj);

      const structPointer = 70000;

      mem = obj.instance.exports.memory.buffer;
      const buf = new Uint8Array(mem, structPointer, 6);

      buf[0] = 5;
      buf[1] = 6;
      buf[5] = 7;

      console.log(obj.instance.exports.hello(structPointer));
    },
  );
}

const ws = new WebSocket("ws://localhost:8000");
ws.addEventListener("message", () => {
  console.log("Websocket message received, rebooting wasm");
  startWasm();
});

setTimeout(() => {
  const canvas = document.getElementById("canvas");
  const ctx = canvas.getContext("2d");
  ctx.font = "16px CompaqThin";
  ctx.imageSmoothingEnabled = false;
  ctx.fillText("hellooooo there 😂", 20, 20);
  console.log("Text measure", ctx.measureText("Hellooooooo there"));
}, 100);
