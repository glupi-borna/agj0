function Game_State() constructor {
    name = "UNKNOWN";
    static init = function() {};
    static update = function() {};
    static render = function() {};
    static gui = function() {};
}

function GS_Main_Menu() : Game_State() constructor {
    name = "MAIN MENU";
    /// @type {Struct.UI}
    ui = undefined;

    static init = function () {
        ui = new UI();
    }

    static render = function() {
        ui.start_frame();

        ui.get_rect(0, room_height/2);

        ui.focus_ud("quit", "opts");
        if (ui.button("play", "Play", 200)) {
            set_game_state(new GS_Dungeon());
        }

        ui.focus_ud("play", "quit");
        if (ui.button("opts", "Options", 200)) {
            set_game_state(new GS_Options_Menu());
        }

        ui.focus_ud("opts", "play");
        if (ui.button("quit", "Quit", 200)) {
            game_end();
        }

        ui.end_frame();
    }
}

function GS_Options_Menu() : Game_State() constructor {
    name = "OPTIONS MENU";
    /// @type {Struct.UI}
    ui = undefined;

    static init = function () {
        ui = new UI();
    }

    static render = function() {
        ui.start_frame();

        ui.get_rect(0, room_height/2);

        static hint = function (text) {
            if (ui.last != ui.kbd_focus) return;
            ui.color(#aaaaaa);
            ui.label(text);
        }

        ui.start_row();
            ui.focus_ud("back", "vol");
            if (ui.button("mute", global.options.audio_mute ? "Unmute" : "Mute", 200)) {
                global.options.audio_mute = !global.options.audio_mute;
            }
            hint($"The audio is currently {global.options.audio_mute ? "muted" : "unmuted"}.");
        ui.end_container();

        ui.start_row();
            ui.focus_ud("mute", "back");
            if (ui.button("vol", $"Volume {global.options.audio}", 200)) {
                global.options.audio = (global.options.audio + 10)%110;
            }
            hint($"Change the audio level.");
        ui.end_container();

        ui.start_row();
            ui.focus_ud("vol", "mute");
            if (ui.button("back", "Back", 200)) {
                set_game_state(new GS_Main_Menu());
            }
            hint($"Back to main menu.");
        ui.end_container();

        ui.end_frame();
    }
}

function Dungeon_Player() constructor {
    pos = new v3(0, 0, 0);
    fwd = new v3(1, 1, 0).normalize();
}

function GS_Dungeon() : Game_State() constructor {
    name = "DUNGEON";
    /// @type {Struct.Dungeon}
    dungeon = undefined;
    /// @type {Id.Camera}
    camera = undefined;
    /// @type {Struct.Dungeon_Player}
    player = undefined;

    static init = function() {
        gpu_set_ztestenable(true);
        gpu_set_zwriteenable(true);
        gpu_set_cullmode(cull_noculling);
        gpu_set_fog(true, c_black, 0, 300);
        dungeon = new Dungeon(50, 50);
        dungeon.generate();
        player = new Dungeon_Player();
        var r = dungeon.get_leaf_room();
        player.pos.x = r.xmid()*48;
        player.pos.y = r.ymid()*48;
        player.pos.z = 24;
    }

    static update = function() {
        var old_pos = player.pos.copy();
        player.fwd.normalize();
        if (keyboard_check(vk_space)) player.pos.add(0, 0, 4);
        if (keyboard_check(vk_control)) player.pos.add(0, 0, -4);
        if (keyboard_check(ord("W"))) player.pos.addv(player.fwd.copy().scale(2));
        if (keyboard_check(ord("S"))) player.pos.addv(player.fwd.copy().neg().scale(2));
        if (keyboard_check(ord("A"))) player.fwd.zrotate(-2);
        if (keyboard_check(ord("D"))) player.fwd.zrotate(2);

        var move = player.pos.copy().subv(old_pos);

        static collision = function () {
            var px = player.pos.x;
            var py = player.pos.y;
            var xx = floor(px/48);
            var yy = floor(py/48);
            for (var i=-1; i<=1; i++) {
                var tx = xx+i;
                for (var j=-1; j<=1; j++) {
                    var ty = yy+j;
                    var k = dungeon.tile_kind(tx, ty);
                    if (k != TILE.WALL) continue;
                    if (rectangle_in_circle(tx*48, ty*48, (tx+1)*48, (ty+1)*48, px, py, 12) != 0) {
                        return true;
                    }
                }
            }
            return false;
        };

        if (collision()) {
            player.pos.set(old_pos.x, old_pos.y, old_pos.z);
            var steps = 10;

            var step = move.copy().scale(-1/steps);
            while (steps) {
                player.pos.addv(step);
                if (collision()) {
                    player.pos.subv(step);
                    break;
                }
                steps--;
            }

            step.zrotate(90);
            while (steps) {
                player.pos.addv(step);
                if (collision()) {
                    player.pos.subv(step);
                    break;
                }
                steps--;
            }

            step.zrotate(180);
            while (steps) {
                player.pos.addv(step);
                if (collision()) {
                    player.pos.subv(step);
                    break;
                }
                steps--;
            }
        }
    }

    static render = function() {
        camera = camera_get_active();
        var lookat = player.pos.copy().addv(player.fwd);
        camera_set_view_mat(camera, matrix_build_lookat(player.pos.x, player.pos.y, player.pos.z, lookat.x, lookat.y, lookat.z-0.1, 0, 0, 1));
        camera_set_proj_mat(camera, matrix_build_projection_perspective_fov(-60, -window_get_width()/window_get_height(), 1, 32000));
        camera_apply(camera);

        // matrix_stack_push(matrix_build(player.pos.x, player.pos.y, 1, 0, 0, 0, 100, 100, 1));
        // matrix_set(matrix_world, matrix_stack_top());
        // vertex_submit(global.v_floor, pr_trianglelist, -1);
        // matrix_stack_pop();
        // matrix_set(matrix_world, matrix_stack_top());
        // dungeon.render(min(room_width, room_height)/max(dungeon.w, dungeon.h));
        static render_wall = function (x, y, size, rot) {
            matrix_stack_push(matrix_build(x, y, 0, 0, 0, 0, 1, 1, 1));
            matrix_stack_push(matrix_build(0, 0, 0, 0, 0, rot, 1, 1, 1));
            matrix_stack_push(matrix_build(0, 0, 0, 0, 0, 0, size, 1, size*10));
            matrix_set(matrix_world, matrix_stack_top());
            vertex_submit(global.v_wall, pr_trianglelist, -1);
            matrix_stack_pop();
            matrix_stack_pop();
            matrix_stack_pop();
            matrix_set(matrix_world, matrix_stack_top());
        }

        static render_floor = function (x, y, size) {
            matrix_stack_push(matrix_build(x, y, 0, 0, 0, 0, 1, 1, 1));
            matrix_stack_push(matrix_build(0, 0, 0, 0, 0, 0, 48, 48, 1));
            matrix_set(matrix_world, matrix_stack_top());
            vertex_submit(global.v_floor, pr_trianglelist, -1);
            matrix_stack_pop();
            matrix_stack_pop();
            matrix_set(matrix_world, matrix_stack_top());
        }

        for (var yy=0; yy<dungeon.h; yy++) {
            for (var xx=0; xx<dungeon.w; xx++) {
                var k = dungeon.tile_kind(xx, yy);

                if (k == TILE.FLOOR || k == TILE.DOOR) {
                    render_floor(xx*48, yy*48, 48);
                }

                if (k != TILE.WALL) continue;

                var k = dungeon.tile_kind(xx+1, yy);
                if (k==TILE.FLOOR || k==TILE.DOOR) {
                    render_wall((xx+1)*48, yy*48, 48, -90);
                }

                k = dungeon.tile_kind(xx-1, yy);
                if (k==TILE.FLOOR || k==TILE.DOOR) {
                    render_wall(xx*48, yy*48, 48, -90);
                }

                k = dungeon.tile_kind(xx, yy+1);
                if (k==TILE.FLOOR || k==TILE.DOOR) {
                    render_wall(xx*48, (yy+1)*48, 48, 0);
                }

                k = dungeon.tile_kind(xx, yy-1);
                if (k==TILE.FLOOR || k==TILE.DOOR) {
                    render_wall(xx*48, yy*48, 48, 0);
                }
            }
        }

    }
}

/// @type {Struct.Game_State}
global.game_state = new GS_Main_Menu();

global.options = {
    audio: 100,
    audio_mute: false,
};

/// @param {Struct.Game_State} gs
function set_game_state(gs) {
    global.game_state = gs;
    gs.init();
}