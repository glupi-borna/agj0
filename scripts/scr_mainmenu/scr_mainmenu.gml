global.options = {
    audio: 100,
    audio_mute: false,
};

/// @param {string} _name
function Menu_State(_name) : Game_State() constructor {
    name = _name;

    /// @type {Struct.UI}
    ui = undefined;
    enter_duration = 200;
    exit_duration = 200;

    static init = function () { ui = new UI(); }
    static menu = function () {}
    static gui = function() {
        do_2d();
        ui.start_frame();

        var offset = 250;
        var offset = 250;
        ui.cursor.x = -offset+offset*ease_io_cubic(animate_io());
        ui.get_rect(0, WH/4);

        menu();

        ui.end_frame();
    }
}

function GS_Main_Menu() : Menu_State("MAIN MENU") constructor {
    static menu = function() {
        ui.color(c_white);
        ui.label($"Focus: {ui.focused}")
        ui.label($"Mode: {ui.input_mode == INPUT_MODE.BUTTONS ? "buttons" : "mouse"}")
        if (ui.button("play", "Play", 200)) {
            set_game_state(new GS_Dungeon());
        }

        if (ui.button("opts", "Options", 200)) {
            set_game_state(new GS_Options_Menu());
        }

        if (ui.button("quit", "Quit", 200)) {
            game_end();
        }
    }
}

function GS_Options_Menu() : Menu_State("OPTIONS MENU") constructor {
    static menu = function() {
        static hint = function (text) {
            if (ui.last != ui.focused) return;
            if (exitting() || entering()) return;
            ui.color(#aaaaaa);
            ui.label(text);
        }

        ui.start_row();
            if (ui.button("mute", global.options.audio_mute ? "Unmute" : "Mute", 200)) {
                global.options.audio_mute = !global.options.audio_mute;
            }
            hint($"The audio is currently {global.options.audio_mute ? "muted" : "unmuted"}.");
        ui.end_container();

        ui.start_row();
            if (ui.button("vol", $"Volume {global.options.audio}", 200)) {
                global.options.audio = (global.options.audio + 10)%110;
            }
            hint($"Change the audio level.");
        ui.end_container();

        ui.start_row();
            if (ui.button("back", "Back", 200)) {
                set_game_state(new GS_Main_Menu());
            }
            hint($"Back to main menu.");
        ui.end_container();
    }
}