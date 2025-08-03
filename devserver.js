Deno.addSignalListener("SIGINT", () => {
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

const sockets = [];

async function handleWebsocket(request) {
  const { socket, response } = Deno.upgradeWebSocket(request);

  socket.addEventListener("open", () => {
    console.log("a client connected!");
    sockets.push(socket);
  });

  return response;
}

async function handleStaticFile(request) {
  const url = new URL(request.url);
  const filepath = decodeURIComponent(url.pathname);

  try {
    const file = await Deno.open("." + filepath, { read: true });

    const response = new Response(file.readable);
    if (filepath.endsWith(".wasm")) {
      response.headers.set("Content-Type", "application/wasm");
    }
    return response;
  } catch {
    return new Response("404 Not Found", { status: 404 });
  }
}

var runningCmds = new Set();

async function buildCommand({ cmdKey, cmd, args, cwd }) {
  if (runningCmds.has(cmdKey)) {
    // Command already running, exit early
    return false;
  }

  runningCmds.add(cmdKey);

  console.log("⚙️ ", cmdKey);
  console.log("  🔄 ", cmd, args.join(" "));

  let process = new Deno.Command(cmd, { cwd, args });
  let { code, stdout, stderr } = await process.output();

  const codePrint = code === 0 ? "  ✅ " : `  ❌ ${code}`;
  console.log(codePrint, cmd, args.join(" "));

  runningCmds.delete(cmdKey);

  if (code === 0) {
    return true;
  } else {
    const outStr = new TextDecoder().decode(stdout);
    const outErr = new TextDecoder().decode(stderr);
    console.log(outStr, outErr);
    return false;
  }
}

async function onFileUpdate(event) {
  var tsFileUpdate = event.paths.find((p) => p.endsWith(".ts"));
  if (tsFileUpdate != null) {
    await buildCommand({
      cmdKey: "vite-build",
      cmd: "npx",
      cwd: "web-runner",
      args: ["vite", "build", ".", "--outDir", "../build/web"],
    });
  }

  var odinFileUpdate = event.paths.find((p) => p.endsWith(".odin"));
  if (odinFileUpdate != null) {
    if (
      await buildCommand({
        cmdKey: "wasm-build",
        cmd: "odin",
        args: [
          "build",
          ".",
          "-target:freestanding_wasm32",
          "-out:build/web/assets/app.wasm",
        ],
      })
    ) {
      for (var s of sockets) {
        s.send(JSON.stringify(odinFileUpdate));
      }
    }
  }
}

// Watch for file changes and send wasm
const watcher = Deno.watchFs("./");
for await (const event of watcher) {
  onFileUpdate(event);

  // var wasmFileUpdate = event.paths.find((p) => p.endsWith(".wasm"));
  // if (wasmFileUpdate != null) {
  //   for (var s of sockets) {
  //     s.send(JSON.stringify(wasmFileUpdate));
  //   }
  // }
}
