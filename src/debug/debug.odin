package debug

import "base:runtime"
import "core:mem"
import "core:prof/spall"
import "core:sync"

spall_context: spall.Context
@(thread_local)
spall_buffer: spall.Buffer

DebugState :: struct {
	tracking_allocator:   mem.Tracking_Allocator,
	spall_buffer_backing: []u8,
}

init :: proc() -> ^DebugState {
	state := new(DebugState)

	when ODIN_DEBUG {
		mem.tracking_allocator_init(&state.tracking_allocator, context.allocator)
		context.allocator = mem.tracking_allocator(&state.tracking_allocator)
	}
	spall_context = spall.context_create("game_of_life.spall")
	state.spall_buffer_backing = make([]u8, spall.BUFFER_DEFAULT_SIZE)
	spall_buffer = spall.buffer_create(state.spall_buffer_backing, u32(sync.current_thread_id()))

	return state
}

destroy :: proc(state: ^DebugState) {
	spall.buffer_destroy(&spall_context, &spall_buffer)
	delete(state.spall_buffer_backing)
	spall.context_destroy(&spall_context)

	when ODIN_DEBUG {
		mem.tracking_allocator_destroy(&state.tracking_allocator)
	}

	free(state)
}

@(deferred_in = end_event)
scoped_event :: proc(name: string, location := #caller_location) {
	spall._buffer_begin(&spall_context, &spall_buffer, name, "", location)
}

@(private)
end_event :: proc(name: string, location: runtime.Source_Code_Location) {
	spall._buffer_end(&spall_context, &spall_buffer)
}
