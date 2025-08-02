/** @type ArrayBufferLike */
let mem;

const canvas = document.getElementById("canvas");
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;
const ctx = canvas.getContext("2d");

const readOdinString = (ptr) => {
  if (mem == null) {
    console.error("mem is null");
    return;
  }

  const data = new DataView(mem);
  const charPtr = data.getInt32(ptr, true);
  const charLen = data.getInt32(ptr + 4, true);

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

var messages = [];
var line = 0;
var metrics = {};

window.getMetrics = () => {
  console.table(metrics);
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
    record_line(num) {
      line = num;
    },
    metric_i32(name, num) {
      metrics[readOdinString(name)] = num;
    },
    log_pointer(ptr, size) {
      const arr = new Uint8Array(mem, ptr, size);
      // Blah

      console.warn("👉 Pointer at ", ptr, " size ", size, arr);

      const nextPtr = readU32(ptr);
      if (nextPtr < mem.byteLength) {
        const nextArr = new Uint8Array(mem, nextPtr, size);

        console.warn("👉", nextPtr, nextArr);

        var chars = [];

        for (var b of nextArr) {
          if (b >= 32 && b <= 126) {
            chars.push(String.fromCharCode(b));
          } else {
            chars.push("0x" + b.toString(16).padStart(2, "0"));
          }
        }

        console.info(chars.join(" "));
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
    print: (ptr, lvl) => {
      const s = readOdinString(ptr);
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
      ctx.clearRect(0, 0, canvas.width, canvas.height);
    },
    measure_text: (size, strPtr) => {
      const text = readString(strPtr);
      ctx.font = `${size}px CompaqThin`;
      return ctx.measureText(text).width;
    },
    fill: (r, g, b, a) => {
      ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${a})`;
    },
    draw_rect: (x, y, w, h) => {
      ctx.fillRect(x, y, w, h);
    },
    draw_text: (x, y, size, strPtr) => {
      const text = readString(strPtr);
      ctx.font = `${size}px CompaqThin`;
      ctx.fillText(text, x, y);
    },
    client_send_message: (msgPtr, size) => {
      const messageContent = new Uint8Array(mem, msgPtr, size);
      messages.push(messageContent.slice());
      console.log(`Message queue has ${messages.length} messages`);
      return 1;
    },
    client_poll_message: (msgPtr, size) => {
      const message = messages.shift();
      if (message == null) {
        return 0;
      }

      if (message.length !== size) {
        return 0;
      }

      const memView = new Uint8Array(mem, msgPtr, size);
      console.log(memView);

      memView.set(message);
      return size;
    },
  },
};

let existingModule = null;

window.addEventListener("resize", () => {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
  ctx.textBaseline = "top";
  if (existingModule != null) {
    existingModule.instance.exports.on_resize(canvas.width, canvas.height);
  }
});

let pointerState = {
  x: 0,
  y: 0,
  down: false,
};

function sendMouseUpdate() {
  existingModule.instance.exports.on_mouse_update(
    pointerState.x,
    pointerState.y,
    pointerState.down,
  );
}
canvas.addEventListener("mousemove", (evt) => {
  pointerState.x = evt.offsetX;
  pointerState.y = evt.offsetY;
  sendMouseUpdate();
});
canvas.addEventListener("mousedown", (evt) => {
  pointerState.down = true;
  sendMouseUpdate();
});
canvas.addEventListener("mouseup", (evt) => {
  pointerState.down = false;
  sendMouseUpdate();
});

function startWasm(obj) {
  mem = obj.instance.exports.memory.buffer;
  obj.instance.exports.hello(canvas.width, canvas.height);
  existingModule = obj;
}
async function initWasm() {
  return WebAssembly.instantiateStreaming(
    fetch("odin-test.wasm"),
    // fetch("optimized.wasm"),
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
    try {
      existingModule.instance.exports.tick(0.016);
    } catch (e) {
      console.error(`Crashed at line`, line);
      throw e;
    }
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

setTimeout(() => {
  ctx.font = "16px CompaqThin";
  ctx.textBaseline = "top";
}, 100);
