import { FresnelInstance, instantiate } from "./fresnel/instance";
import { FresnelState, Pointer } from "./fresnel/types";

let mem: ArrayBufferLike;

const canvas: HTMLCanvasElement = document.getElementById(
  "canvas",
)! as HTMLCanvasElement;
canvas.width = window.innerWidth;
canvas.height = window.innerHeight / 2;
const ctx = canvas.getContext("2d");

const readU32 = (address: Pointer) => {
  if (mem == null) {
    console.error("mem is null");
    return;
  }

  const u32 = new Uint32Array(mem, address, 4);
  return u32[0];
};

var messages = [];
var line = 0;
var metrics: Record<string, any> = {};

declare global {
  function getMetrics(): void;
}
window.getMetrics = () => {
  console.table(metrics);
};

let instance: FresnelInstance | null = null;

let state: FresnelState = {
  canvas,
  canvasContext: ctx!,
};

window.addEventListener("resize", () => {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight / 2;
  state.canvasContext.textBaseline = "top";
  instance?.exports.on_resize?.(canvas.width, canvas.height);
});

let pointerState = {
  x: 0,
  y: 0,
  down: false,
};

function sendMouseUpdate() {
  instance?.exports.on_mouse_update?.(
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

async function initWasm() {
  instance = await instantiate(state);
}

initWasm();

const ws = new WebSocket("ws://localhost:8000");

function frame(time) {
  if (instance != null) {
    try {
      instance.exports.tick(0.016);
    } catch (e) {
      console.error(`Crashed at line`, line);
      throw e;
    }
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

// TODO: Something more robust - gives the font time to load
setTimeout(() => {
  state.canvasContext.font = "16px CompaqThin";
  state.canvasContext.textBaseline = "top";
}, 100);
