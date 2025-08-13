import { FresnelInstance, instantiate } from "./fresnel/instance";
import {
  AssetType,
  ClientId,
  FresnelState,
  Mailbox,
  ManifestJson,
  Pointer,
} from "./fresnel/types";

export const INSTANCES = 2;
export const NET_FAKE_DELAY = 0;

const canvas: HTMLCanvasElement = document.getElementById(
  "canvas",
)! as HTMLCanvasElement;
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;
const ctx = canvas.getContext("2d");

let state: FresnelState = {
  canvas,
  canvasContext: ctx!,
  storage: {},
  instances: [],
  clients: new Map(),
  nextClientId: 100 as ClientId,
  focusedInstance: 0,
  listeningServerId: null,
  font: 'sans-serif',
  serverMailbox: [],
  assets: {},
  audioContext: new AudioContext(),
  input: {
    keyToAction: new Map(),
    mouseButtonToAction: new Map(),
  },
};

var line = 0;
var metrics: Record<string, any> = {};

document.addEventListener("keydown", (e) => {
  if (e.key == "`") {
    console.group(`Metrics at ${performance.now() / 1000}`);
    for (var i = 0; i < state.instances.length; i++) {
      console.group(`Instance ${i}`);
      console.table(state.instances[i]?.metrics);
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
  const instance = state.instances[state.focusedInstance];
  if (instance != null && actionId != null) {
    instance.input.pressedActions.add(actionId);
    instance.input.pressedActionsThisFrame.add(actionId);
  }
}

function clearAction(actionId: number | undefined | null) {
  const instance = state.instances[state.focusedInstance];
  if (instance != null && actionId != null) {
    instance.input.pressedActions.delete(actionId);
  }
}

canvas.addEventListener("mousedown", (e) => {
  e.preventDefault();
});

const loadResource = async (
  resourceId: number,
  filename: string,
  type: AssetType,
) => {
  if (type == "image") {
    const response = await fetch(`assets/${filename}`);
    await addImage(resourceId, await response.blob());
  } else if (type == "audio") {
    addAudio(resourceId, `assets/${filename}`);
  }
};
const addImage = async (resourceId: number, data: Blob) => {
  state.assets[resourceId] = {
    type: "image",
    image: await createImageBitmap(data),
  };
};
const addAudio = (resourceId: number, filename: string) => {
  const audioElement = document.createElement("audio");
  audioElement.src = filename;
  document.body.appendChild(audioElement);

  const track = state.audioContext.createMediaElementSource(audioElement);
  track.connect(state.audioContext.destination);

  state.assets[resourceId] = {
    type: "audio",
    audioElement,
  };
};

fetch("assets/manifest.json").then(async (response) => {
  const manifest: ManifestJson = await response.json();
  for (var asset of manifest.assets) {
    loadResource(asset.id, asset.filename, asset.type);
  }
  state.font = manifest.font;
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

  for (var i = 0; i < state.instances.length; i++) {
    const instance = state.instances[i];
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

function getRegionCoord(
  y: number,
): { instanceId: number; regionY: number } | null {
  const yPct = y / canvas.height;
  for (var i = 0; i < state.instances.length; i++) {
    const region = state.instances[i]!.region;
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

  const regionCoord = getRegionCoord(pointerState.y);
  if (regionCoord == null) return;
  const instance = state.instances[regionCoord.instanceId];
  if (instance != null) {
    state.focusedInstance = instance?.instanceId;
  }

  instance?.exports.on_mouse_move?.(
    pointerState.x,
    regionCoord.regionY,
    pointerState.down,
  );
});
canvas.addEventListener("mousedown", (evt) => {
  pointerState.down = true;
  const actionId = state.input.mouseButtonToAction.get(evt.button);
  if (actionId != null) {
    evt.preventDefault();
    setAction(actionId);
  }

  const regionCoord = getRegionCoord(pointerState.y);
  if (regionCoord == null) return;
  const instance = state.instances[regionCoord.instanceId];
  instance?.exports.on_mouse_button?.(
    pointerState.x,
    regionCoord.regionY,
    true,
    evt.button,
  );
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

  const regionCoord = getRegionCoord(pointerState.y);
  if (regionCoord == null) return;
  const instance = state.instances[regionCoord.instanceId];
  instance?.exports.on_mouse_button?.(
    pointerState.x,
    regionCoord.regionY,
    false,
    evt.button,
  );
});

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
    const newInstance = await instantiate(state, i, { y, height }, i);
    state.instances.push(newInstance);
    newInstance.exports.boot(
      state.canvas.width,
      state.canvas.height * newInstance.region.height,
      i,
    );
    await delay(100);
  }
}
// initWasm(2);
initWasm(INSTANCES);

async function restartWasm() {
  // Flush all mailboxes so new instances don't receive messages from old instances...

  state.serverMailbox = [];
  state.listeningServerId = null;

  let height = 1 / state.instances.length;
  for (var i = 0; i < state.instances.length; i++) {
    const instance = state.instances[i];

    if (instance != null) {
      // Notify old instance we're shutting down
      instance.exports.on_dev_hot_unload?.();
    }

    console.log(
      `%c 🔄 Hot reload fresnel instance ${i}`,
      "background-color: #994400; font-weight: bold; font-size: 16px; padding: 8px; display: block;",
    );

    const y = height * i;
    const newInstance = await instantiate(state, i, { y, height });
    state.instances[i] = newInstance;
    newInstance.exports.boot(
      state.canvas.width,
      state.canvas.height * newInstance.region.height,
      i,
    );
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
    for (var instance of state.instances) {
      try {
        instance.exports.tick(t);
        instance.input.pressedActionsThisFrame.clear();
      } catch (e) {
        console.error(`Crashed at line`, line);
        throw e;
      }
    }

    const regionHeight = canvas.height / state.instances.length;

    state.canvasContext.strokeStyle = "#228";
    state.canvasContext.lineWidth = 4;

    state.canvasContext.strokeRect(
      0,
      state.focusedInstance * regionHeight,
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
  const track2 = audioContext.createMediaElementSource(errorSound);
  track2.connect(audioContext.destination);
  const track3 = audioContext.createMediaElementSource(audioElement3);
  track3.connect(audioContext.destination);
  const track4 = audioContext.createMediaElementSource(hotReloadSound);
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
