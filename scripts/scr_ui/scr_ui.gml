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
    focus_changed = false;
    focus = {
        left: "-",
        right: "-",
        up: "-",
        down: "-"
    };

    input_mode = INPUT_MODE.BUTTONS;

    static start_frame = function() {
        if (keyboard_check_pressed(vk_anykey)) {
            input_mode = INPUT_MODE.BUTTONS;
        } else if (window_mouse_get_delta_x()>5 || window_mouse_get_delta_y()>5 || mouse_check_button_pressed(mb_any)) {
            input_mode = INPUT_MODE.POINTER;
        }

        cursor.x = 0;
        cursor.y = 0;
        container = start_col();
        focus_changed = false;
        focus = {
            left: "-",
            right: "-",
            up: "-",
            down: "-"
        };
    }

    static end_frame = function() {
        if (mouse_check_button_released(mb_left)) active = "-";
    }

    /// @param {string} left
    /// @param {string} right
    /// @param {string} up
    /// @param {string} down
    static focus_targets = function (left, right, up, down) {
        focus.left = left;
        focus.right = right;
        focus.up = up;
        focus.down = down;
    }

    static focus_ud = function(up, down) { focus.up = up; focus.down = down; }
    static focus_lr = function(left, right) { focus.left = left; focus.right = right; }

    static focus_left = function(name) { focus.left = name; }
    static focus_down = function(name) { focus.down = name; }
    static focus_right = function(name) { focus.right = name; }
    static focus_up = function(name) { focus.up = name; }

    static set_focus = function(name) {
        if (focus_changed) return;
        if (focused == name) return;
        focus_changed = true;
        focused = name;
    }

    static kbd_focus_interaction = function (id) {
        last = id;
        if (input_mode != INPUT_MODE.BUTTONS) return;
        if (focused == "-") set_focus(id);
        if (focused != id) return;
        if (keyboard_check_pressed(vk_left) && focus.left != "-") set_focus(focus.left);
        if (keyboard_check_pressed(vk_right) && focus.right != "-") set_focus(focus.right);
        if (keyboard_check_pressed(vk_down) && focus.down != "-") set_focus(focus.down);
        if (keyboard_check_pressed(vk_up) && focus.up != "-") set_focus(focus.up);
    }

    static get_rect = function (w, h) {
        var r = new Rect(cursor.x, cursor.y, w, h);
        container.update_max(cursor.copy().add(w, h));
        if (container.dir == UI_DIR.VERTICAL) {
            cursor.y += h + container.gap.y;
        } else {
            cursor.x += w + container.gap.x;
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
        container.max_extent.addv(container.parent.gap);
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

    static label = function(text, linesep=2, maxw=99999) {
        var w = string_width_ext(text, linesep, maxw);
        var h = string_height_ext(text, linesep, maxw);
        var r = get_rect(w, h);
        draw_text_ext(r.x, r.y, text, linesep, maxw);
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

    /// @param {string} text
    static button = function(id, text, w=0) {
        kbd_focus_interaction(id);

        var xpad = 2;
        var ypad = 2;

        if (w == 0) {
            w = string_width(text) + xpad*2;
        } else {
            xpad = (w - string_width(text)) / 2
        }

        var h = string_height(text) + ypad*2;
        var x2 = cursor.x + w;
        var y2 = cursor.y + h;

        var is_focused = focused == id;
        var is_active = active == id;
        var is_hovered = false;
        var clicked = false;

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

        if (is_active) {
            color(#666666);
        } else if (is_hovered || is_focused) {
            color(#ffffff);
        } else {
            color(#aaaaaa);
        }

        bgrect(w, h);

        color(#000000);
        draw_text(cursor.x+xpad, cursor.y+ypad, text);
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
