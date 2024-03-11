/// @param {string} _name
/// @param {Struct.Stats} _stats
/// @param {string} _model
/// @param {Asset.GMSprite} _texture
/// @param {real} _size
/// @param {bool} _floating
function Character(_name, _stats, _model, _texture, _size, _floating) constructor {
    name = _name;
    stats = _stats;
    model = _model;
    texture = _texture;
    icon = asset_get_index(sprite_get_name(_texture) + "_icon");
    assert(icon!=-1, $"Failed to find sprite: {sprite_get_name(_texture) + "_icon"}")
    size = _size;
    floating = _floating;
    hp = stats.max_hp;

    pos = new v3(0, 0, 0);
    fwd = new v3(1, 1, 0);

    static look_pos = function() {
        var out = pos.copy().add(0, 0, size);
        if (floating) out.add(0, 0, size*2);
        return out;
    }

    death_time = undefined;

    static render_pos = function() {
        if (!floating) return pos.copy();
        var p = look_pos().add(0, 0, sin(current_time/1000)*size*0.1);
        if (hp == 0) {
            death_time = death_time ?? current_time;
            var time = clamp((current_time - death_time)/500, 0, 1);
            return p.lerpv(pos.copy().add(0, 0, size*0.75), time);
        }
        return p;
    }

    /// @param {Struct.Character} attacker
    /// @param {real} damage
    static damaged_by = function(attacker, damage) {
        hp = clamp(hp-damage, 0, stats.max_hp);
    }

    /// @param {real} x
    /// @param {real} y
    /// @param {bool} hl
    static draw_head = function(x, y, hl) {
        draw_set_color(c_white);
        shader_set(sh_flat);
        draw_sprite(icon, 0, x+5 + hl*5, y+5 + hl*5);
        shader_reset();

        var perc = clamp(hp/stats.max_hp, 0, 1);

        var w = 64;
        var h = 10;
        var p = 2;

        draw_sprite(icon, 0, x, y);
        draw_set_color(c_white);
        draw_rectangle(x, y+60, x+w, y+60+h, false);

        draw_set_color(c_blue);
        draw_rectangle(x+p, y+60+p, x+(w-p)*perc, y+60+h-p, false);
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
    /// @type {Struct.v3}
    var cam_pos = undefined;

    if (is_enemy_turn) {
        cam_pos = gs.chars_mid(gs.party).scale(2).setz(40);
    } else {
        var lp = current_char.look_pos();
        cam_pos = lp.subv(current_char.fwd.copy().normalize().setz(0).zrotate(45).scale(TILE_SIZE)).setz(20);
    }

    var cam_fwd = current_char.look_pos().addv(current_char.fwd.copy().scale(TILE_SIZE*0.5)).subv(cam_pos).normalize();
    return [cam_pos, cam_fwd];
}

enum BATTLE_STATE { TURN, ANIMATION };

/// @param {Struct.Character} _char
/// @param {string|Undefined} _anim_name
/// @param {real} _spd
function Seq_Anim(_char, _anim_name, _spd) constructor {
    char = _char;
    anim_name = _anim_name;
    spd = _spd;
}

/// @param {Struct.v3} _pos
/// @param {Struct.v3} _look_at
function Seq_Cam(_pos, _look_at) constructor {
    pos = _pos;
    look_at = _look_at;
}

/// @param {Struct.Character} _char
/// @param {Struct.v3} _target
/// @param {real} _time
function Seq_Move(_char, _target, _time) constructor {
    char = _char;
    target = _target;
    time = _time;
}

/// @param {real} _time
function Seq_Wait(_time) constructor {
    time = _time;
}

/// @param {Function} _fn
/// @param {Array} _args
function Seq_Do(_fn, _args) constructor {
    fn = _fn;
    args = _args;
}

enum BATTLE_MENU { MAIN, ITEMS, ENEMIES };

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
    /// @type {Struct.Item}
    menu_item = undefined;
    menu = BATTLE_MENU.MAIN;
    ui = new UI();

    /// @type {Struct.Seq_Anim | Struct.Seq_Do | Struct.Seq_Move | Struct.Seq_Wait | Struct.Seq_Cam}
    current_seq_item = undefined;
    /// @type {Struct.Seq_Anim | Struct.Seq_Do | Struct.Seq_Move | Struct.Seq_Wait | Struct.Seq_Cam}
    seq_item_start = undefined;
    /// @type {Struct.v3}
    lerp_from = undefined;
    /// @type {Array<Struct.Seq_Anim | Struct.Seq_Do | Struct.Seq_Move | Struct.Seq_Wait | Struct.Seq_Cam>}
    sequence = [];

    cam_target_pos = new v3(0, 0, 30);
    cam_target_fwd = new v3(0, 0, -1);

    cam_pos = new v3(0, 0, 30);
    cam_fwd = new v3(0, 0, -1);

    will_run = -1;

    outline = -1;

    enter_duration = 500;
    exit_duration = 1000;

    static no_initiative_positions = [
        new v3(0, TILE_SIZE*0.5, 0),
        new v3(-TILE_SIZE*0.75, TILE_SIZE*1.25, 0),
        new v3( TILE_SIZE*0.75,  TILE_SIZE*1.25, 0),
    ];

    static initiative_positions = [
        new v3(0, -TILE_SIZE, 0),
        new v3(-TILE_SIZE, 0, 0),
        new v3( TILE_SIZE, 0, 0),
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

    static is_party_turn = function() {
        return state == BATTLE_STATE.TURN && array_contains(party, turn_order[current_turn])
    }

    static is_enemy_turn = function() {
        return state == BATTLE_STATE.TURN && array_contains(enemies, turn_order[current_turn])
    }

    static default_look_dir = function(char) {
        var look_dir = new v3(1, 1, 0);
        if (array_contains(enemies, char)) {
            look_dir.setv(chars_mid(party));
        } else {
            look_dir.setv(chars_mid(enemies));
        }
        return look_dir.subv(char.pos).normalize();
    }

    static init = function () {
        audio_play_sound(mus_s1, 1, true);
        audio_sound_gain(mus_s1, 0, 0);
        audio_sound_gain(mus_s1, 1, 100);

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

        for (var i=0; i<array_length(turn_order); i++) {
            var char = turn_order[i];
            anim_char(char, "idle", 0.01, 1);
            char.fwd.setv(default_look_dir(char));
        }

        var ct = battle_turn_cam_target(self);
        cam_target_pos = ct[0];
        cam_target_fwd = ct[1];
    }

    static stop_music = function() {
        audio_sound_gain(mus_s1, 0, 500);
        after(500, function() {
            audio_sound_set_track_position(mus_s1, 0);
            audio_stop_sound(mus_s1);
        }, []);
    }

    static end_battle = function() {
        set_game_state(gs, false, true);
        stop_music();
    }

    /// @param {Struct.Character} char
    /// @param {string} anim_name
    /// @param {real} spd
    /// @param {real} lspd
    static anim_char = function(char, anim_name, spd, lspd) {
        var idx = array_get_index(turn_order, char);
        animation_play(char.model, $"battle:{idx}", anim_name, spd, lspd, true);
    }

    static update = function () {
        if (entering()||exitting()) { return }

        if (state == BATTLE_STATE.TURN) {
            if (array_all(enemies, function(e) {return e.hp==0})) {
                end_battle();
            }

            if (array_all(party, function(e) {return e.hp==0})) {
                stop_music();
                set_game_state(new GS_Main_Menu());
            }

            for (var i=0; i<array_length(turn_order); i++) {
                if (keyboard_check_pressed(ord(string(i+1)))) {
                    current_turn = i;
                    var ct = battle_turn_cam_target(self);
                    cam_target_pos = ct[0];
                    cam_target_fwd = ct[1];
                }
            }
        }

        if (state == BATTLE_STATE.ANIMATION) {
            if (is_undefined(current_seq_item)) {
                if (array_length(sequence) == 0) {
                    var char = turn_order[current_turn];
                    char.fwd = default_look_dir(char);

                    for (var i=0; i<array_length(turn_order); i++) {
                        var ch = turn_order[i];
                        if (ch.hp <= 0) anim_char(ch, "death", 0.1, 1);
                    }

                    current_turn = (current_turn+1)%array_length(turn_order);
                    char = turn_order[current_turn];
                    while (char.hp <= 0) {
                        current_turn = (current_turn+1)%array_length(turn_order);
                        char = turn_order[current_turn];
                    }

                    state = BATTLE_STATE.TURN;
                    var ct = battle_turn_cam_target(self);
                    cam_target_pos = ct[0];
                    cam_target_fwd = ct[1];
                    return;
                }

                current_seq_item = sequence[0];
                array_shift(sequence);
                seq_item_start = current_time;

                if (is_instanceof(current_seq_item, Seq_Wait)) {
                    /// @type {Struct.Seq_Wait}
                    var w = current_seq_item;
                    after(w.time, function(battle) { battle.current_seq_item = undefined; }, [self]);

                } else if (is_instanceof(current_seq_item, Seq_Move)) {
                    /// @type {Struct.Seq_Move}
                    var m = current_seq_item;
                    lerp_from = m.char.pos.copy();
                    after(m.time, function(battle) { battle.current_seq_item = undefined; }, [self]);

                } else if (is_instanceof(current_seq_item, Seq_Anim)) {
                    /// @type {Struct.Seq_Anim}
                    var a = current_seq_item;
                    if (a.anim_name == "default") {
                        if (a.char.hp == 0) {
                            anim_char(a.char, "death", a.spd, 0.2);
                        } else if (a.char.hp < a.char.stats.max_hp*0.33) {
                            anim_char(a.char, "idle_hurt", a.spd, 0.2);
                        } else {
                            anim_char(a.char, "idle", a.spd, 0.2);
                        }

                    } else {
                        anim_char(a.char, a.anim_name, a.spd, 0.2);
                    }
                    current_seq_item = undefined;

                } else if (is_instanceof(current_seq_item, Seq_Do)) {
                    /// @type {Struct.Seq_Do}
                    var d = current_seq_item;
                    script_execute_ext(d.fn, d.args);
                    current_seq_item = undefined;

                } else if (is_instanceof(current_seq_item, Seq_Cam)) {
                    /// @type {Struct.Seq_Cam}
                    var c = current_seq_item;
                    cam_target_pos = c.pos;
                    cam_target_fwd = c.look_at.subv(c.pos).normalize();
                    current_seq_item = undefined;
                }

            } else if (is_instanceof(current_seq_item, Seq_Move)) {
                /// @type {Struct.Seq_Move}
                var m = current_seq_item;
                var amt = clamp((current_time-seq_item_start)/m.time, 0, 1);
                m.char.pos.setv(lerp_from).lerpv(m.target, amt);
                m.char.fwd.setv(m.target).subv(lerp_from).normalize();
                if (amt == 1) current_seq_item = undefined;
            }
        } else if (is_enemy_turn()) {
            var enemy = turn_order[current_turn];
            var old_pos = enemy.pos.copy();
            /// @type {Struct.Character}
            var target = pick_arr(array_filter(party, function(p) { return p.hp > 0; }));
            var target_dir = target.pos.copy().subv(enemy.pos).normalize();
            var target_pos = target.pos.copy().subv(target_dir.copy().scale(enemy.size*0.75));

            if (enemy.floating) target_pos.z -= enemy.size;

            var new_cam_pos = target.look_pos().addv(target_dir.copy().zrotate(90).scale(TILE_SIZE));
            sequence = [
                new Seq_Wait(500),
                new Seq_Cam(new_cam_pos, target.look_pos()),
                new Seq_Anim(enemy, "idle", 0.01),
                new Seq_Move(enemy, target_pos, 500),
                new Seq_Anim(enemy, "attack", 0.03),
                new Seq_Wait(250),
                new Seq_Anim(target, "damage", 0.02),
                new Seq_Do(function(t, e){ t.damaged_by(e, 10); }, [target, enemy]),
                new Seq_Wait(250),
                new Seq_Anim(target, "default", 0.02),
                new Seq_Anim(enemy, "default", 0.01),
                new Seq_Move(enemy, old_pos, 500),
            ];
            state = BATTLE_STATE.ANIMATION;

        } else if (is_party_turn() && current_turn == will_run) {
            show_notif("Ran away!");
            end_battle();
        }
    }

    static gui = function() {
        outline = -1;
        do_2d();

        if (entering()||exitting()) {
            draw_set_color(c_black);
            draw_set_alpha(1-animate_io());
            draw_rectangle(0, 0, WW, WH, false);
            draw_set_alpha(1);
            return;
        }

        var Y = WH*0.33;
        for (var i=0; i<array_length(enemies); i++) {
            var e = enemies[i];
            e.draw_head(10, Y, turn_order[current_turn]==e);
            Y += 84;
        }

        Y = WH*0.33;
        for (var i=0; i<array_length(party); i++) {
            var c = party[i];
            c.draw_head(WW-74, Y, turn_order[current_turn]==c);
            Y += 84;
        }

        switch (state) {
            case BATTLE_STATE.TURN:
                if (!is_party_turn()) return;
                ui.start_frame();

                ui.cursor.set(WW/4-100, WH/2);

                if (menu == BATTLE_MENU.MAIN) {

                    if (ui.button("throw", "Attack", 200)) {
                        menu_item = undefined;
                        menu = BATTLE_MENU.ENEMIES;
                    }

                    if (ui.button("use", "Use item", 200)) {
                        menu = BATTLE_MENU.ITEMS;
                    }

                    if (will_run == -1) {
                        if (ui.button("run", "Run", 200)) {
                            will_run = current_turn;
                            state = BATTLE_STATE.ANIMATION;
                            sequence = [];
                        }
                    }

                } else if (menu == BATTLE_MENU.ITEMS) {
                    /// @type {Array<Struct.Item>}
                    var inv = ds_map_keys_to_array(gs.inventory.items);
                    var hint = "";

                    for (var i=0; i<array_length(inv); i++) {
                        var item = inv[i];
                        var count = gs.inventory.items[? item];

                        ui.start_row();
                        if (ui.button($"item:{item.name}", item.name, 200)) {
                            menu_item = item;
                            menu = BATTLE_MENU.ENEMIES;
                            gs.inventory.remove(item, 1);
                        }

                        ui.color(c_white);
                        ui.bgrect(20, 20);
                        ui.color(c_black);
                        ui.label($"{count}")

                        ui.end_container();

                        if (ui.last == ui.focused) hint = item.desc;
                    }

                    ui.start_row(); ui.get_rect(100, 20); ui.label(hint); ui.end_container();

                    if (ui.button("back", "Back")) {
                        menu = BATTLE_MENU.MAIN;
                    }

                } else if (menu == BATTLE_MENU.ENEMIES) {
                    for (var i=0; i<array_length(enemies); i++) {
                        var e = enemies[i];
                        if (e.hp == 0) continue;

                        if (ui.button($"enemy:{i}", e.name, 200)) {
                            var char = turn_order[current_turn];
                            var old_pos = char.pos.copy();
                            var target_dir = e.pos.copy().subv(char.pos).normalize();
                            var target_pos = char.pos.copy().addv(target_dir);

                            var new_cam_pos1c1 = char.look_pos().lerpv(e.look_pos(), 0.5).addv(target_dir.copy().zrotate(90).scale(TILE_SIZE));
                            var new_cam_pos1c2 = char.look_pos().lerpv(e.look_pos(), 0.5).addv(target_dir.copy().zrotate(-90).scale(TILE_SIZE));
                            var new_cam_pos1 = new_cam_pos1c1;

                            var deg = 90;
                            if (new_cam_pos1c1.len() > new_cam_pos1c2.len()) {
                                new_cam_pos1 = new_cam_pos1c2;
                                deg = -90;
                            }

                            var new_cam_pos2 = char.look_pos().addv(target_dir.copy().zrotate(deg).scale(TILE_SIZE));

                            sequence = [
                                new Seq_Cam(new_cam_pos1, char.look_pos()),
                                new Seq_Anim(char, "walk", 0.01),
                                new Seq_Move(char, target_pos, 100),
                                new Seq_Anim(char, "item", 0.01),
                                new Seq_Wait(1000),
                                new Seq_Cam(new_cam_pos2, e.look_pos()),
                                new Seq_Wait(250),
                                new Seq_Anim(e, "damage", 0.02),
                                is_undefined(menu_item)
                                    ? new Seq_Do(function(t, c){ t.damaged_by(c, 100); }, [e, char])
                                    : new Seq_Do(function(t, c, i){ i.effect(c, t); }, [e, char, menu_item]),
                                new Seq_Wait(250),
                                new Seq_Anim(e, "default", 0.01),
                                new Seq_Anim(char, "walk", 0.01),
                                new Seq_Move(char, old_pos, 100),
                                new Seq_Anim(char, "default", 0.01),
                            ];
                            menu = BATTLE_MENU.MAIN;
                            state = BATTLE_STATE.ANIMATION;
                        }

                        if (ui.last == ui.focused) {
                            outline = array_get_index(turn_order, e);
                            cam_target_fwd.setv(e.look_pos().copy().subv(cam_pos));
                            cam_target_pos.z = e.look_pos().z + 10;
                        }
                    }

                    if (ui.button("back", "Back")) {
                        if (is_undefined(menu_item)) {
                            menu = BATTLE_MENU.MAIN;
                        } else {
                            menu = BATTLE_MENU.ITEMS;
                            ui.focused = $"item:{menu_item.name}";
                        }
                    }
                }

                ui.end_frame();
            break;
        }

    }

    static render = function () {
        do_3d(600, cull_noculling);
        update_animations();

        draw_clear(gpu_get_fog()[1]);

        var current_char = turn_order[current_turn];

        cam_pos.lerpv(cam_target_pos, 0.1);
        cam_fwd.lerpv(cam_target_fwd.normalize(), 0.1);

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

            var rot = point_direction(0, 0, char.fwd.x, char.fwd.y);
            var pos = char.render_pos();

            matrix_set(matrix_world, mtx_mul(
                mtx_scl(char.size, char.size, char.size),
                mtx_rot(0, 0, rot),
                mtx_mov(pos.x, pos.y, pos.z)
            ));

            shader_set(sh_smf_animate);

            static uni_col = shader_get_uniform(sh_smf_animate, "outlineColor");
            if (outline == i) shader_set_uniform_f_array(uni_col, [255, 0, 0, 255]);
            render_model_simple(char.model, $"battle:{i}", char.texture);
            if (outline == i) shader_set_uniform_f_array(uni_col, [0, 0, 0, 0]);

            shader_reset();
        }

        matrix_set(matrix_world, matrix_build_identity());
    }
}