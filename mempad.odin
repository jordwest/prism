package prism

MemPadding :: struct {
    pad: [1024]u8
}

mempad_validate :: proc(padding: ^MemPadding) {
    for x := 0; x < len(padding.pad); x += 1 {
        if padding.pad[x] != 0 do unreachable()
    }
}
