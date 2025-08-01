/** @type ArrayBufferLike */
let mem;

const canvas = document.getElementById("canvas");
canvas.width = 1280;
canvas.height = 1024;
const ctx = canvas.getContext("2d");

const readOdinString = (ptr) => {
  if (mem == null) {
    console.error("mem is null");
    return;
  }

  const data = new DataView(mem);
  const charPtr = data.getInt32(ptr, true);
  const charLen = data.getInt32(ptr + 4, true);
  console.log("String at ", charPtr, charLen);

  // let i = 0;
  // while (true) {
  //   if (data[i] === 0) {
  //     break;
  //   }
  //   i++;
  // }

  const bytes = new Uint8Array(mem, charPtr, charLen);

  const string = new TextDecoder().decode(bytes);
  return string;
};

const readString = (ptr) => {
  if (mem == null) {
    console.error("mem is null");
    return;
  }

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
  if (mem == null) {
    console.error("mem is null");
    return;
  }

  const u32 = new Uint32Array(mem, address, 4);
  return u32[0];
};

const importObject = {
  debug: {
    log_panic(prefix, message, file, lineNumber) {
      console.error(
        `${readOdinString(prefix)}: ${readOdinString(message)}\n${readOdinString(file)}:${lineNumber}`,
      );
    },
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
  env: {
    sinf: (x) => Math.sin(x),
    cosf: (x) => Math.cos(x),
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
    clear: () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
    },
    measure_text: (strPtr) => {
      const text = readString(strPtr);
      return ctx.measureText(text).width;
    },
    fill: (r, g, b, a) => {
      // console.log("Fill", r, g, b, a);
      ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${a})`;
    },
    draw_rect: (x, y, w, h) => {
      // console.log("Rect", x, y, w, h);
      ctx.fillRect(x, y, w, h);
    },
    draw_text: (x, y, strPtr) => {
      const text = readString(strPtr);
      ctx.fillText(text, x, y);
    },
  },
};

let existingModule = null;

function startWasm(obj) {
  mem = obj.instance.exports.memory.buffer;
  obj.instance.exports.hello();
  existingModule = obj;
}
async function initWasm() {
  return WebAssembly.instantiateStreaming(
    fetch("odin-test.wasm"),
    importObject,
  ).then((obj) => {
    console.log("WASM INIT", obj.instance.exports);
    return obj;
  });
}

initWasm().then(startWasm);

function copyMem(from, to, fromAddr, toAddr, size) {
  console.info(`Copy ${size} bytes (${fromAddr} -> ${toAddr})`);
  const source = new Uint8Array(
    from.instance.exports.memory.buffer,
    fromAddr,
    size,
  );
  const dest = new Uint8Array(to.instance.exports.memory.buffer, toAddr, size);

  dest.set(source, 0);
}

const ws = new WebSocket("ws://localhost:8000");
ws.addEventListener("message", async () => {
  console.info("Websocket message received, rebooting wasm");

  if (existingModule == null) {
    console.warn("No module active, ignoring");
    return;
  }

  // Prevent the old module being used while we init
  const oldModule = existingModule;
  existingModule = null;

  const srcAddr = oldModule.instance.exports.get_state_ptr();
  const srcSize = oldModule.instance.exports.get_state_size();

  const newModule = await initWasm();

  const destAddr = newModule.instance.exports.get_state_ptr();
  const destSize = newModule.instance.exports.get_state_size();

  if (srcSize == destSize) {
    copyMem(oldModule, newModule, srcAddr, destAddr, destSize);
  } else {
    console.warn(`State size differs, not copying (${srcSize} -> ${destSize})`);
  }

  startWasm(newModule);
});

function frame(time) {
  if (existingModule != null) {
    existingModule.instance.exports.tick(0.016);
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

setTimeout(() => {
  ctx.font = "16px CompaqThin";
  ctx.imageSmoothingEnabled = false;
  ctx.fillText("hellooooo there 😂", 20, 20);
  console.log("Text measure", ctx.measureText("Hellooooooo there"));
}, 100);
