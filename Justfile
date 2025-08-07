dev:
    deno --allow-read=. --allow-write=build --allow-net --allow-run devserver.js
clean:
    rm -rf build
optimize-wasm:
    wasm-opt build/web/assets/app.wasm -o build/web/assets/app-optimised.wasm -O3
    ls -la build/web/assets/*.wasm
