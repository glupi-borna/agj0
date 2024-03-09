/// @param {Struct.Stats} _stats
/// @param {string} _model
/// @param {Asset.GMSprite} _texture
/// @param {real} _size
/// @param {bool} _floating
function Character(_stats, _model, _texture, _size, _floating) constructor {
    stats = _stats;
    model = _model;
    texture = _texture;
    size = _size;
    floating = _floating;
    hp = stats.max_hp;
    dp = stats.max_dp;

    pos = new v3(0, 0, 0);
    fwd = new v3(1, 1, 0);

    static look_pos = function() {
        var out = pos.copy().add(0, 0, size);
        if (floating) out.add(0, 0, size*2);
        return out;
    }

    static render_pos = function() {
        if (!floating) return pos.copy();
        return look_pos().add(0, 0, sin(current_time/1000)*size*0.1);
    }
}

enum INITIATIVE { PARTY, ENEMY, NONE };

/// @param {Struct.Character} c1
/// @param {Struct.Character} c2
function sort_chars_by_speed(c1, c2) {
    if (c1.stats.speed > c2.stats.speed) return -1;
    if (c1.stats.speed < c2.stats.speed) return 1;
    return 0;
}

/// @param {Struct.GS_Battle} gs
function battle_turn_cam_target(gs) {
    var current_char = gs.turn_order[gs.current_turn];
    var is_enemy_turn = array_contains(gs.enemies, current_char);
    var cam_pos;

    if (is_enemy_turn) {
        cam_pos = gs.chars_mid(gs.party).normalize().scale(TILE_SIZE*2);
        cam_pos.z = 40;
    } else {
        var lp = current_char.look_pos();
        var dist = lp.len();
        cam_pos = lp.normalize().scale(dist+TILE_SIZE*0.5);
        cam_pos.z = 15;
    }

    var cam_fwd = current_char.look_pos().subv(cam_pos).normalize();
    return [cam_pos, cam_fwd];
}

enum BATTLE_STATE { TURN, ANIMATION };

