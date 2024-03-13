/// @param {Struct.GS_Dungeon} gs
/// @param {string} name
function GS_Ingame_Menu_State(gs, name) : Menu_State(name) constructor {
    root_gs = gs;

    static render = function() {
        update_animations();
        root_gs.render();
    }
}

/// @param {Struct.GS_Dungeon} gs
function GS_Menu_Ingame(gs) : GS_Ingame_Menu_State(gs, "INGAME MENU") constructor {
    static menu = function() {
        draw_set_alpha(0.4*ease_io_cubic(animate_io()));
        draw_rectangle_color(0, 0, WW, WH, c_black, c_black, c_black, c_black, false);
        draw_set_alpha(1);

        if (kbd_pressed(vk_escape, "ESC", "Back to game")) {
            set_game_state(root_gs, false, true);
            return;
        }

        if (ui.button("continue", "Continue", gui_px(200))) {
            set_game_state(root_gs, false, true);
            return;
        }

        ui.get_rect(0, gui_px(20));

        if (ui.button("stats", "Stats", gui_px(200))) {
            set_game_state(new GS_Menu_Stats(root_gs));
            return;
        }

        if (ui.button("inv", "Inventory", gui_px(200))) {
            set_game_state(new GS_Menu_Inv(root_gs));
            return;
        }

        if (ui.button("opts", "Options", gui_px(200))) {
            set_game_state(new GS_Ingame_Options(root_gs));
            return;
        }

        ui.get_rect(0, gui_px(20));

        if (ui.button("quit", "Quit", gui_px(200))) {
            set_game_state(new GS_Ingame_Quit(root_gs));
            return;
        }
    }
}

/// @param {Struct.GS_Dungeon} gs
function GS_Menu_Stats(gs) : GS_Ingame_Menu_State(gs, "INGAME STATS") constructor {
    /// @type {Struct.Character}
    focus_char = undefined;
    focus_time = current_time;

    static menu = function() {
        draw_set_alpha(0.4*ease_io_cubic(animate_io()));
        draw_rectangle_color(0, 0, WW, WH, c_black, c_black, c_black, c_black, false);
        draw_set_alpha(1);

        if (kbd_released(vk_escape, "ESC", "Back")) {
            set_game_state(new GS_Menu_Ingame(root_gs));
        }

        var last_focus_char = focus_char;
        focus_char = undefined;
        for (var i=0; i<array_length(root_gs.party); i++) {
            var char = root_gs.party[i];
            ui.button($"char:{i}", char.name, gui_px(200));
            if (ui.last == ui.focused) focus_char = char;
        }

        if (focus_char != last_focus_char) focus_time = current_time;

        ui.get_rect(0, gui_px(20));

        if (ui.button("back", "Back")) {
            set_game_state(new GS_Menu_Ingame(root_gs));
        }

        if (is_undefined(focus_char)) return;
        var time_since_focus = current_time - focus_time;
        var t = 1-ease_io_cubic(clamp(time_since_focus, 0, 500)/500);
        var t2 = (1-animate_io())*gui_px(250);
        ui.cursor.set(WW-gui_px(200) + gui_px(500)*t + t2, WH/2);

        do_3d(0, cull_noculling);

        if (keyboard_check(vk_f4)) {
            window_set_fullscreen(!window_get_fullscreen());
        }

        var pos = new v3(gui_px(80), WW*0.8, 0);
        var rot = new v3(165, 90, -90);
        var scl = new v3(WW/2, WW/2, WW/2);

        matrix_set(matrix_world, mtx_mul(
            mtx_scl(scl.x, scl.y, scl.z),
            mtx_rot(rot.x, rot.y, rot.z),
            mtx_mov(ui.cursor.x+pos.x, ui.cursor.y+pos.y, pos.z)
        ));

        shader_set(sh_smf_animate_menu);
            animation_play("char", "stats-char", "idle", 0.01, 1, false);
            render_model_simple("char", "stats-char", focus_char.texture);
        shader_reset();

        matrix_set(matrix_world, matrix_build_identity());

        do_2d();

        ui.label_bg($"LVL {focus_char.stats.lvl}", c_blue, gui_px(200), c_white);
        ui.label_bg($"HP: {focus_char.hp} / {focus_char.stats.max_hp}", c_blue, gui_px(200), c_white);
        ui.label_bg($"Speed: {focus_char.stats.speed}", c_blue, gui_px(200), c_white);
    }
}

