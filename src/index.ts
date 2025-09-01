import { isCommaListExpression } from "typescript";
import { FresnelInstance, instantiate } from "./fresnel/instance";
import {
  AssetType,
  FresnelState,
  ManifestJson,
  Pointer,
} from "./fresnel/types";

export const INSTANCES = 1;
export const NET_FAKE_DELAY = 250;
export const WS_RELAY = "wss://relay.curious.garden";
// export const WS_RELAY = "ws://localhost:3524";

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
  focusedInstance: 0,
  listeningServerId: null,
  font: 'sans-serif',
  assets: {},
  audioContext: new AudioContext(),
  audio: {
    bufferedUpToTime: 0,
    sampleRate: 16769
  },
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

  const actionIds = state.input.keyToAction.get(e.key);
  actionIds?.forEach(id => setAction(id))
});

document.addEventListener("keyup", (e) => {
  const actionIds = state.input.keyToAction.get(e.key);
  actionIds?.forEach(id => clearAction(id))
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
      action.webKeys.forEach((key) => {
        const actionIds = state.input.keyToAction.get(key) ?? [];
        actionIds.push(action.id)
        state.input.keyToAction.set(key, actionIds)
      });
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
  handleMouseDown(evt)
});
canvas.addEventListener("touchstart", (evt) => {
  const bound = (evt.target! as HTMLCanvasElement).getBoundingClientRect();
  handleMouseDown({
    preventDefault: () => evt.preventDefault,
    button: 0,
    offsetX: evt.targetTouches[0]!.clientX - bound.x,
    offsetY: evt.targetTouches[0]!.clientY - bound.y,
  })
});
canvas.addEventListener("touchend", (evt) => {
  console.log("TOUCHEND")
  evt.preventDefault();

  pointerState.down = false;
  const actionId = state.input.mouseButtonToAction.get(0);
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
    0,
  );
});
function handleMouseDown(evt: { button: number, offsetX: number, offsetY: number, preventDefault: () => void }) {
  pointerState.down = true;
  pointerState.x = evt.offsetX;
  pointerState.y = evt.offsetY;

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
}

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
    const newInstance = await instantiate(state, i, { y, height });
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

  state.listeningServerId = null;

  let height = 1 / state.instances.length;
  for (var i = 0; i < state.instances.length; i++) {
    const instance = state.instances[i];

    if (instance != null) {
      // Notify old instance we're shutting down
      instance.exports.on_dev_hot_unload?.();

      // Remove input
      instance.input.inputBoxState.element.parentElement!.removeChild(instance.input.inputBoxState.element)
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

if (window.location.hostname === 'localhost') {
  const ws = new WebSocket("ws://localhost:8000");
  ws.addEventListener("message", async (msg) => {
    console.info("Websocket message received, rebooting wasm");
    const data = JSON.parse(msg.data);
    if (data.type == "webassembly") {
      if (data.error != null) {
        console.error("Error compiling webassembly", data.error);
      } else {
        restartWasm();
      }
    } else if (data.type == "host_source") {
      window.location.reload();
    }
  });
}

let lastT: DOMHighResTimeStamp | null = null;

const frame: FrameRequestCallback = (time) => {
  if (lastT != null) {
    let t = (time - lastT) / 1000;

    // Disabled for now because itch.io seems to trigger this all the time
    // if (!document.hasFocus() && t < 0.1) {
    //   // Tick less frequently when not active
    //   requestAnimationFrame(frame);
    //   return;
    // }

    t = Math.min(0.5, t);
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

    if (INSTANCES > 1) {
      state.canvasContext.strokeStyle = "#228";
      state.canvasContext.lineWidth = 4;

      state.canvasContext.strokeRect(
        0,
        state.focusedInstance * regionHeight,
        canvas.width,
        regionHeight,
      );
    }
  }
  // Disabled for now because itch.io seems to trigger this all the time
  // canvas.style.opacity = document.hasFocus() ? "" : "30%";

  lastT = time;

  requestAnimationFrame(frame);
};
requestAnimationFrame(frame);

// TODO: Something more robust - gives the font time to load
setTimeout(() => {
  state.canvasContext.textBaseline = "top";
  state.canvasContext.imageSmoothingEnabled = false;
}, 100);

function audioTest() {
  const audioContext = new AudioContext();
}
audioTest();

canvas.addEventListener("mousedown", () => {
  window.focus();
  state.audioContext.resume()
});

setInterval(() => {
  if (state.instances[0]?.exports.request_audio != null) {
    const samplesBuffered = (state.audio.bufferedUpToTime - state.audioContext.currentTime) * state.audio.sampleRate;
    if (samplesBuffered < 512) {
      state.instances[0].exports.request_audio(512);
    }
  }
}, 1);
