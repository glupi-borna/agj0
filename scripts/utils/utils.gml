#macro debug:print show_debug_message
#macro debug:assert __assert_impl
#macro release:assert noop

function noop() {}

function __assert_impl(condition, message) {
	if (!condition) {
		show_message(message);
		game_end(1);
	}
}

function array_dup(arr) {
	var out = array_create(array_length(arr));
	array_copy(out, 0, arr, 0, array_length(arr));
	return out;
}