/// @param {Struct.GS_Dungeon} gs
function GS_Menu_Inv(gs) : GS_Ingame_Menu_State(gs, "INGAME INV") constructor {
    /// @type {Struct.Item}
    focus_item = undefined;
    focus_time = current_time;

    static menu = function() {
        draw_set_alpha(0.4*ease_io_cubic(animate_io()));
        draw_rectangle_color(0, 0, WW, WH, c_black, c_black, c_black, c_black, false);
        draw_set_alpha(1);

        if (kbd_released(vk_escape, "ESC", "Back")) {
            set_game_state(new GS_Menu_Ingame(root_gs));
            return;
        }

        var last_focus_item = focus_item;
        focus_item = undefined;

        /// @type {Array<Struct.Item>}
        var inv = ds_map_keys_to_array(root_gs.inventory.items);
        for (var i=0; i<array_length(inv); i++) {
            var item = inv[i];
            ui.button($"inv:{i}", item.name, 200);
            if (ui.last == ui.focused) focus_item = item;;
        }

        if (focus_item != last_focus_item) focus_time = current_time;

        ui.get_rect(0, gui_px(20));

        if (ui.button("back", "Back", gui_px(200))) {
            set_game_state(new GS_Menu_Ingame(root_gs));
            return;
        }

        if (is_undefined(focus_item)) return;
        var time_since_focus = current_time - focus_time;
        var t = 1-ease_io_cubic(clamp(time_since_focus, 0, 500)/500);
        var t2 = (1-animate_io())*250;
        ui.cursor.set(WW-250 + 500*t + t2, WH/2);

        ui.label_bg(focus_item.desc, c_white);
    }
}

/// @param {Struct.GS_Dungeon} gs
function GS_Ingame_Options(gs) : GS_Ingame_Menu_State(gs, "INGAME OPTIONS") constructor {
    static menu = function() {
        draw_set_alpha(0.4*ease_io_cubic(animate_io()));
        draw_rectangle_color(0, 0, WW, WH, c_black, c_black, c_black, c_black, false);
        draw_set_alpha(1);

        if (kbd_released(vk_escape, "ESC", "Back")) {
            set_game_state(new GS_Menu_Ingame(root_gs));
            return;
        }

        options_menu(ui);

        ui.get_rect(0, gui_px(20));

        if (ui.button("back", "Back", gui_px(200))) {
            set_game_state(new GS_Menu_Ingame(root_gs));
        }
    }
}

/// @param {Struct.GS_Dungeon} gs
function GS_Ingame_Quit(gs) : GS_Ingame_Menu_State(gs, "INGAME QUIT") constructor {
    static menu = function() {
        draw_set_alpha(0.4*ease_io_cubic(animate_io()));
        draw_rectangle_color(0, 0, WW, WH, c_black, c_black, c_black, c_black, false);
        draw_set_alpha(1);

        if (kbd_released(vk_escape, "ESC", "Back")) {
            set_game_state(new GS_Menu_Ingame(root_gs));
            return;
        }

        if (ui.button("back", "Back", gui_px(200))) {
            set_game_state(new GS_Menu_Ingame(root_gs));
            return;
        }

        ui.get_rect(0, gui_px(20));

        if (ui.button("to_menu", "To main menu", gui_px(200))) {
            set_game_state(new GS_Main_Menu());
            return;
        }

        if (ui.button("game", "Quit game", gui_px(200))) {
            game_end();
        }
    }
}

