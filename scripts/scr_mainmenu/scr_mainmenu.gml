global.options = {
    audio: 100,
    audio_mute: false,
};

/// @param {string} _name
function Menu_State(_name) : Game_State() constructor {
    name = _name;

    ui = new UI();
    enter_duration = 200;
    exit_duration = 200;

    static menu = function () {}
    static gui = function() {
        do_2d();
        ui.start_frame(!exitting());

        var offset = gui_px(250);
        ui.cursor.x = offset*ease_io_cubic(animate_io()-1);
        ui.get_rect(0, WH/4);

        if (!exitting()) {
            bp_register("Arrows, WASD", "Change selection");
            bp_register("Enter", "Confirm");
        }

        menu();

        ui.end_frame();
    }
}

function GS_Main_Menu() : Menu_State("MAIN MENU") constructor {
    /// @type {Struct.GS_Dungeon}
    menu_bg = undefined;
    cam_pos = new v3(0, 0, 0);
    cam_lookat = new v3(0, 0, 0);
    switch_cam = current_time;

    static init = function() {
        if (is_undefined(menu_bg)) {
            menu_bg = new GS_Dungeon();
            menu_bg.generate_dungeon();
            menu_bg.player.pos.setz(-999999);
            menu_bg.party_members[0].pos.setz(-9999999);
            menu_bg.party_members[1].pos.setz(-9999999);
        }
    }

    static render = function() {
        for (var i=0; i<array_length(menu_bg.enemies); i++) {
            menu_bg.enemies[i].update(menu_bg.dungeon, menu_bg.player, true);
        }

        if (current_time >= switch_cam) {
            var r = pick_arr(menu_bg.dungeon.rooms);
            cam_pos.set(random_range(r.x, r.x+r.w), random_range(r.y, r.y+r.h), 0).scale(TILE_SIZE).setz(32);
            cam_lookat.set(r.xmid(), r.ymid(), 0).scale(TILE_SIZE).setz(24);
            switch_cam = current_time + 10000;
        }
        menu_bg.render(cam_pos, cam_lookat);
    }

    static menu = function() {
        ui.get_rect(gui_px(0), gui_px(60));
        draw_sprite_ext(s_title, 0, ui.cursor.x, ui.cursor.y, gui_px(0.5), gui_px(0.5), 0, c_white, animate_io());
        // ui.get_rect(gui_px(0), gui_px(60));

        if (ui.button("play", "Play", gui_px(200))) {
            set_game_state(new GS_Level_Transition(0, 1, new GS_Dungeon()));
        }

        if (ui.button("opts", "Options", gui_px(200))) {
            set_game_state(new GS_Options_Menu(self));
        }

        if (ui.button("quit", "Quit", gui_px(200))) {
            game_end();
        }

        if (exitting() && !is_instanceof(next_state, Menu_State)) {
            draw_set_alpha(1*ease_io_cubic(animate_out(500)));
            draw_rectangle_color(0, 0, WW, WH, c_black, c_black, c_black, c_black, false);
            draw_set_alpha(1);
        }
    }
}

/// @param {Struct.GS_Main_Menu} mm
function GS_Options_Menu(mm) : Menu_State("OPTIONS MENU") constructor {
    main_menu = mm;
    hint_text = " ";

    static render = function() {
        main_menu.render();
    }

    static menu = function() {
        hint_text = " ";

        if (kbd_pressed(vk_escape, "ESC", "Back to main menu")) {
            set_game_state(main_menu);
        }

        options_menu(ui);

        ui.start_row();
            if (ui.button("back", "Back", gui_px(200))) {
                set_game_state(main_menu);
            }
        ui.end_container();
    }
}

/// @param {Struct.UI} ui
function options_menu(ui) {
    ui.start_row();
    if (ui.button("fullscreen", window_get_fullscreen() ? "Windowed" : "Fullscreen", gui_px(200))) {
        window_set_fullscreen(!window_get_fullscreen());
    }
    if (window_get_fullscreen()) {
        ui.hint("Display the game in a regular window.");
    } else {
        ui.hint("Display the game fullscreen.");
    }
    ui.end_container();

    ui.start_row();
        if (ui.button("mute", global.options.audio_mute ? "Unmute" : "Mute", gui_px(200))) {
            global.options.audio_mute = !global.options.audio_mute;
            if (global.options.audio_mute) audio_stop_all();
        }
        var muted = global.options.audio_mute ? "muted" : "unmuted";
        ui.hint($"The audio is currently {muted}.");
    ui.end_container();

    ui.start_row();
        if (ui.button("vol", $"Volume {global.options.audio}", gui_px(200))) {
            global.options.audio = (global.options.audio + 10)%110;
            audio_set_master_gain(0, global.options.audio/100);
        }
        ui.hint($"Change the audio level.");
    ui.end_container();

    ui.start_row();
        ui.get_rect(gui_px(50), 0);
        ui.label_bg(ui.hint_text, c_black, 0, c_gray);
    ui.end_container();
}

