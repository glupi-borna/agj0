#macro GUI_SCALE (WW/960)

/// @param {real} x
function gui_px(x) { return GUI_SCALE*x; }

function text_width(text) {
    return gui_px(string_width_ext(text, 2, 999999));
}

function text_height(text) {
    return gui_px(string_height_ext(text, 2, 99999));
}

function render_text(x, y, text) {
    draw_text_transformed(x, y, text, GUI_SCALE, GUI_SCALE, 0);
}

enum UI_DIR { HORIZONTAL, VERTICAL };

/// @param {Enum.UI_DIR} _old_dir
/// @param {Enum.UI_DIR} _dir
/// @param {Struct.v2} _cursor
/// @param {Struct.UI_Container|Undefined} _parent
function UI_Container(_old_dir, _dir, _cursor, _parent) constructor {
    dir = _dir;
    start_dir = _old_dir;
    start_cursor = _cursor.copy();
    parent = _parent;
    max_extent = _cursor.copy();
    gap = is_undefined(_parent) ? new v2(4, 4) : _parent.gap.copy();

    /// @param {Struct.v2} v
    static update_max = function(v) {
        max_extent.x = max(v.x, max_extent.x);
        max_extent.y = max(v.y, max_extent.y);
    }
}

enum INPUT_MODE { POINTER, BUTTONS };