/// @param {Struct.GS_Dungeon} _gs
/// @param {Array<Struct.Character>} _enemies
/// @param {Enum.INITIATIVE} _initiative
function GS_Battle(
    _gs,
    _enemies,
    _initiative
) : Game_State() constructor {
    gs = _gs;
    party = gs.party;
    enemies = _enemies;
    initiative = _initiative;
    /// @type {Array<Struct.Character>}
    turn_order = [];
    current_turn = 0;
    state = BATTLE_STATE.TURN;

    cam_pos = new v3(0, 0, 30);
    cam_fwd = new v3(0, 0, -1);

    static no_initiative_positions = [
        new v3(-0.5*TILE_SIZE, TILE_SIZE, 0),
        new v3( 0.5*TILE_SIZE, TILE_SIZE, 0),
        new v3(    -TILE_SIZE, TILE_SIZE*1.5, 0),
        new v3(     TILE_SIZE, TILE_SIZE*1.5, 0),
    ];

    static initiative_positions = [
        new v3(-0.75*TILE_SIZE, -TILE_SIZE, 0),
        new v3( 0.75*TILE_SIZE, -TILE_SIZE, 0),
        new v3( 1.75*TILE_SIZE, -TILE_SIZE*0.25, 0),
        new v3(-1.75*TILE_SIZE, -TILE_SIZE*0.25, 0),
    ];

    /// @param {Array<Struct.Character>} chars
    static chars_mid = function(chars) {
        var mid = new v3(0, 0, 0);
        for (var i=0; i<array_length(chars); i++) {
            mid.addv(chars[i].look_pos());
        }
        mid.scale(1/array_length(chars));
        return mid;
    }

    static init = function () {
        if (initiative == INITIATIVE.ENEMY) {
            array_sort(enemies, sort_chars_by_speed);
            for (var i=0; i<array_length(enemies); i++) {
                array_push(turn_order, enemies[i]);
                enemies[i].pos.setv(initiative_positions[i]);
            }

            array_sort(party, sort_chars_by_speed);
            for (var i=0; i<array_length(party); i++) {
                array_push(turn_order, party[i]);
                party[i].pos.setv(no_initiative_positions[i]);
            }
        } else if (initiative == INITIATIVE.PARTY) {
            array_sort(party, sort_chars_by_speed);
            for (var i=0; i<array_length(party); i++) {
                array_push(turn_order, party[i]);
                party[i].pos.setv(initiative_positions[i]);
            }

            array_sort(enemies, sort_chars_by_speed);
            for (var i=0; i<array_length(enemies); i++) {
                array_push(turn_order, enemies[i]);
                enemies[i].pos.setv(no_initiative_positions[i]);
            }
        } else {
            for (var i=0; i<array_length(party); i++) {
                array_push(turn_order, party[i]);
                party[i].pos.setv(initiative_positions[i]);
            }
            for (var i=0; i<array_length(enemies); i++) {
                array_push(turn_order, enemies[i]);
                enemies[i].pos.setv(no_initiative_positions[i]);
            }
            array_sort(turn_order, sort_chars_by_speed);
        }
    }

    static render = function () {
        do_3d(600, cull_noculling);
        update_animations();

        draw_clear(gpu_get_fog()[1]);

        for (var i=0; i<array_length(turn_order); i++) {
            if (keyboard_check_pressed(ord(string(i+1)))) {
                current_turn = i;
            }
        }

        var current_char = turn_order[current_turn];

        static freeze_cam = false;
        if (keyboard_check_pressed(vk_end)) {
            freeze_cam = !freeze_cam;
        }

        switch (state) {
            case BATTLE_STATE.TURN:
                var cam_tf = battle_turn_cam_target(self);
                if (!freeze_cam) {
                    cam_pos.lerpv(cam_tf[0], 0.1);
                    cam_fwd.lerpv(cam_tf[1], 0.1);
                }
            break;

            case BATTLE_STATE.ANIMATION:
            break;
        }

        static wheel = function() { return mouse_wheel_up() - mouse_wheel_down(); }

        if (freeze_cam) {
            if (keyboard_check(ord("Q"))) cam_pos.x += wheel();
            if (keyboard_check(ord("W"))) cam_pos.y += wheel();
            if (keyboard_check(ord("E"))) cam_pos.z += wheel();
            if (keyboard_check(ord("A"))) cam_fwd.x += wheel();
            if (keyboard_check(ord("S"))) cam_fwd.y += wheel();
            if (keyboard_check(ord("D"))) cam_fwd.z += wheel();
        }

        var lookat = cam_pos.copy().addv(cam_fwd);
        camera = camera_get_active();
        camera_set_view_mat(camera, matrix_build_lookat(cam_pos.x, cam_pos.y, cam_pos.z, lookat.x, lookat.y, lookat.z, 0, 0, 1));
        camera_set_proj_mat(camera, matrix_build_projection_perspective_fov(-60, -WW/WH, 1, 32000));
        camera_apply(camera);

        matrix_set(matrix_world, mtx_mul(
            mtx_scl(30*TILE_SIZE, 30*TILE_SIZE, 1),
            mtx_mov(-15*TILE_SIZE, -15*TILE_SIZE, 0),
        ));
        vertex_submit(global.v_floor_battle, pr_trianglelist, sprite_get_texture(spr_floor_brick, 0));

        for (var i=0; i<array_length(turn_order); i++) {
            var char = turn_order[i];

            var look_dir = new v3(1, 1, 0).normalize();
            if (array_contains(enemies, char)) {
                look_dir.setv(chars_mid(party).subv(char.pos)).normalize();
            } else {
                look_dir.setv(chars_mid(enemies).subv(char.pos)).normalize();
            }

            var rot = point_direction(0, 0, look_dir.x, look_dir.y);
            var pos = char.render_pos();
            matrix_set(matrix_world, mtx_mul(
                mtx_scl(char.size, char.size, char.size),
                mtx_rot(0, 0, rot),
                mtx_mov(pos.x, pos.y, pos.z)
            ));

            shader_set(sh_smf_animate);
            render_model_simple(char.model, $"battle:{i}", char.texture);
            shader_reset();
        }

        matrix_set(matrix_world, matrix_build_identity());
    }
}