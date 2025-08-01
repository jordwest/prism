Deno.addSignalListener("SIGINT", () => {
  console.log("Shutting down");
  Deno.exit();
});

Deno.serve({ hostname: "localhost", port: 8000 }, async (request) => {
  if (request.headers.get("upgrade") == "websocket") {
    return await handleWebsocket(request);
  }

  return await handleStaticFile(request);
});

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

// Watch for file changes and send wasm
const watcher = Deno.watchFs("./");
for await (const event of watcher) {
  for (var s of sockets) {
    var wasmFileUpdate = event.paths.find((p) => p.endsWith(".wasm"));
    if (wasmFileUpdate != null) {
      s.send(JSON.stringify(wasmFileUpdate));
    }
  }
  console.log(">>>> event", event);
}
