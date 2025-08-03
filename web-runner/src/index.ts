import { FresnelInstance, instantiate } from "./fresnel/instance";
import { FresnelState, Pointer } from "./fresnel/types";

const canvas: HTMLCanvasElement = document.getElementById(
  "canvas",
)! as HTMLCanvasElement;
canvas.width = window.innerWidth;
canvas.height = window.innerHeight / 2;
const ctx = canvas.getContext("2d");

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
  storage: {},
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
  console.log(
    "%c Starting fresnel instance",
    "background-color: #990000; font-weight: bold; font-size: 16px; padding: 8px; display: block;",
  );
  instance = await instantiate(state);
}
initWasm();

const ws = new WebSocket("ws://localhost:8000");
ws.addEventListener("message", async () => {
  console.info("Websocket message received, rebooting wasm");

  if (instance != null) {
    // Notify old instance we're shutting down
    instance.exports.on_dev_hot_unload?.();
  }

  console.log(
    "%c Hot reloading fresnel instance",
    "background-color: #994400; font-weight: bold; font-size: 16px; padding: 8px; display: block;",
  );
  instance = await instantiate(state);
});

const frame: FrameRequestCallback = (time) => {
  if (instance != null) {
    try {
      instance.exports.tick(0.016);
    } catch (e) {
      console.error(`Crashed at line`, line);
      throw e;
    }
  }
  requestAnimationFrame(frame);
};
requestAnimationFrame(frame);

// TODO: Something more robust - gives the font time to load
setTimeout(() => {
  state.canvasContext.font = "16px CompaqThin";
  state.canvasContext.textBaseline = "top";
}, 100);
