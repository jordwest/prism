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

document.addEventListener("keydown", (e) => {
  if (e.key == "`") {
    console.group(`Metrics at ${performance.now() / 1000}`);
    for (var i = 0; i < instances.length; i++) {
      console.group(`Instance ${i}`);
      console.table(instances[i]?.metrics);
      console.groupEnd();
    }
    console.groupEnd();
  }
});

let instances: FresnelInstance[] = [];

let state: FresnelState = {
  canvas,
  canvasContext: ctx!,
  storage: {},
  mailboxes: {},
  serverMailbox: [],
  images: {},
};

const loadResource = async (resourceId: number, filename: string) => {
  const response = await fetch(`assets/${filename}`);
  await addImage(resourceId, await response.blob());
};
const addImage = async (resourceId: number, data: Blob) => {
  state.images[resourceId] = await createImageBitmap(data);
};

fetch("assets/manifest.json").then(async (response) => {
  const manifest = await response.json();
  for (var asset of manifest.assets) {
    loadResource(asset.id, asset.filename);
  }
});

window.addEventListener("resize", () => {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
  state.canvasContext.textBaseline = "top";

  for (var i = 0; i < instances.length; i++) {
    const instance = instances[i];
    instance?.exports.on_resize?.(
      canvas.width,
      canvas.height * instance!.region.height,
    );
  }
});

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

// Temp function for notifying instances of a "connection"
const notifyHostOfConnection = (clientId: number) => {
  const host = instances[0];
  if (host != null) {
    host.exports.on_client_connected?.(clientId);
  }
};

async function initWasm(instanceCount: number) {
  let height = 1 / instanceCount;
  for (var i = 0; i < instanceCount; i++) {
    console.log(
      `%c ✨ Starting fresnel instance ${i}`,
      "background-color: #990000; font-weight: bold; font-size: 16px; padding: 8px; display: block;",
    );
    const y = height * i;
    instances.push(await instantiate(state, i, { y, height }, i));
    notifyHostOfConnection(i + 1);
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
      `%c 🔄 Hot reload fresnel instance ${i}`,
      "background-color: #994400; font-weight: bold; font-size: 16px; padding: 8px; display: block;",
    );

    const y = height * i;
    instances[i] = await instantiate(state, i, { y, height }, i);
    notifyHostOfConnection(i + 1);
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
  state.canvasContext.imageSmoothingEnabled = false;
}, 100);
