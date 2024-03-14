#macro _print show_debug_message
// #macro _print noop
#macro assert __assert_impl
// #macro assert noop

// #macro print noop
/// @param {ArgumentIdentity} [...]
function print() {
	var str = "";
	for (var i=0; i<argument_count; i++) {
		str += string(argument[i]) + " ";
	}
	_print(str);
}

#macro WMX window_mouse_get_x()
#macro WMY window_mouse_get_y()
#macro WW window_get_width()
#macro WH window_get_height()

function noop() {}

function array_dup(arr) {
	var out = array_create(array_length(arr));
	for (var i=0; i<array_length(arr); i++) {
		out[i] = arr[i];
	}
	return out;
}

function __assert_impl(condition, msg) {
	if (!condition) {
		show_message(msg);
		print("ASSERTION ERROR", msg);
		game_end(1);
	}
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

global.v_floor_battle = vertex_create_buffer();
vertex_begin(global.v_floor_battle, global.vertex_format);
	vtx_norm(0, 0, 1);
	vtx_rgba(#ffffff, 1);

	vtx_pos(0, 0, 0);
	vtx_tex(0, 0);
	vtx_point(global.v_floor_battle);

	vtx_pos(1, 0, 0);
	vtx_tex(30, 0);
	vtx_point(global.v_floor_battle);

	vtx_pos(1, 1, 0);
	vtx_tex(30, 30);
	vtx_point(global.v_floor_battle);
	vtx_point(global.v_floor_battle);

	vtx_pos(0, 1, 0);
	vtx_tex(0, 30);
	vtx_point(global.v_floor_battle);

	vtx_pos(0, 0, 0);
	vtx_tex(0, 0);
	vtx_point(global.v_floor_battle);
vertex_end(global.v_floor_battle);

global.v_wall = vertex_create_buffer();
vertex_begin(global.v_wall, global.vertex_format);
	vtx_norm(0, 1, 0);
	vtx_rgba(#ffffff, 1);

	vtx_pos(1, 0, 0);
	vtx_tex(1, 10);
	vtx_point(global.v_wall);

	vtx_pos(1, 0, 10);
	vtx_tex(1, 0);
	vtx_point(global.v_wall);

	vtx_pos(0, 0, 10);
	vtx_tex(0, 0);
	vtx_point(global.v_wall);
	vtx_point(global.v_wall);

	vtx_pos(0, 0, 0);
	vtx_tex(0, 10);
	vtx_point(global.v_wall);

	vtx_pos(1, 0, 0);
	vtx_tex(1, 10);
	vtx_point(global.v_wall);
vertex_end(global.v_wall);

global.v_door = vertex_create_buffer();
vertex_begin(global.v_door, global.vertex_format);
	vtx_norm(0, 1, 0);
	vtx_rgba(#ffffff, 1);

	vtx_pos(1, 0, 0);
	vtx_tex(1, 1);
	vtx_point(global.v_door);

	vtx_pos(1, 0, 1);
	vtx_tex(1, 0);
	vtx_point(global.v_door);

	vtx_pos(0, 0, 1);
	vtx_tex(0, 0);
	vtx_point(global.v_door);
	vtx_point(global.v_door);

	vtx_pos(0, 0, 0);
	vtx_tex(0, 1);
	vtx_point(global.v_door);

	vtx_pos(1, 0, 0);
	vtx_tex(1, 1);
	vtx_point(global.v_door);

	vtx_norm(0, -1, 0);

	vtx_pos(1, 0, 0);
	vtx_tex(0, 1);
	vtx_point(global.v_door);

	vtx_pos(0, 0, 0);
	vtx_tex(1, 1);
	vtx_point(global.v_door);

	vtx_pos(0, 0, 1);
	vtx_tex(1, 0);
	vtx_point(global.v_door);
	vtx_point(global.v_door);

	vtx_pos(1, 0, 1);
	vtx_tex(0, 0);
	vtx_point(global.v_door);

	vtx_pos(1, 0, 0);
	vtx_tex(0, 1);
	vtx_point(global.v_door);
vertex_end(global.v_door);


/// @param {Function} _fn
/// @param {Array} _args
/// @param {Any} _this
function Callback(_fn, _args, _this) constructor {
	fn_val = _fn;
	args = _args;
	this_val = _this;

	static call = function() {
		method_call(method(this_val, fn_val), args);
	}
}

global.async_cb_map = ds_map_create();

/// @param {real} async_id
/// @param {Struct.Callback} callback
function on_async(async_id, callback) {
	/// @type {Array<Struct.Callback>}
	var cbs = ds_map_find_value(global.async_cb_map, async_id);
	if (is_undefined(cbs)) {
		/// @type {Array<Struct.Callback>}
		cbs = [];
		global.async_cb_map[? async_id] = cbs;
	}
	array_push(cbs, callback);
}

function async_done(async_id) {
	/// @type {Array<Struct.Callback>}
	var cbs = ds_map_find_value(global.async_cb_map, async_id);
	if (is_undefined(cbs)) return;
	ds_map_delete(global.async_cb_map, async_id);
	for (var i=0; i<array_length(cbs); i++) {
		cbs[i].call();
	}
}

function do_3d(fog=300, cull=cull_counterclockwise) {
	ensure_pixelation();
    gpu_set_ztestenable(true);
    gpu_set_zwriteenable(true);
	gpu_set_alphatestenable(true);
	gpu_set_cullmode(cull);
    gpu_set_fog(fog>0, #111111, 0, fog);
	gpu_set_tex_repeat(true);
}


function do_2d() {
	ensure_pixelation();
    gpu_set_ztestenable(false);
    gpu_set_zwriteenable(false);
    gpu_set_fog(false, c_white, 0, 300);
	gpu_set_tex_repeat(false);
}

function ensure_pixelation() {
	if (
		surface_get_width(application_surface) != floor(WW/2) ||
		surface_get_height(application_surface) != floor(WH/2) ||
		display_get_gui_width() != WW ||
		display_get_gui_height() != WH
	) {
		if (WW == 0 || WH == 0) return;
		surface_resize(application_surface, ceil(WW/2), ceil(WH/2));
		display_set_gui_size(WW, WH);
	}
}

/// @param {real} x
/// @param {real} y
/// @param {real} z
function mtx_mov(x, y, z) { return matrix_build(x, y, z, 0, 0, 0, 1, 1, 1); }
/// @param {real} x
/// @param {real} y
/// @param {real} z
function mtx_scl(x, y, z) { return matrix_build(0, 0, 0, 0, 0, 0, x, y, z); }
/// @param {real} x
/// @param {real} y
/// @param {real} z
function mtx_rot(x, y, z) { return matrix_build(0, 0, 0, x, y, z, 1, 1, 1); }

/// @param {Array<Real>} m1
/// @param {Array<Real>} m2
/// @param {Array<Real>} [...]
function mtx_mul() {
	var mat = argument[0];
	for (var i=1; i<argument_count; i++) {
		mat = matrix_multiply(mat, argument[i]);
	}
	return mat;
}

function animation_exists(model, anim_name) {
	var m = get_model(model);
	if (is_undefined(m)) return false;
	return !is_undefined(m.animMap[? anim_name]);
}

/// @param {string} model
/// @param {string} inst_name
function animation_name(model, inst_name) {
	var inst = get_anim_inst(model, inst_name);
	if (is_undefined(inst)) return "";
	return inst.currAnimName;
}

/// @param {string} model
/// @param {string} inst_name
function animation_is_playing(model, inst_name) {
	var inst = get_anim_inst(model, inst_name);
	if (inst == undefined) return inst;
	return inst.get_animation() != -1;
}

/// @param {string} model
/// @param {string} inst_name
/// @param {string} anim_name
/// @param {real} spd
/// @param {real} lerp_spd
function animation_play(model, inst_name, anim_name, spd, lerp_spd, reset=false) {
	var inst = get_anim_inst(model, inst_name);
	if (is_undefined(inst)) return;
	inst.play(anim_name, spd, lerp_spd, reset);
	inst.step(1);
}

/// @param {string} model
/// @param {string} inst_name
function animation_timer(model, inst_name) {
	var inst = get_anim_inst(model, inst_name);
	if (is_undefined(inst)) return -1;
	return inst.timer;
}

/// @type {Array<Struct._ExecAfter>}
global.exec_queue = [];

/// @param {Function} _fn
/// @param {Array} _args
function _ExecFnBase(_fn, _args) constructor {
	fn = _fn;
	args = _args;

	static exec = function() { script_execute_ext(fn, args); }
	static is_ready = function() { return true; }
}

/// @param {Function} _fn
/// @param {Array} _args
/// @param {real} _time
function _ExecAfter(_fn, _args, _time) : _ExecFnBase(_fn, _args) constructor {
	time = _time;
	static is_ready = function() { return current_time > time; }
}

/// @param {real} time
/// @param {Function} fn
/// @param {Array} args
function after(time, fn, args) {
	array_push(global.exec_queue, new _ExecAfter(fn, args, current_time+time));
}

/// @param {real} time
/// @param {real} repeats
/// @param {Function} fn
/// @param {Array} args
function timed_sequence(time, repeats, fn, args) {
    var offset = time;
    for (var i=0; i<repeats; i++) {
        after(offset, fn, args);
        offset += time;
    }
}

/// @param {Function} _cond_fn
/// @param {Array} _cond_args
/// @param {Function} _fn
/// @param {Array} _args
function _ExecWhen(_cond_fn, _cond_args, _fn, _args) : _ExecFnBase(_fn, _args) constructor {
	cond_fn = _cond_fn;
	cond_args = _cond_args;
	static is_ready = function() { return script_execute_ext(cond_fn, cond_args); }
}

/// @param {Function} cond_fn
/// @param {Array} cond_args
/// @param {Function} fn
/// @param {Array} args
function when(cond_fn, cond_args, fn, args) {
	array_push(global.exec_queue, new _ExecWhen(cond_fn, cond_args, fn, args));
}

function drain_exec_queue() {
	for (var i=array_length(global.exec_queue)-1; i>=0; i--) {
		var it = global.exec_queue[i];
		if (it.is_ready()) {
			it.exec();
			array_delete(global.exec_queue, i, 1);
		}
	}
}

function array_flatten(arr, into=[]) {
	for (var i=0; i<array_length(arr); i++) {
		var item = arr[i];
		if (is_array(item)) {
			array_flatten(item, into);
		} else {
			array_push(into, item);
		}
	}
	return into;
}