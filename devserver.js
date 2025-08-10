/**
 * Global state
 **/
var runningCmds = new Set();

Deno.addSignalListener("SIGINT", () => {
  console.log("Shutting down");
  Deno.exit();
});

Deno.addSignalListener("SIGTERM", () => {
  console.log("Shutting down");
  Deno.exit();
});

Deno.serve(
  { hostname: "localhost", port: 8000, hostname: "0.0.0.0" },
  async (request) => {
    if (request.headers.get("upgrade") == "websocket") {
      return await handleWebsocket(request);
    }

    return await handleStaticFile(request);
  },
);

async function buildAll() {
  try {
    // Build everything
    await buildWebRunner();
    await buildWasm();
  } catch (e) {
    console.error(e);
  }
}

buildAll();

const sockets = [];

async function handleWebsocket(request) {
  const { socket, response } = Deno.upgradeWebSocket(request);

  socket.addEventListener("open", () => {
    console.log("🔌 WebSocket client connected");
    sockets.push(socket);
  });

  return response;
}

async function handleStaticFile(request) {
  const url = new URL(request.url);
  const filepath = decodeURIComponent(url.pathname);

  try {
    console.log("GET", filepath);
    const file = await Deno.open("./build/web" + filepath, { read: true });

    const response = new Response(file.readable);
    if (filepath.endsWith(".js")) {
      response.headers.set("Content-Type", "application/javascript");
    } else if (filepath.endsWith(".wasm")) {
      response.headers.set("Content-Type", "application/wasm");
    }
    return response;
  } catch {
    return new Response("404 Not Found", { status: 404 });
  }
}

async function buildCommand({ cmdKey, cmd, args, cwd }) {
  if (runningCmds.has(cmdKey)) {
    // Command already running, exit early
    return false;
  }

  runningCmds.add(cmdKey);

  console.log("⚙️ ========== ", cmdKey, " ==========");
  console.log("  🔄 ", cmd, args.join(" "));

  const t0 = performance.now();
  let process = new Deno.Command(cmd, { cwd, args });
  let { code, stdout, stderr } = await process.output();
  const t1 = performance.now();

  const codePrint = code === 0 ? "  ✅ " : `  🔴 ${code}`;
  console.log(codePrint, `${Number(t1 - t0).toFixed(2)}ms`);

  runningCmds.delete(cmdKey);

  if (code === 0) {
    return true;
  } else {
    const outStr = new TextDecoder().decode(stdout);
    const outErr = new TextDecoder().decode(stderr);
    console.log(outStr, outErr);
    throw new Error([outStr, outErr].join("\n"));
  }
}

async function buildWebRunner() {
  if (
    await buildCommand({
      cmdKey: "vite-build",
      cmd: "just",
      args: ["build-web-dev"],
    })
  ) {
    for await (var entry of Deno.readDir("./assets")) {
      if (entry.isFile) {
        Deno.copyFile(
          `./assets/${entry.name}`,
          `./build/web/assets/${entry.name}`,
        );
      }
    }
    return true;
  }

  return false;
}

async function buildWasm() {
  return await buildCommand({
    cmdKey: "wasm-build",
    cmd: "just",
    args: ["build-wasm-dev"],
    // cmd: "odin",
    // args: [
    //   "build",
    //   "src",
    //   // "-o:none",
    //   "-debug",
    //   "-source-code-locations:filename",
    //   "-target:freestanding_wasm32",
    //   "-out:build/web/assets/app.wasm",
    // ],
  });
}

// type HotUpdate = {"type": "webassembly"} | {"type": "host_source"} | {"type": "resource"}

function sendHotUpdate(data) {
  for (var s of sockets) {
    s.send(JSON.stringify(data));
  }
}

async function onFileUpdate(event) {
  var tsFileUpdate = event.paths.find(
    (p) =>
      (p.endsWith(".ts") ||
        p.endsWith(".html") ||
        p.endsWith(".css") ||
        p.endsWith(".mp3") ||
        p.endsWith(".ogg") ||
        p.endsWith(".json") ||
        p.endsWith(".png")) &&
      !p.includes("build/web"),
  );
  if (tsFileUpdate != null) {
    console.log("🌐 File changed: ", tsFileUpdate);
    if (await buildWebRunner()) {
      sendHotUpdate({ type: "host_source" });
    }
  }

  var odinFileUpdate = event.paths.find((p) => p.endsWith(".odin"));
  if (odinFileUpdate != null) {
    console.log("👾 File changed: ", odinFileUpdate);
    try {
      if (await buildWasm()) {
        sendHotUpdate({ type: "webassembly" });
      }
    } catch (e) {
      sendHotUpdate({ type: "webassembly", error: e.toString() });
    }
  }
}

// Watch for file changes and send wasm
const watcher = Deno.watchFs("./");
for await (const event of watcher) {
  onFileUpdate(event);
}
