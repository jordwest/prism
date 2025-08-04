package fresnel

import "base:runtime"
import "core:fmt"

line :: proc(loc: runtime.Source_Code_Location = #caller_location) {
	str := fmt.tprintf("%s %d", loc.file_path, loc.line)
	metric_str("line", str)
}
