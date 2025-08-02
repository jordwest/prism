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

var isBuilding = false;

async function onFileUpdate(event) {
  var odinFileUpdate = event.paths.find((p) => p.endsWith(".odin"));
  if (odinFileUpdate != null) {
    if (isBuilding) {
      console.warn("Already building");
      return;
    }
    isBuilding = true;
    console.log("run command");
    let cmd = new Deno.Command("odin", {
      args: ["build", ".", "-target:freestanding_wasm32"],
    });
    let { code, stdout, stderr } = await cmd.output();
    console.log("Return code", code);

    if (code === 0) {
      // var wasmFileUpdate = event.paths.find((p) => p.endsWith(".wasm"));
      for (var s of sockets) {
        s.send(JSON.stringify(odinFileUpdate));
      }
    } else {
      const outStr = new TextDecoder().decode(stdout);
      const outErr = new TextDecoder().decode(stderr);
      console.log(outStr, outErr);
    }
    isBuilding = false;
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
  console.log(">>>> event", event);
}
