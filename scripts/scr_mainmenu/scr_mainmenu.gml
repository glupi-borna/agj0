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

        bp_register("Arrows, WASD", "Change selection");
        bp_register("Enter", "Confirm");

        menu();

        ui.end_frame();
    }
}

function GS_Main_Menu() : Menu_State("MAIN MENU") constructor {
    static menu = function() {
        if (ui.button("play", "Play", gui_px(200))) {
            set_game_state(new GS_Level_Transition(0, 1, new GS_Dungeon()));
        }

        if (ui.button("opts", "Options", gui_px(200))) {
            set_game_state(new GS_Options_Menu());
        }

        if (ui.button("quit", "Quit", gui_px(200))) {
            game_end();
        }
    }
}

function GS_Options_Menu() : Menu_State("OPTIONS MENU") constructor {
    hint_text = " ";

    static hint = function (text) {
        if (ui.last != ui.focused) return;
        if (exitting() || entering()) return;
        hint_text = text;
    }

    static menu = function() {
        hint_text = " ";

        if (kbd_pressed(vk_escape, "ESC", "Back to main menu")) {
            set_game_state(new GS_Main_Menu());
        }

        options_menu(ui);

        ui.start_row();
            if (ui.button("back", "Back", gui_px(200))) {
                set_game_state(new GS_Main_Menu());
            }
            hint($"Back to main menu.");
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

/// @type {Asset.GMSound}
global.current_bgm = undefined;

/// @param {Asset.GMSound} track
function set_bgm(track) {
    if (global.options.audio_mute) {
        global.current_bgm = undefined;
        audio_stop_all();
        return;
    }

    if (!is_undefined(track) && global.current_bgm == track) {
        return;
    }

    if (!is_undefined(global.current_bgm)) {
        audio_sound_gain(global.current_bgm, 0, 500);
        after(500, audio_stop_sound, [global.current_bgm]);
    }

    global.current_bgm = track;
    if (!is_undefined(track)) {
        audio_play_sound(global.current_bgm, 1, true);
        audio_sound_gain(global.current_bgm, 0, 0);
        audio_sound_gain(global.current_bgm, 1, 500);
    }
}

