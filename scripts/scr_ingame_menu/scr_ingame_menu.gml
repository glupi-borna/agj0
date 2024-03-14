/// @param {Struct.GS_Dungeon} gs
/// @param {string} name
function GS_Ingame_Menu_State(gs, name) : Menu_State(name) constructor {
    root_gs = gs;

    static render = function() {
        update_animations();
        root_gs.render();
    }
}

/// @param {Struct.GS_Battle} _gs
/// @param {Array<Struct.Item>} _got_items
function GS_Menu_Battle_Stats(_gs, _got_items) : Menu_State("BATTLE STATS") constructor {
    battle_gs = _gs;
    got_items = _got_items;

    static render = function() {
        battle_gs.render();
    }

    static menu = function() {
        draw_set_alpha(0.4*ease_io_cubic(animate_io()));
        draw_rectangle_color(0, 0, WW, WH, c_black, c_black, c_black, c_black, false);
        draw_set_alpha(1);

        var got_xp = 0;
        for (var i=0; i<array_length(battle_gs.enemies); i++) {
            got_xp += battle_gs.enemies[i].stats.lvl;
        }

        ui.label_bg($"Battle won", c_black, gui_px(274), c_yellow);

        var lvl_ups = [];

        for (var i=0; i<array_length(battle_gs.party); i++) {
            ui.start_row();
                ui.get_rect(gui_px(30), gui_px(0));
                var char = battle_gs.party[i];
                var rect = ui.get_rect(gui_px(70), gui_px(74));

                if (char.hp == 0) {
                    shader_set(sh_bw);
                    draw_sprite_ext(char.icon, 0, rect.x, rect.y, gui_px(1), gui_px(1), 0, c_white, 1);
                    shader_reset();
                    ui.end_container();
                    continue;
                }

                draw_sprite_ext(char.icon, 0, rect.x, rect.y, gui_px(1), gui_px(1), 0, c_white, 1);
                ui.start_col();
                    ui.get_rect(gui_px(0), gui_px(20));
                    if (char.stats.xp + got_xp >= lvl_xp(char.stats.lvl)) {
                        array_push(lvl_ups, char);
                        ui.label_bg($"LVL UP", c_yellow, gui_px(200), c_black);
                    } else {
                        ui.label_bg($"{got_xp}xp", c_black, 0, c_yellow);
                    }
                ui.end_container()

            ui.end_container();
        }

        if (array_length(got_items) > 0) {
            ui.label_bg("Got items", c_white, 200, c_blue);
            for (var i=0; i<array_length(got_items); i++) {
                var item = got_items[i];
                ui.label_bg(item.name, c_blue, 200, c_white);
            }
        }

        if (ui.button("continue", "Continue", gui_px(200))) {
            for (var i=0; i<array_length(got_items); i++) {
                battle_gs.gs.inventory.add(got_items[i], 1);
            }

            after(500, function(party, got_xp) {
                for (var i=0; i<array_length(party); i++) {
                    var char = party[i];
                    if (char.hp == 0) continue;
                    char.stats.xp += got_xp;
                    if (char.stats.xp >= lvl_xp(char.stats.lvl)) {
                        char.stats.xp = 0;
                        char.stats.lvl++;
                    }
                }
            }, [battle_gs.party, got_xp]);

            if (array_length(lvl_ups) > 0) {
                set_game_state(new GS_Menu_Lvl_Up(battle_gs, lvl_ups));
            } else {
                set_game_state(battle_gs.gs, false, true);
            }
            return;
        }
    }
}

