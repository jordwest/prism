use tinywasm::{Extern, Imports, MemoryRef, Module, Store};

fn main() {
    start_wasm().unwrap();
}

fn log_panic(_ctx: tinywasm::FuncContext<'_>, args: (i32, i32, i32, i32)) -> tinywasm::Result<()> {
    println!("Module panic on line {}", args.3);
    Ok(())
}

fn test_assert(_ctx: tinywasm::FuncContext<'_>, args: (i32, i32)) -> tinywasm::Result<()> {
    let mem_ref = _ctx.exported_memory("memory")?;

    let pass = args.0 == 1;
    let msg_ptr = args.1;

    let msg = read_string_slice(mem_ref, msg_ptr);

    let pass_icon = match pass {
        true => "✅",
        false => "🔴",
    };

    println!("{} {}", pass_icon, msg);
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

fn dummy_i32(_ctx: tinywasm::FuncContext<'_>, _: ()) -> tinywasm::Result<i32> {
    Ok(0)
}

fn dummy_i32_i32_i32(_ctx: tinywasm::FuncContext<'_>, _: (i32, i32)) -> tinywasm::Result<i32> {
    Ok(0)
}

fn dummy_i32_void(_ctx: tinywasm::FuncContext<'_>, a: i32) -> tinywasm::Result<()> {
    println!("({}: i32) -> void", a);
    Ok(())
}

fn dummy_strptr_void(_ctx: tinywasm::FuncContext<'_>, strptr: i32) -> tinywasm::Result<()> {
    let mem_ref = _ctx.exported_memory("memory")?;
    println!("=== {} ===", read_string_slice(mem_ref, strptr));
    return Ok(());
}

fn read_string_slice(mem_ref: MemoryRef, ptr: i32) -> String {
    let slice = mem_ref.load(ptr as usize, 8).unwrap();
    let ptr: u32 = u32::from_le_bytes(slice[0..4].try_into().unwrap());
    let len: u32 = u32::from_le_bytes(slice[4..8].try_into().unwrap());

    let str_bytes = mem_ref.load(ptr as usize, len as usize).unwrap();
    let string = str::from_utf8(str_bytes).unwrap();
    return string.to_string();
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
        .define("debug", "test_case", Extern::typed_func(dummy_strptr_void))?
        .define("debug", "test_report", Extern::typed_func(dummy_i32))?
        .define("debug", "test_complete", Extern::typed_func(dummy_i32_void))?
        .define(
            "input",
            "is_action_pressed",
            Extern::typed_func(dummy_i32_i32),
        )?
        .define(
            "input",
            "is_action_just_pressed",
            Extern::typed_func(dummy_i32_i32),
        )?
        .define("debug", "test_assert", Extern::typed_func(test_assert))?
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
    let test = instance
        .exported_func::<(), ()>(&mut store, "tests")
        .expect("export test");

    let _ = test.call(&mut store, ()).expect("call test");
    // let _ = boot.call(&mut store, (800, 600, 0)).expect("call boot");
    // let _ = tick.call(&mut store, (0.016)).expect("call tick");

    Ok(())
}
