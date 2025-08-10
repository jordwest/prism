dev:
    deno --allow-read=. --allow-write=build --allow-net --allow-run devserver.js
clean:
    rm -rf build
optimize-wasm:
    wasm-opt build/web/assets/app.wasm -o build/web/assets/app-optimised.wasm -O4
    ls -la "" build/web/assets/*.wasm
build-wasm-dev:
    odin build src -debug -source-code-locations:filename -target:freestanding_wasm32 -out:build/web/assets/app.wasm
    ls -la -D "" build/web/assets > .dev.asset-sizes
build-wasm-release:
    odin build src -source-code-locations:filename -target:freestanding_wasm32 -out:build/web/assets/app.wasm
    wasm-opt build/web/assets/app.wasm -o build/web/assets/app.wasm -O3
    ls -la -D build/web/assets > .release.asset-sizes