/// @param {Struct.GS_Battle} _gs
/// @param {Array<Struct.Character>} _lvl_ups
function GS_Menu_Lvl_Up(_gs, _lvl_ups) : Menu_State("LVL UP") constructor {
    /// @type {Struct.GS_Battle}
    battle_gs = _gs;
    lvl_ups = _lvl_ups;

    static render = function() {
        battle_gs.render();
    }

    static advance = function() {
        var char = lvl_ups[0];
        char.hp = char.stats.max_hp;

        if (array_length(lvl_ups) > 1) {
            var arr = array_dup(lvl_ups);
            array_shift(arr);
            set_game_state(new GS_Menu_Lvl_Up(battle_gs, arr));
        } else {
            set_game_state(battle_gs.gs, false, true);
        }
    }

    static menu = function() {
        draw_set_alpha(0.4*ease_io_cubic(animate_io()));
        draw_rectangle_color(0, 0, WW, WH, c_black, c_black, c_black, c_black, false);
        draw_set_alpha(1);
        var char = lvl_ups[0];

        do_3d(0, cull_noculling);
            var original_cursor = ui.cursor.copy();
            var t2 = (1-animate_io())*gui_px(250);
            ui.cursor.set(WW-gui_px(200) + t2, WH/2);

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
                render_model_simple("char", "stats-char", char.texture);
            shader_reset();

            matrix_set(matrix_world, matrix_build_identity());

            ui.cursor.set(original_cursor.x, original_cursor.y);
        do_2d();

        ui.label_bg($"Lvl up", c_yellow, gui_px(200), c_black);
        ui.label_bg($"Pick a stat to upgrade", c_black, gui_px(200), c_yellow);

        ui.start_row();
            if (ui.button("mhp", "Max HP", 200)) {
                char.stats.max_hp += 5;
                advance();
            }

            if (ui.last==ui.focused) {
                ui.label_bg($"{char.stats.max_hp+5}", c_yellow, 0, c_black);
            } else {
                ui.label_bg($"{char.stats.max_hp}", c_black, 0, c_yellow);
            }
        ui.end_container();

        ui.start_row();
            if (ui.button("spd", "Speed", 200)) {
                char.stats.speed += 1;
                advance();
            }

            if (ui.last==ui.focused) {
                ui.label_bg($"{char.stats.speed+1}", c_yellow, 0, c_black);
            } else {
                ui.label_bg($"{char.stats.speed}", c_black, 0, c_yellow);
            }
        ui.end_container();

        ui.start_row();
            if (ui.button("atk", "Attack", 200)) {
                char.stats.attack += 1;
                advance();
            }

            if (ui.last==ui.focused) {
                ui.label_bg($"{char.stats.attack+1}", c_yellow, 0, c_black);
            } else {
                ui.label_bg($"{char.stats.attack}", c_black, 0, c_yellow);
            }
        ui.end_container();
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

        ui.cursor.y += gui_px(100);
        ui.label_bg($"LVL {focus_char.stats.lvl}", c_blue, gui_px(200), c_white);
        ui.label_bg($"Max HP: {focus_char.hp} / {focus_char.stats.max_hp}", c_blue, gui_px(200), c_white);
        ui.label_bg($"Speed: {focus_char.stats.speed}", c_blue, gui_px(200), c_white);
        ui.label_bg($"Attack: {focus_char.stats.attack}", c_blue, gui_px(200), c_white);
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
            var count = root_gs.inventory.items[? item];

            ui.start_row();
                if (ui.button($"inv:{i}", item.name, 200) && item.usable_outside_battle) {
                    set_game_state(new GS_Menu_Use(root_gs, item));
                    return;
                }
                ui.label_bg($"x{count}", c_white);
            ui.end_container();

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
        var t2 = (1-animate_io())*WW/2;
        ui.cursor.set(WW/2 + WW/2*t + t2, WH/2);

        ui.label_bg(focus_item.desc, c_white);
    }
}

/// @param {Struct.GS_Dungeon} gs
/// @param {Struct.Item} item
function GS_Menu_Use(gs, item) : GS_Ingame_Menu_State(gs, "INGAME ITEM USE") constructor {
    self.item = item;

    /// @type {Struct.Character}
    focus_char = undefined;
    focus_time = current_time;

    static menu = function() {
        draw_set_alpha(0.4*ease_io_cubic(animate_io()));
        draw_rectangle_color(0, 0, WW, WH, c_black, c_black, c_black, c_black, false);
        draw_set_alpha(1);

        if (kbd_released(vk_escape, "ESC", "Back")) {
            set_game_state(new GS_Menu_Inv(root_gs));
            return;
        }

        var last_focus_char = focus_char;
        focus_char = undefined;

        /// @type {Array<Struct.Character>}
        var targets = [];
        if (item.usable_on_downed) {
            for (var i=0; i<array_length(root_gs.party); i++) {
                var char = root_gs.party[i];
                if (char.hp == 0) array_push(targets, char);
            }
        } else {
            for (var i=0; i<array_length(root_gs.party); i++) {
                var char = root_gs.party[i];
                if (char.hp > 0) array_push(targets, char);
            }
        }

        if (array_length(targets) == 0 && !exitting()) {
            set_game_state(new GS_Menu_Inv(root_gs));
            return;
        }

        for (var i=0; i<array_length(targets); i++) {
            var char = targets[i];

            if (ui.button($"use:{i}", char.name, 200)) {
                item.effect(char, char);
                root_gs.inventory.remove(item, 1);
                set_game_state(new GS_Menu_Inv(root_gs));
                return;
            }

            if (ui.last == ui.focused) focus_char = char;
        }

        if (focus_char != last_focus_char) focus_time = current_time;

        ui.get_rect(0, gui_px(20));

        if (ui.button("back", "Back", gui_px(200))) {
            set_game_state(new GS_Menu_Inv(root_gs));
            return;
        }

        if (is_undefined(focus_char)) return;
        var time_since_focus = current_time - focus_time;
        var t = 1-ease_io_cubic(clamp(time_since_focus, 0, 500)/500);
        var t2 = (1-animate_io())*WW/2;
        ui.cursor.set(WW/2 + WW/2*t + t2, WH/2);

        focus_char.effects = [];
        focus_char.draw_head(ui.cursor.x, ui.cursor.y, false);
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

