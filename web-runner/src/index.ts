import { FresnelInstance, instantiate } from "./fresnel/instance";
import { FresnelState, ManifestJson, Pointer } from "./fresnel/types";

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
  if (e.key == "r") {
    restartWasm();
  }

  const actionId = state.input.keyToAction.get(e.key);
  setAction(actionId);
});

document.addEventListener("keyup", (e) => {
  const actionId = state.input.keyToAction.get(e.key);
  clearAction(actionId);
});

function setAction(actionId: number | undefined | null) {
  const instance = instances[focusedInstance];
  if (instance != null && actionId != null) {
    instance.input.pressedActions.add(actionId);
    instance.input.pressedActionsThisFrame.add(actionId);
  }
}

function clearAction(actionId: number | undefined | null) {
  const instance = instances[focusedInstance];
  if (instance != null && actionId != null) {
    instance.input.pressedActions.delete(actionId);
  }
}

canvas.addEventListener("mousedown", (e) => {
  e.preventDefault();
});

let instances: FresnelInstance[] = [];
let focusedInstance = 0;

let state: FresnelState = {
  canvas,
  canvasContext: ctx!,
  storage: {},
  mailboxes: new Map(),
  serverMailbox: [],
  images: {},
  input: {
    keyToAction: new Map(),
    mouseButtonToAction: new Map(),
  },
};

const loadResource = async (resourceId: number, filename: string) => {
  const response = await fetch(`assets/${filename}`);
  await addImage(resourceId, await response.blob());
};
const addImage = async (resourceId: number, data: Blob) => {
  state.images[resourceId] = await createImageBitmap(data);
};

fetch("assets/manifest.json").then(async (response) => {
  const manifest: ManifestJson = await response.json();
  for (var asset of manifest.assets) {
    loadResource(asset.id, asset.filename);
  }
  for (var action of manifest.input.actions) {
    if (action.webKeys != null) {
      action.webKeys.forEach((key) =>
        state.input.keyToAction.set(key, action.id),
      );
    }
    if (action.mouseButtons != null) {
      action.mouseButtons.forEach((btn) =>
        state.input.mouseButtonToAction.set(btn, action.id),
      );
    }
  }
});

window.addEventListener("resize", () => {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
  state.canvasContext.textBaseline = "top";
  state.canvasContext.imageSmoothingEnabled = false;

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
  if (instance != null) {
    focusedInstance = instance?.instanceId;
  }

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
  const actionId = state.input.mouseButtonToAction.get(evt.button);
  if (actionId != null) {
    evt.preventDefault();
    setAction(actionId);
  }
  sendMouseUpdate();
});
canvas.addEventListener("contextmenu", (evt) => {
  evt.preventDefault();
});
canvas.addEventListener("mouseup", (evt) => {
  pointerState.down = false;
  const actionId = state.input.mouseButtonToAction.get(evt.button);
  if (actionId != null) {
    clearAction(actionId);
  }
  sendMouseUpdate();
});

// Temp function for notifying instances of a "connection"
const notifyHostOfConnection = (clientId: number) => {
  const host = instances[0];
  if (host != null) {
    host.exports.on_client_connected?.(clientId);
  }
};

const delay = (ms: number) =>
  new Promise<void>((resolve) => setTimeout(() => resolve(), ms));
async function initWasm(instanceCount: number) {
  let height = 1 / instanceCount;
  for (var i = 0; i < instanceCount; i++) {
    console.log(
      `%c ✨ Starting fresnel instance ${i}`,
      "background-color: #990000; font-weight: bold; font-size: 16px; padding: 8px; display: block;",
    );
    const y = height * i;
    instances.push(await instantiate(state, i, { y, height }, i));
    await delay(100);
    notifyHostOfConnection(i + 1);
    await delay(5000);
  }
}
initWasm(2);

async function restartWasm() {
  // Flush all mailboxes so new instances don't receive messages from old instances...

  state.serverMailbox = [];
  for (var mb of state.mailboxes.keys()) {
    state.mailboxes.set(mb, []);
  }

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
}

const ws = new WebSocket("ws://localhost:8000");
ws.addEventListener("message", async (msg) => {
  console.info("Websocket message received, rebooting wasm");
  const data = JSON.parse(msg.data);
  if (data.type == "webassembly") {
    if (data.error != null) {
      console.error("Error compiling webassembly", data.error);
      errorSound.currentTime = 0;
      errorSound.play();
    } else {
      hotReloadSound.currentTime = 0;
      hotReloadSound.play();
      restartWasm();
    }
  } else if (data.type == "host_source") {
    window.location.reload();
  }
});

let lastT: DOMHighResTimeStamp | null = null;
const frame: FrameRequestCallback = (time) => {
  if (lastT != null && document.hasFocus()) {
    let t = (time - lastT) / 1000;
    t = Math.min(0.5, t);
    canvas.style.opacity = "";
    for (var instance of instances) {
      try {
        instance.exports.tick(t);
        instance.input.pressedActionsThisFrame.clear();
      } catch (e) {
        console.error(`Crashed at line`, line);
        throw e;
      }
    }

    const regionHeight = canvas.height / instances.length;

    state.canvasContext.strokeStyle = "#228";
    state.canvasContext.lineWidth = 4;

    state.canvasContext.strokeRect(
      0,
      focusedInstance * regionHeight,
      canvas.width,
      regionHeight,
    );
  } else {
    canvas.style.opacity = "30%";
  }

  lastT = time;

  requestAnimationFrame(frame);
};
requestAnimationFrame(frame);

// TODO: Something more robust - gives the font time to load
setTimeout(() => {
  state.canvasContext.font = "16px CompaqThin";
  state.canvasContext.textBaseline = "top";
  state.canvasContext.imageSmoothingEnabled = false;
}, 100);

const audioElement = document.createElement("audio");
const errorSound = document.createElement("audio");
const audioElement3 = document.createElement("audio");
const hotReloadSound = document.createElement("audio");
function audioTest() {
  document.body.appendChild(audioElement);
  const audioContext = new AudioContext();
  audioElement.src = "/assets/Daudir.mp3";
  errorSound.src = "/assets/miss.ogg";
  audioElement3.src = "/assets/ambience.mp3";
  hotReloadSound.src = "/assets/punch.wav";
  audioElement3.loop = true;
  const track = audioContext.createMediaElementSource(audioElement);
  track.connect(audioContext.destination);
  const track2 = audioContext.createMediaElementSource(audioElement);
  track2.connect(audioContext.destination);
  const track3 = audioContext.createMediaElementSource(audioElement);
  track3.connect(audioContext.destination);
  const track4 = audioContext.createMediaElementSource(audioElement);
  track4.connect(audioContext.destination);
}
audioTest();

canvas.addEventListener("mousedown", () => {
  // audioElement.play();
  // if (errorSound.currentTime != 0) {
  //   errorSound.currentTime = 0;
  // }
  // errorSound.play();
  audioElement3.play();
  // hotReloadSound.play();
});
