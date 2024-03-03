#macro print show_debug_message
// #macro print noop
#macro assert __assert_impl
// #macro assert noop

function noop() {}

function __assert_impl(condition, msg) {
	if (!condition) {
		show_message(msg);
		game_end(1);
	}
}

/// @template T
/// @param {Array<T>} arr
/// @returns {Array<T>}
function array_dup(arr) {
	var out = array_create(array_length(arr));
	array_copy(out, 0, arr, 0, array_length(arr));
	return out;
}

global.vowels = ["a", "e", "i", "o", "u"];
global.letters = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"];

/// @template T
/// @param {Array<T>} arr
function pick_arr(arr) {
	return arr[irandom(array_length(arr)-1)];
}

function gen_name() {
	var vowel = choose(true, false);
	var name = "";
	for (var i=0; i<4; i++) {
		vowel = !vowel;
		name += pick_arr(vowel ? global.letters : global.vowels);
	}
	return name;
}