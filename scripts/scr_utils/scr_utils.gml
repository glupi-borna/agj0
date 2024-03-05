#macro print show_debug_message
// #macro print noop
#macro assert __assert_impl
// #macro assert noop

#macro WMX window_mouse_get_x()
#macro WMY window_mouse_get_y()

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



vertex_format_begin();
	vertex_format_add_position_3d();
	vertex_format_add_normal();
	vertex_format_add_texcoord();
	vertex_format_add_color();
global.vertex_format = vertex_format_end();

global.vbuf_curr_point = {
	pos: new v3(0, 0, 0),
	normal: new v3(0, 0, 0),
	tex: new v2(0, 0),
	color: c_white,
	alpha: 1
};

function vtx_pos(x, y, z) { global.vbuf_curr_point.pos.set(x, y, z); }
function vtx_norm(x, y, z) { global.vbuf_curr_point.normal.set(x, y, z); }
function vtx_tex(x, y) { global.vbuf_curr_point.tex.set(x, y); }
function vtx_col(color) { global.vbuf_curr_point.color = color; }
function vtx_alpha(alpha) { global.vbuf_curr_point.alpha = alpha; }
function vtx_rgba(color, alpha) { vtx_col(color); vtx_alpha(alpha); }
function vtx_point(buf) {
	vertex_position_3d(buf, global.vbuf_curr_point.pos.x, global.vbuf_curr_point.pos.y, global.vbuf_curr_point.pos.z);
	vertex_normal(buf, global.vbuf_curr_point.normal.x, global.vbuf_curr_point.normal.y, global.vbuf_curr_point.normal.z);
	vertex_texcoord(buf, global.vbuf_curr_point.tex.x, global.vbuf_curr_point.tex.y);
	vertex_color(buf, global.vbuf_curr_point.color, global.vbuf_curr_point.alpha);
}

global.v_floor = vertex_create_buffer();
vertex_begin(global.v_floor, global.vertex_format);
	vtx_norm(0, 0, 1);
	vtx_rgba(#ffffff, 1);

	vtx_pos(0, 0, 0);
	vtx_tex(0, 0);
	vtx_point(global.v_floor);

	vtx_pos(1, 0, 0);
	vtx_tex(1, 0);
	vtx_point(global.v_floor);

	vtx_pos(1, 1, 0);
	vtx_tex(1, 1);
	vtx_point(global.v_floor);
	vtx_point(global.v_floor);

	vtx_pos(0, 1, 0);
	vtx_tex(0, 1);
	vtx_point(global.v_floor);

	vtx_pos(0, 0, 0);
	vtx_tex(0, 0);
	vtx_point(global.v_floor);
vertex_end(global.v_floor);

global.v_wall = vertex_create_buffer();
vertex_begin(global.v_wall, global.vertex_format);
	vtx_norm(0, 1, 0);
	vtx_rgba(#ffffff, 1);

	vtx_pos(0, 0, 1);
	vtx_tex(0, 0);
	vtx_point(global.v_wall);

	vtx_pos(1, 0, 1);
	vtx_tex(1, 0);
	vtx_point(global.v_wall);

	vtx_pos(1, 0, 0);
	vtx_tex(1, 1);
	vtx_point(global.v_wall);
	vtx_point(global.v_wall);

	vtx_pos(0, 0, 0);
	vtx_tex(0, 1);
	vtx_point(global.v_wall);

	vtx_pos(0, 0, 1);
	vtx_tex(0, 0);
	vtx_point(global.v_wall);

	vtx_norm(0, -1, 0);

	vtx_pos(1, 0, 1);
	vtx_tex(0, 0);
	vtx_point(global.v_wall);

	vtx_pos(0, 0, 1);
	vtx_tex(1, 0);
	vtx_point(global.v_wall);

	vtx_pos(0, 0, 0);
	vtx_tex(1, 1);
	vtx_point(global.v_wall);
	vtx_point(global.v_wall);

	vtx_pos(1, 0, 0);
	vtx_tex(0, 1);
	vtx_point(global.v_wall);

	vtx_pos(1, 0, 1);
	vtx_tex(0, 0);
	vtx_point(global.v_wall);
vertex_end(global.v_wall);