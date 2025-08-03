import { FresnelInstance, instantiate } from "./fresnel/instance";
import { FresnelState, Pointer } from "./fresnel/types";

const canvas: HTMLCanvasElement = document.getElementById(
  "canvas",
)! as HTMLCanvasElement;
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;
const ctx = canvas.getContext("2d");

var line = 0;
var metrics: Record<string, any> = {};

declare global {
  function getMetrics(): void;
}
window.getMetrics = () => {
  console.table(metrics);
};

// let instance: FresnelInstance | null = null;
let instances: FresnelInstance[] = [];

let state: FresnelState = {
  canvas,
  canvasContext: ctx!,
  storage: {},
};

// window.addEventListener("resize", () => {
//   canvas.width = window.innerWidth;
//   canvas.height = window.innerHeight / 2;
//   state.canvasContext.textBaseline = "top";
//   instance?.exports.on_resize?.(canvas.width, canvas.height);
// });

let pointerState = {
  x: 0,
  y: 0,
  down: false,
};

function sendMouseUpdate() {
  const regionCoord = getRegionCoord(pointerState.y);
  if (regionCoord == null) return;
  const instance = instances[regionCoord.instanceId];
  instance?.exports.on_mouse_update?.(
    pointerState.x,
    regionCoord.regionY,
    pointerState.down,
  );
}

function getRegionCoord(
  y: number,
): { instanceId: number; regionY: number } | null {
  const yPct = y / canvas.height;
  for (var i = 0; i < instances.length; i++) {
    const region = instances[i]!.region;
    const scale = canvas.height;
    if (yPct > region.y && yPct < region.y + region.height) {
      return { instanceId: i, regionY: (yPct - region.y) * scale };
    }
  }

  return null;
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

async function initWasm(instanceCount: number) {
  let height = 1 / instanceCount;
  for (var i = 0; i < instanceCount; i++) {
    console.log(
      `%c Starting fresnel instance ${i}`,
      "background-color: #990000; font-weight: bold; font-size: 16px; padding: 8px; display: block;",
    );
    const y = height * i;
    instances.push(await instantiate(state, i, { y, height }));
  }
}
initWasm(2);

const ws = new WebSocket("ws://localhost:8000");
ws.addEventListener("message", async () => {
  console.info("Websocket message received, rebooting wasm");

  let height = 1 / instances.length;
  for (var i = 0; i < instances.length; i++) {
    const instance = instances[i];

    if (instance != null) {
      // Notify old instance we're shutting down
      instance.exports.on_dev_hot_unload?.();
    }

    console.log(
      `%c Hot reload fresnel instance ${i}`,
      "background-color: #994400; font-weight: bold; font-size: 16px; padding: 8px; display: block;",
    );

    const y = height * i;
    instances[i] = await instantiate(state, i, { y, height });
  }
});

const frame: FrameRequestCallback = (time) => {
  for (var instance of instances) {
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
