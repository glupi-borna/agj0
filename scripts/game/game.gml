function Game_State() constructor {
    name = "UNKNOWN";
    static init = function() {};
    static update = function() {};
    static render = function() {};
}

function GS_Main_Menu() constructor {
    name = "MAIN MENU";
    static render = function() {

    }
}

/// @type {Struct.Game_State}
global.game_state = new GS_Main_Menu();