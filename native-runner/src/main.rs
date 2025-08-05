use tinywasm::{Extern, Imports, Module, Store};

fn main() {
    start_wasm().unwrap();
}

fn log_panic(_ctx: tinywasm::FuncContext<'_>, args: (i32, i32, i32, i32)) -> tinywasm::Result<()> {
    println!("Module panic on line {}", args.3);
    Ok(())
}

fn dummy_f32_f32_f32_f32_void(
    _ctx: tinywasm::FuncContext<'_>,
    _: (f32, f32, f32, f32),
) -> tinywasm::Result<()> {
    Ok(())
}

fn dummy_f32_f32_i32_i32_void(
    _ctx: tinywasm::FuncContext<'_>,
    _: (f32, f32, i32, i32),
) -> tinywasm::Result<()> {
    Ok(())
}

fn dummy_i32_i32_void(_ctx: tinywasm::FuncContext<'_>, args: (i32, i32)) -> tinywasm::Result<()> {
    println!("(i32 = {}, i32 = {}) -> void", args.0, args.1);
    Ok(())
}

fn dummy_i32_i32(_ctx: tinywasm::FuncContext<'_>, _: i32) -> tinywasm::Result<i32> {
    Ok(0)
}

fn dummy_i32_i32_i32(_ctx: tinywasm::FuncContext<'_>, _: (i32, i32)) -> tinywasm::Result<i32> {
    Ok(0)
}

fn dummy_i32_void(_ctx: tinywasm::FuncContext<'_>, _: i32) -> tinywasm::Result<()> {
    println!("i32 -> void");
    Ok(())
}

fn dummy_f32_f32(_ctx: tinywasm::FuncContext<'_>, _: f32) -> tinywasm::Result<f32> {
    Ok(1.0)
}

fn dummy_void(_ctx: tinywasm::FuncContext<'_>, _: ()) -> tinywasm::Result<()> {
    Ok(())
}

fn draw_rect(
    ctx: tinywasm::FuncContext<'_>,
    (x, y, w, h): (f32, f32, f32, f32),
) -> tinywasm::Result<()> {
    // ctx.module().memory(ctx.store(), 0);
    println!("Draw rect at {}, {} size {}, {}", x, y, w, h);
    Ok(())
}

fn start_wasm() -> tinywasm::Result<()> {
    // Load a module from bytes
    let wasm = include_bytes!("../../build/web/assets/app.wasm");
    let module = Module::parse_bytes(wasm)?;

    let mut imports = Imports::new();

    let dummy_0_i32 = Extern::typed_func(
        |_ctx: tinywasm::FuncContext<'_>, ()| -> tinywasm::Result<i32> { Ok(0) },
    );

    imports
        .define("debug", "now", dummy_0_i32.clone())?
        .define("core", "draw_image", Extern::typed_func(dummy_i32_void))?
        .define(
            "debug",
            "metric_i32",
            Extern::typed_func(dummy_i32_i32_void),
        )?
        .define("core", "print", Extern::typed_func(dummy_i32_i32_void))?
        .define("core", "clear", Extern::typed_func(dummy_void))?
        .define(
            "core",
            "fill",
            Extern::typed_func(dummy_f32_f32_f32_f32_void),
        )?
        .define("core", "draw_rect", Extern::typed_func(draw_rect))?
        .define(
            "core",
            "measure_text",
            Extern::typed_func(dummy_i32_i32_i32),
        )?
        .define(
            "core",
            "draw_text",
            Extern::typed_func(dummy_f32_f32_i32_i32_void),
        )?
        .define(
            "core",
            "fill_slice_random",
            Extern::typed_func(dummy_i32_void),
        )?
        .define(
            "net",
            "client_poll_message",
            Extern::typed_func(dummy_i32_i32),
        )?
        .define(
            "net",
            "server_poll_message",
            Extern::typed_func(dummy_i32_i32_i32),
        )?
        .define(
            "net",
            "client_send_message",
            Extern::typed_func(dummy_i32_i32),
        )?
        .define(
            "net",
            "server_send_message",
            Extern::typed_func(dummy_i32_i32_i32),
        )?
        .define(
            "net",
            "server_broadcast_message",
            Extern::typed_func(dummy_i32_i32),
        )?
        .define("core", "storage_get", Extern::typed_func(dummy_i32_i32_i32))?
        .define(
            "core",
            "storage_set",
            Extern::typed_func(dummy_i32_i32_void),
        )?
        .define("env", "sinf", Extern::typed_func(dummy_f32_f32))?
        .define("env", "cosf", Extern::typed_func(dummy_f32_f32))?
        .define("debug", "log_panic", Extern::typed_func(log_panic))?;

    // Create a new store
    // Stores are used to allocate objects like functions and globals
    let mut store = Store::default();

    // Instantiate the module
    // This will allocate the module and its globals into the store
    // and execute the module's start function.
    // Every ModuleInstance has its own ID space for functions, globals, etc.
    let instance = module.instantiate(&mut store, Some(imports))?;

    // Get a typed handle to the exported "add" function
    // Alternatively, you can use `instance.get_func` to get an untyped handle
    // that takes and returns [`WasmValue`]s
    let boot = instance
        .exported_func::<(i32, i32, i32), ()>(&mut store, "boot")
        .expect("export boot");
    let tick = instance
        .exported_func::<(f32), ()>(&mut store, "tick")
        .expect("export tick");

    let _ = boot.call(&mut store, (800, 600, 0)).expect("call boot");
    let _ = tick.call(&mut store, (0.016)).expect("call tick");

    Ok(())
}