function UI() constructor {
    cursor = new v2(0, 0);

    /// @type {Struct.UI_Container}
    container = undefined;
    active = "-";
    focused = "-";
    last = "-";
    saw_focused = false;
    focus_changed = false;
    interactive = true;
    hint_text = " ";

    input_mode = INPUT_MODE.BUTTONS;

    static start_frame = function(_interactive=true) {
        hint_text = " ";
        interactive = _interactive;

        if (interactive) {
            if (keyboard_check_pressed(vk_anykey)) {
                input_mode = INPUT_MODE.BUTTONS;
            } else if (window_mouse_get_delta_x()>1 || window_mouse_get_delta_y()>1 || mouse_check_button_pressed(mb_any)) {
                input_mode = INPUT_MODE.POINTER;
            }
        }

        saw_focused = false;
        cursor.x = 0;
        cursor.y = 0;
        container = start_col();
        focus_changed = false;
    }

    static end_frame = function() {
        if (!saw_focused) focused = "-";
        if (interactive && mouse_check_button_released(mb_left)) active = "-";
    }

    static set_focus = function(name) {
        if (!interactive) return;
        if (focus_changed) return;
        if (focused == name) return;
        focus_changed = true;
        focused = name;
        saw_focused = true;
    }

    static kbd_focus_interaction = function (id) {
        if (focused == id) saw_focused = true;
        var prev = last;
        last = id;
        if (!interactive) return;
        if ((keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) && focused == prev) set_focus(id);
        if (input_mode != INPUT_MODE.BUTTONS) return;
        if (focused == "-") set_focus(id);
        if (focused != id) return;
        if (keyboard_check_pressed(vk_up) || keyboard_check_pressed(ord("W"))) set_focus(prev);
    }

    /// @param {real} w
    /// @param {real} h
    static get_rect = function (w, h) {
        var r = new Rect(cursor.x, cursor.y, w, h);
        container.update_max(cursor.copy().add(w, h));
        if (container.dir == UI_DIR.VERTICAL) {
            cursor.y += h + gui_px(container.gap.y);
        } else {
            cursor.x += w + gui_px(container.gap.x);
        }
        return r;
    }

    /// @param {Enum.UI_DIR} c_dir
    static start_container = function (c_dir) {
        container = new UI_Container(is_undefined(container) ? UI_DIR.VERTICAL : container.dir, c_dir, cursor.copy(), container);
        dir = c_dir;
        return container;
    }

    static end_container = function () {
        container.max_extent.add(gui_px(container.parent.gap.x), gui_px(container.gap.y));
        if (container.start_dir == UI_DIR.HORIZONTAL) {
            cursor.x = container.max_extent.x;
            cursor.y = container.start_cursor.y;
        } else {
            cursor.x = container.start_cursor.x
            cursor.y = container.max_extent.y;
        }
        container.parent.update_max(container.max_extent);
        container = container.parent;
    }

    static start_row = function() { return start_container(UI_DIR.HORIZONTAL); }
    static start_col = function() { return start_container(UI_DIR.VERTICAL); }

    /// @param {Constant.Color} _c
    static color = function (_c) {
        draw_set_color(_c);
    }

    static label = function(text) {
        var w = text_width(text);
        var h = text_height(text);
        var r = get_rect(w, h);
        render_text(r.x, r.y, text);
    }

    /// @param {string} text
    /// @param {Constant.Color} bg
    static label_bg = function(text, bg, w=0, fg=c_black) {
        var xpad = gui_px(2);
        var ypad = gui_px(2);

        if (w == 0) {
            w = text_width(text) + xpad*2;
        } else {
            xpad = (w - text_width(text)) / 2
        }

        var h = text_height(text) + ypad*2;
        var x2 = cursor.x + w;
        var y2 = cursor.y + h;

        if (string_trim(text) != "") {
            color(bg);
            bgrect(w, h);
            color(fg);
            render_text(cursor.x+xpad, cursor.y+ypad, text);
        }

        get_rect(w, h);
    }

    /// @param {real} w
    /// @param {real} h
    static rect = function(w, h, outline=false) {
        var r = get_rect(w, h);
        draw_rectangle(r.x, r.y, r.x+r.w, r.y+r.h, outline);
    }

    /// @param {real} w
    /// @param {real} h
    static bgrect = function(w, h, outline=false) {
        draw_rectangle(cursor.x, cursor.y, cursor.x+w, cursor.y+h, outline);
    }

    /// @param {Struct.Game_State} gs
    /// @param {string} text
    static hint = function (text) {
        if (last != focused) return;
        if (global.game_state.exitting() || global.game_state.entering()) return;
        hint_text = text;
    }

    /// @param {string} text
    static button = function(id, text, w=0) {
        kbd_focus_interaction(id);

        var xpad = gui_px(2);
        var ypad = gui_px(2);

        if (w == 0) {
            w = text_width(text) + xpad*2;
        } else {
            xpad = (w - text_width(text)) / 2
        }

        var h = text_height(text) + ypad*2;
        var x2 = cursor.x + w;
        var y2 = cursor.y + h;

        var is_focused = focused == id;
        var is_active = active == id;
        var is_hovered = false;
        var clicked = false;

        if (interactive) {
            if (point_in_rectangle(WMX, WMY, cursor.x, cursor.y, x2, y2)) {
                is_hovered = true;

                if (input_mode == INPUT_MODE.POINTER) set_focus(id);

                if (active == "-" && mouse_check_button_pressed(mb_left)) {
                    active = id;
                    set_focus(id);
                    is_active = true;
                    is_focused = true;
                }
            }

            if (is_active && is_hovered && mouse_check_button_released(mb_left)) {
                active = "-";
                set_focus(id);
                clicked = true;

            } else if (is_focused && keyboard_check_pressed(vk_enter)) {
                clicked = true;
            }
        }

        if (is_active) {
            color(#666666);
        } else if (is_focused) {
            color(#ffffff);
        } else {
            color(#aaaaaa);
        }

        bgrect(w, h);

        color(#000000);
        render_text(cursor.x+xpad, cursor.y+ypad, text);
        get_rect(w, h);

        return clicked;
    }
}

function ui_anim(start_time, current_time, duration) {
    return clamp(current_time - start_time, 0, duration)/duration;
}

/// @param {real} x
function ease_io_cubic(x) {
    if (x<0.5) return 4*x*x*x;
    else return 1-power(-2*x+2,3)/2;
}

/// @param {real|Constant.VirtualKey} key
/// @param {string} label
/// @param {string} action
function ButtonPrompt(key, label, action) constructor {
    self.key = key;
    self.label = label;
    self.action = action;
}

/// @param {string|Constant.VirtualKey} key
/// @param {string} label
/// @param {string} action
function kbd_pressed(key, label, action) {
    if (typeof(key) == "string") { key = ord(string_upper(key)); }
    array_push(global.button_prompts, new ButtonPrompt(key, label, action));
    return keyboard_check_pressed(key);
}

/// @param {string|Constant.VirtualKey} key
/// @param {string} label
/// @param {string} action
function kbd_released(key, label, action) {
    if (typeof(key) == "string") { key = ord(string_upper(key)); }
    array_push(global.button_prompts, new ButtonPrompt(key, label, action));
    return keyboard_check_released(key);
}

/// @param {string|Constant.VirtualKey} key
/// @param {string} label
/// @param {string} action
function kbd_down(key, label, action) {
    if (typeof(key) == "string") { key = ord(string_upper(key)); }
    array_push(global.button_prompts, new ButtonPrompt(key, label, action));
    return keyboard_check(key);
}

function bp_register(label, action) {
    array_push(global.button_prompts, new ButtonPrompt(-1, label, action));
}

/// @type {Array<Struct.ButtonPrompt>}
global.button_prompts = [];
global.last_keypress_time = current_time;

function button_prompts_step() {
    /// @type {Array<Struct.ButtonPrompt>}
    global.button_prompts = [];
    if (keyboard_check(vk_anykey)) global.last_keypress_time = current_time;
}

function button_prompts_render() {
    do_2d();

    var alpha = clamp(current_time - global.last_keypress_time - 2000, 0, 1000)/1000;
    if (alpha == 0) return;
    draw_set_alpha(alpha);

    var xoff = 10;
    for (var i=0; i<array_length(global.button_prompts); i++) {
        var bp = global.button_prompts[i];
        var lw = text_width(bp.label);
        var aw = text_width(bp.action);
        var h = text_height("0");

        var apad = gui_px(2);
        var lpad = gui_px(4);

        xoff += aw+apad*2;
        draw_set_color(c_white);
        render_text(WW-xoff+apad, WH-lpad-h, bp.action);

        xoff += lw+lpad*2;
        draw_set_color(c_red);
        draw_rectangle(WW-xoff, WH-lpad-h, WW-xoff+lw+lpad*2, WH-lpad, false);
        draw_set_color(c_white);
        render_text(WW-xoff+lpad, WH-lpad-h, bp.label);

        xoff += lpad*2;
    }
    draw_set_alpha(1);
}