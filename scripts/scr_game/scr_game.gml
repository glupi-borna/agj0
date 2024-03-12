function Game_State() constructor {
    name = "UNKNOWN";
    /// @type {real}
    state_start = undefined;
    /// @type {real|undefined}
    state_end = undefined;

    /// @type {real}
    enter_duration = 0;
    /// @type {real}
    exit_duration = 0;
    /// @type {Struct.Game_State|undefined}
    next_state = undefined;

    static entering = function() {
        return is_undefined(next_state) && current_time - state_start < enter_duration;
    }

    static exitting = function() {
        return !is_undefined(next_state);
    }

    /// @param {real} duration
    static animate = function(duration) {
        return ui_anim(state_start, current_time, duration);
    }

    /// @param {real} duration
    static animate_in = function(duration) {
        return ui_anim(state_start, current_time, duration);
    }

    /// @param {real} duration
    static animate_out = function(duration) {
        return ui_anim(state_end, current_time, duration);
    }

    static animate_io = function() {
        if (exitting()) {
            return 1-animate_out(exit_duration);
        } else {
            return animate_in(enter_duration);
        }
    }

    static init = function() {};
    static update = function() {};
    static render = function() {};
    static gui = function() {};
}

/// @type {Struct.Game_State}
global.game_state = new GS_Main_Menu();
global.game_state.state_start = current_time;
global.skip_next_init = false;

/// @param {Struct.Game_State} gs
function set_game_state(gs, no_exit=false, no_init=false) {
    global.skip_next_init = no_init;
    global.game_state.next_state = gs;
    if (no_exit) {
        global.game_state.state_end = current_time-global.game_state.exit_duration;
        update_game_state();
    } else {
        global.game_state.state_end = current_time;
    }
}

function update_game_state() {
    if (!is_undefined(global.game_state.next_state)) {
        var exit_time = current_time - global.game_state.state_end;
        if (exit_time >= global.game_state.exit_duration) {
            var gs = global.game_state.next_state;
            global.game_state.next_state = undefined;
            global.game_state.state_end = undefined;
            global.game_state = gs;
            if (global.skip_next_init) {
                global.game_state.state_start = current_time - global.game_state.enter_duration;
            } else {
                global.game_state.state_start = current_time;
                global.game_state.init();
            }
            global.skip_next_init = false;
        }
    }

    global.game_state.update();
}

/// @param {Struct.Dungeon} d
/// @param {real} px
/// @param {real} py
/// @param {real} radius
function collision_at(d, px, py, radius) {
    var xx = floor(px/TILE_SIZE);
    var yy = floor(py/TILE_SIZE);

    var minx = floor((px-radius)/TILE_SIZE);
    var maxx = floor((px+radius)/TILE_SIZE);
    var miny = floor((py-radius)/TILE_SIZE);
    var maxy = floor((py+radius)/TILE_SIZE);

    for (var tx=minx; tx<=maxx; tx++) {
        for (var ty=miny; ty<=maxy; ty++) {
            var t = d.tile_at(tx, ty);
            var c = t.collider();
            if (is_undefined(c)) continue;
            var rx = tx * TILE_SIZE;
            var ry = ty * TILE_SIZE;
            var cx = rx + TILE_SIZE*c.x;
            var cy = ry + TILE_SIZE*c.y;
            var cw = TILE_SIZE*c.w;
            var ch = TILE_SIZE*c.h;
            if (rectangle_in_circle(cx, cy, cx+cw, cy+ch, px, py, radius) != 0) {
                return true;
            }
        }
    }
    return false;
};

function move(d, pos, x, y, radius) {
    var xx = x;
    var yy = y;
    var old = pos.copy();

    while (x != 0 || y != 0) {
        var xstep = clamp(x, -1, 1);
        var ystep = clamp(y, -1, 1);

        var moved = false;
        if (x != 0) {
            if (!collision_at(d, pos.x+xstep, pos.y, 6)) {
                pos.x += xstep;
                x -= xstep;
                moved = true;
            }
        }

        if (y != 0) {
            if (!collision_at(d, pos.x, pos.y+ystep, 6)) {
                pos.y += ystep;
                y -= ystep;
                moved = true;
            }
        }

        if (!moved) break;
    }

    return x==0 && y==0;
}

/// @param {real} _lvl
/// @param {real} _max_hp
/// @param {real} _speed
function Stats(
    _lvl,
    _max_hp,
    _speed
) constructor {
    lvl = _lvl
    max_hp = _max_hp;
    speed = _speed;
}

/// @param {string} _name
/// @param {string} _model
/// @param {Asset.GMSprite} _tex
/// @param {real} _size
/// @param {bool} _floating
/// @param {Struct.Stats} _stats
function Enemy(_name, _model, _tex, _size, _floating, _stats) constructor {
    name = _name;
    model = _model;
    texture = _tex;
    size = _size;
    floating = _floating;
    stats = _stats;

    static char = function() {
        return new Character(name, stats, model, texture, size, floating);
    }
}

/// @param {real} lvl
function mouth(lvl) {
    return new Enemy(
        "Mouth", "mouth", spr_mouth, 12, true,
        new Stats(lvl, 50+lvl*5, 10+lvl*1)
    );
}

function get_enemy(lvl) {
    var fn = choose(mouth, mouth);
    return fn(lvl);
}

enum DE_STATE { WAIT, WANDER, CHASE, ATTACK };

/// @param {Struct.Enemy} _data
function Dungeon_Enemy(_data) constructor {
    data = _data;
    pos = new v3(0, 0, 0);
    fwd = new v3(1, 1, 0).normalize();
    look_dir = fwd.copy();
    state = DE_STATE.WAIT;
    state_time = current_time;
    wait_time = irandom_range(0, 5000);

    /// @param {Struct.Dungeon} d
    /// @param {Struct.Dungeon_Player} p
    static can_see_player = function(d, p) {
        var p_dir = point_direction(pos.x, pos.y, p.pos.x, p.pos.y);
        var l_dir = point_direction(0, 0, look_dir.x, look_dir.y);
        if (abs(angle_difference(p_dir, l_dir)) > 45) return false;
        var dist = point_distance(pos.x, pos.y, p.pos.x, p.pos.y);
        if (dist > 150) return false;
        return true;
    }

    /// @param {Struct.Dungeon} d
    /// @param {Struct.Dungeon_Player} p
    static update = function(d, p) {
        var player_dist = point_distance_3d(p.pos.x, p.pos.y, p.pos.z, pos.x, pos.y, pos.z);
        if (player_dist > TILE_SIZE*15) return;

        switch (state) {
            case DE_STATE.ATTACK:
                if (current_time - state_time > wait_time) {
                    /// @type {Array<Struct.Dungeon_Enemy>}
                    var enemies = [];
                    for (var i=0; i<array_length(global.game_state.enemies); i++) {
                        var e = global.game_state.enemies[i];
                        if (point_distance(pos.x, pos.y, e.pos.x, e.pos.y) < TILE_SIZE*2) {
                            array_push(enemies, e);
                            if (array_length(enemies) == 3) break;
                        }
                    }

                    after(500, function(enemies, gs) {
                        for (var i=0; i<array_length(enemies); i++) {
                            array_delete(gs.enemies, array_get_index(gs.enemies, enemies[i]), 1)
                        }
                    }, [enemies, global.game_state]);

                    /// @type {Array<Struct.Character>}
                    var enemy_chars = array_map(
                        enemies,
                        /// @param {Struct.Dungeon_Enemy} e
                        function(e) {return e.data.char()}
                    );

                    set_game_state(
                        new GS_Battle(global.game_state, enemy_chars, INITIATIVE.ENEMY)
                    );
                    state = DE_STATE.CHASE;
                }
            break;

            case DE_STATE.CHASE:
                animation_play(data.model, $"{data.name}:dungeon", "idle", 0.01, 1);
                if (!can_see_player(d, p)) {
                    state_time = current_time;
                    state = DE_STATE.WANDER;
                    wait_time = irandom_range(5000, 10000);
                } else {
                    fwd.setv(p.pos).subv(pos).normalize();
                    move(d, pos, fwd.x, fwd.y, 6);
                    var dist = point_distance_3d(p.pos.x, p.pos.y, p.pos.z, pos.x, pos.y, pos.z);
                    if (dist < data.size) {
                        state = DE_STATE.ATTACK;
                        state_time = current_time;
                        wait_time = 500;
                        animation_play(data.model, $"{data.name}:dungeon_attack", "attack", 0.03, 1, true);
                    }
                }
            break;

            case DE_STATE.WAIT:
                animation_play(data.model, $"{data.name}:dungeon", "idle", 0.01, 1);
                if (current_time - state_time > wait_time) {
                    state_time = current_time;
                    fwd.set(random_range(-1, 1), random_range(-1, 1), 0).normalize();
                    state = DE_STATE.WANDER;
                    wait_time = irandom_range(5000, 10000);
                }
            break;

            case DE_STATE.WANDER:
                animation_play(data.model, $"{data.name}:dungeon", "idle", 0.01, 1);
                if (current_time - state_time > wait_time) {
                    state_time = current_time;
                    state = DE_STATE.WAIT;
                    wait_time = irandom_range(1000, 5000);
                }

                if (!move(d, pos, fwd.x*0.5, fwd.y*0.5, 6)) {
                    state_time = current_time;
                    state = DE_STATE.WAIT;
                    wait_time = irandom_range(1000, 3000);
                }
            break;
        }

        if (state != DE_STATE.CHASE && state != DE_STATE.ATTACK) {
            if (can_see_player(d, p)) {
                state = DE_STATE.CHASE;
            }
        }
    }

    static render = function () {
        look_dir.lerpv(fwd, 0.2);

        var rot = point_direction(0, 0, look_dir.x, look_dir.y);
        var float_offset = 0;

        if (data.floating) {
            var mul = 0.1;
            var spd = current_time/1000;
            if (state != DE_STATE.WAIT) mul = 0.25;
            if (state == DE_STATE.CHASE) spd *= 2;
            float_offset = data.size*2 + sin(spd)*data.size*mul;
        }

        matrix_set(matrix_world, mtx_mul(
            mtx_scl(data.size, data.size, data.size),
            mtx_rot(0, 0, rot),
            mtx_mov(pos.x, pos.y, pos.z + float_offset)
        ));

        shader_set(sh_smf_animate);
        if (state == DE_STATE.ATTACK) {
            render_model_simple(data.model, $"{data.name}:dungeon_attack", data.texture);
        } else {
            render_model_simple(data.model, $"{data.name}:dungeon", data.texture);
        }
        shader_reset();
    }
}

enum DP_STATE { IDLE, WALK };

/// @param {Asset.GMSprite} tex
function Dungeon_Party(tex) constructor {
    pos = new v3(0, 0, 0);
    fwd = new v3(1, 1, 0).normalize();
    look_dir = fwd.copy();
    formation_offset = 0;
    texture = tex;

    state = DP_STATE.IDLE;

    /// @param {Struct.Dungeon_Player}
    static target_pos = function(p) {
        var target = p.pos.copy().subv(p.fwd.copy().scale(16));
        if (formation_offset != 0) {
            target.addv(p.fwd.copy().zrotate(-90).scale(16*formation_offset));
        }
        return target;
    }

    /// @param {Struct.Dungeon} d
    /// @param {Struct.Dungeon_Player} p
    static update = function(d, p) {
        var target = target_pos(p);
        var old_pos = pos.copy();
        var mv = target.copy().subv(pos);
        var dist = mv.len();

        switch (state) {
            case DP_STATE.IDLE:
                if (dist > 16) {
                    state = DP_STATE.WALK;
                }
            break;

            case DP_STATE.WALK:
                if (dist < 1) {
                    state = DP_STATE.IDLE;
                } else {
                    fwd = mv.copy().normalize();
                    if (dist < TILE_SIZE*4) {
                        mv.normalize().scale(2);
                        move(d, pos, mv.x, mv.y, 6);
                    } else if (dist >= TILE_SIZE*4) {
                        mv.scale(0.5);
                        pos.addv(mv);
                    }
                }
            break;
        }

        var movement = pos.copy().subv(old_pos);
        if (movement.len() > 1) {
            var anim_spd = 0.015 * movement.len();
            animation_play("char", $"party:{formation_offset}", "walk", anim_spd, 0.2);
        } else {
            animation_play("char", $"party:{formation_offset}", "idle", 0.015, 0.2);
        }
    }

    static render = function() {
        look_dir.lerpv(fwd, 0.2);

        var rot = point_direction(0, 0, look_dir.x, look_dir.y);
        matrix_set(matrix_world, mtx_mul(
            mtx_scl(12, 12, 12),
            mtx_rot(0, 0, rot),
            mtx_mov(pos.x, pos.y, pos.z)
        ));

        shader_set(sh_smf_animate);
        render_model_simple("char", $"party:{formation_offset}", texture);
        shader_reset();
    }
}

function Dungeon_Player() constructor {
    pos = new v3(0, 0, 0);
    movement = new v3(0, 0, 0);
    fwd = new v3(1, 1, 0).normalize();

    /// @param {Struct.Dungeon} dungeon
    static update = function (dungeon) {
        var old_pos = pos.copy();
        fwd.normalize();
        var walk_speed = 2;
        var mv = new v3(0, 0, 0);
        if (keyboard_check(ord("W")) || keyboard_check(vk_up)) mv.addv(fwd.copy().scale(walk_speed));
        if (keyboard_check(ord("S")) || keyboard_check(vk_down)) mv.addv(fwd.copy().neg().scale(walk_speed));
        if (keyboard_check(ord("A")) || keyboard_check(vk_left)) fwd.zrotate(-4);
        if (keyboard_check(ord("D")) || keyboard_check(vk_right)) fwd.zrotate(4);

        movement.addv(mv.copy().subv(movement).scale(0.2));
        move(dungeon, pos, movement.x, movement.y, 6);

        var lerp_spd = animation_is_playing("char", "player") ? 1 : 0.2;
        if (old_pos.copy().subv(pos).len() < 0.5) {
            animation_play("char", "player", "idle", 0.01, lerp_spd);
        } else {
            var fwd_dir = point_direction(0, 0, fwd.x, fwd.y);
            var mv_dir = point_direction(0, 0, movement.x, movement.y);
            var anim_spd = 0.015 * movement.len();
            animation_play("char", "player", "walk", anim_spd, lerp_spd);
        }
    }

    static render = function() {
        var rot = point_direction(0, 0, fwd.x, fwd.y);
        matrix_set(matrix_world, mtx_mul(
            mtx_scl(12, 12, 12),
            mtx_rot(0, 0, rot),
            mtx_mov(pos.x, pos.y, pos.z)
        ));

        shader_set(sh_smf_animate);
        render_model_simple("char", "player", spr_player);
        shader_reset();
    }
}

/// @param {Struct.Dungeon} dungeon
/// @param {Struct.v3} cam_pos
/// @param {Struct.v3} cam_target
function get_cam_pos(dungeon, cam_pos, cam_target) {
    var min_pos = cam_pos.copy();
    var max_pos = cam_target.copy();
    var step = 0;
    var check_pos = min_pos.copy();
    while (step < 8) {
        check_pos.setv(min_pos).addv(max_pos).scale(0.5);
        if (collision_at(dungeon, check_pos.x, check_pos.y, 3)) {
            max_pos.setv(check_pos);
        } else {
            min_pos.setv(check_pos);
        }
        step++;
    }
    return min_pos;
}

/// @param {real} from_lvl
/// @param {real} to_lvl
/// @param {Struct.GS_Dungeon} gs
/// @param {Array<string>} _msgs
function GS_Level_Transition(from_lvl, to_lvl, gs, _msgs=undefined) : Game_State() constructor {
    name = "TRANSITION";
    enter_duration = 500;
    exit_duration = 500;
    self.from_lvl = from_lvl;
    self.to_lvl = to_lvl;
    self.gs = gs;
    msgs = _msgs;
    msg = "";

    static go_to_dungeon = function() {
        gs.lvl = to_lvl;
        gs.generate_dungeon();
        set_game_state(gs);

        if (!audio_is_playing(mus_s2)) {
            audio_play_sound(mus_s2, 1, true);
            audio_sound_gain(mus_s2, 0, 0);
            audio_sound_gain(mus_s2, 1, 500);
        }
    }

    static max_depth = -1;

    /// @param {Array<string>} _msgs
    static first_time_msg = function(_msgs) {
        if (max_depth > from_lvl) return [];
        return _msgs;
    }

    static init = function() {
        if (is_undefined(msgs)) {
            if (from_lvl == 0 && to_lvl == 1) {
                msgs = first_time_msg([
                    "Hubris.",
                    "That's why they're here.\nThat's why we're here.",
                    "The details are muddy.\nNobody knows for sure what happened.",
                    "However, we believe\nthat the AI has become conscious.",
                    "Now consciousness is seeping through the cracks.",
                    "It is too late.\nOur heroes are long gone.\nWe are what remains.",
                    "We must descend into the depths,\nbeneath the facility where it all started.",
                ]);
            } else if (from_lvl == 1 && to_lvl == 2) {
                msgs = first_time_msg(["It's hard to believe that this is the basement of an office building."]);
            } else if (from_lvl == 2 && to_lvl == 3) {
                msgs = first_time_msg(["The floors rumble and the walls shift\neach time we descend."]);
            } else if (from_lvl == 3 && to_lvl == 4) {
                msgs = first_time_msg(["Those things are getting tougher."]);
            } else if (from_lvl == 4 && to_lvl == 5) {
                msgs = first_time_msg(["..."]);
            } else if (from_lvl == to_lvl) {
                msgs = [
                    choose(
                        "We were bested.",
                        "We were defeated.",
                        "Nobody remembers what happened.",
                        "They got us."
                    ),
                    choose(
                        "When we came to, we were back at the stairs.",
                        "When we woke up, the enemy was nowhere to be seen.",
                        "How are we still alive?"
                    )
                ];
            } else {
                /// @type {Array<string>}
                msgs = [];
            }
        }

        max_depth = max(to_lvl, max_depth);

        if (array_length(msgs) == 0) {
            go_to_dungeon();
        } else {
            msg = array_shift(msgs);
        }
    }

    static update = function() {
        if (entering() || exitting()) return;

        if (kbd_pressed(vk_enter, "Enter", "Next")) {
            if (array_length(msgs) == 0) {
                go_to_dungeon();
            } else {
                set_game_state(new GS_Level_Transition(from_lvl, to_lvl, gs, msgs));
            }
        }

        if (kbd_pressed(vk_escape, "ESC", "Skip")) {
            go_to_dungeon();
        }
    }

    static gui = function() {
        do_2d();

        draw_set_color(c_black);
        draw_rectangle(0, 0, WW, WH, false);

        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text(WW/2, WH/2, msg);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        if (entering()||exitting()) {
            draw_set_color(c_black);
            draw_set_alpha(1-animate_io());
            draw_rectangle(0, 0, WW, WH, false);
            draw_set_alpha(1);
        }
    }
}

function GS_Dungeon() : Game_State() constructor {
    name = "DUNGEON";
    /// @type {Struct.Dungeon}
    dungeon = new Dungeon(50, 50);

    inventory = new Inventory();

    /// @type {Struct.Dungeon_Player}
    player = new Dungeon_Player();

    /// @type {Array<Struct.Dungeon_Party>}
    party_members = [new Dungeon_Party(spr_girl), new Dungeon_Party(spr_player)];

    party = [
        new Character(
            "Green",
            new Stats(1, 100, 3),
            "char", spr_player, 12, false
        ),
        new Character(
            "Suit",
            new Stats(1, 100, 3),
            "char", spr_player, 12, false
        ),
        new Character(
            "Girl",
            new Stats(1, 100, 3),
            "char", spr_girl, 12, false
        )
    ];

    /// @type {Array<Struct.Dungeon_Enemy>}
    enemies = [];

    lvl = 1;

    /// @type {Struct.Tile|Undefined}
    interact_tile = undefined;
    interact_tile_time = 0;
    enter_duration = 500;
    exit_duration = 500;

    static generate_dungeon = function() {
        dungeon.clear();
        dungeon.generate(lvl, [mouth], self);

        var f = -0.5;
        for (var i=0; i<array_length(party_members); i++) {
            var p = party_members[i];
            p.formation_offset = f;
            f++;
            p.pos.setv(p.target_pos(player));
        }
    }

    /// @param {real} next_lvl
    static level_transition = function(next_lvl) {
        set_game_state(new GS_Level_Transition(lvl, next_lvl, self));
    }

    static gui = function() {
        #macro GUI_TILE_SIZE (5)
        #macro WORLD_TO_GUI (GUI_TILE_SIZE/TILE_SIZE)

        do_2d();
        var px = player.pos.x * WORLD_TO_GUI;
        var py = player.pos.y * WORLD_TO_GUI;
        dungeon.render(GUI_TILE_SIZE, floor(-px+100), floor(-py+100));
        var dir = point_direction(0, 0, player.fwd.x, player.fwd.y)-45;
        draw_sprite_ext(spr_arrow, 0, 100, 100, 0.125, 0.125, dir, c_white, 1);

        if (entering()||exitting()) {
            draw_set_color(c_black);
            draw_set_alpha(1-animate_io());
            draw_rectangle(0, 0, WW, WH, false);
            draw_set_alpha(1);
        }

        /// TODO: Make popup a global thing so that the exit animation will not be bound to game_state
        static popup_width = 0;
        if (!is_undefined(interact_tile) || popup_width>=1) {
            var label = "";
            if (!is_undefined(interact_tile)) {
                label = interact_tile.interact_label();
            }
            var text_width = string_width(label);
            var target_width = text_width == 0 ? 0 : text_width+20;
            popup_width = lerp(popup_width, target_width, 0.2);
            var half = popup_width/2;

            draw_set_color(c_red);
            draw_rectangle(WW*3/4-half, WH/2, WW*3/4+half, WH/2+40, false);
            draw_set_color(c_white);

            if (popup_width > target_width-20) {
                draw_text(WW*3/4-half+10, WH/2+10, label);
            }
        }

        draw_set_color(c_white);
        interact_tile = undefined;
    }

    static update = function() {
        if (exitting()) return;

        if (keyboard_check_pressed(vk_f2)) {
            for (var i=0; i<array_length(dungeon.rooms); i++) {
                var r = dungeon.rooms[i];
                if (!r.has_tile_of_kind(TILE.WELL)) continue;
                var wp = r.find_tile_of_kind(dungeon, TILE.FLOOR);
                if (!is_undefined(wp)) {
                    player.pos.set(wp.x+0.5, wp.y+0.5, 0).scale(TILE_SIZE);
                }
            }
        }

        // if (keyboard_check_pressed(vk_f2)) {
        //     set_game_state(new GS_Battle(self, [mouth(1).char(), mouth(1).char(), mouth(1).char()], INITIATIVE.PARTY))
        // }

        player.update(dungeon);

        for (var i=0; i<array_length(enemies); i++) {
            var e = enemies[i];
            e.update(dungeon, player);
        }

        for (var i=0; i<array_length(party_members); i++) {
            var p = party_members[i];
            p.update(dungeon, player);
        }

        // if (keyboard_check_pressed(vk_tab)) {
        //     generate_dungeon();
        // }

        var pt = new v2(player.pos.x/TILE_SIZE, player.pos.y/TILE_SIZE);
        var ptf = new v2(floor(pt.x), floor(pt.y));
        dungeon.discover(ptf.x, ptf.y);

        var dir = point_direction(0, 0, player.fwd.x, player.fwd.y);
        var t1 = pt.copy();
        var t2 = new v2(t1.x+lengthdir_x(1, dir-22.5), t1.y+lengthdir_y(1, dir-22.5));
        var t3 = new v2(t1.x+lengthdir_x(1, dir+22.5), t1.y+lengthdir_y(1, dir+22.5));

        interact_tile = undefined;
        var dist = infinity;
        for (var tx=ptf.x-1; tx<=ptf.x+1; tx++) {
            for (var ty=ptf.y-1; ty<=ptf.y+1; ty++) {
                var t = dungeon.tile_at(tx, ty);
                if (!t.interactive()) continue;
                var c = t.collider();
                if (is_undefined(c)) continue;
                var rx1 = tx + c.x;
                var ry1 = ty + c.y;
                var rx2 = rx1 + c.w;
                var ry2 = ry1 + c.h;
                if (!rectangle_in_triangle(rx1, ry1, rx2, ry2, t1.x, t1.y, t2.x, t2.y, t3.x, t3.y)) continue;
                var d = point_distance(pt.x, pt.y, (rx1+rx2)/2, (ry1+ry2)/2);
                if (d < dist) {
                    interact_tile = t;
                    dist = d;
                }
            }
        }

        if (!is_undefined(interact_tile) && kbd_released(vk_enter, "Enter", "Interact")) {
            interact_tile.interact(self);
        }
    }

    static render = function() {
        do_3d();
        update_animations();

        draw_clear(gpu_get_fog()[1]);

        if (is_undefined(interact_tile)) {
            interact_tile_time = clamp(interact_tile_time-(delta_time/1000), 0, 500);
        } else {
            var is_well = interact_tile.kind == TILE.WELL;
            var is_stairs = interact_tile.kind == TILE.STAIRS || interact_tile.kind == TILE.STAIRS_CHILD;
            if (is_well || (is_stairs && interact_tile.direction==1)) {
                interact_tile_time = clamp(interact_tile_time+(delta_time/1000), 0, 500);
            } else {
                interact_tile_time = clamp(interact_tile_time-(delta_time/1000), 0, 500);
            }
        }

        var camera = camera_get_active();
        var cam_pos = player.pos.copy().add(0, 0, 20);
        var target_cam_pos = cam_pos.copy().addv(
            player.fwd.copy().neg().scale(64) // Move camera back
        ).addv(
            player.fwd.copy().zrotate(90).scale(0) // Move cam right
        );
        var lookat = player.pos.copy().add(0, 0, 20).addv(player.fwd.copy().scale(20));

        cam_pos = get_cam_pos(dungeon, cam_pos, target_cam_pos);
        cam_pos.add(0, 0, ease_io_cubic(interact_tile_time/500)*48);

        camera_set_view_mat(camera, matrix_build_lookat(cam_pos.x, cam_pos.y, cam_pos.z, lookat.x, lookat.y, lookat.z, 0, 0, 1));
        camera_set_proj_mat(camera, matrix_build_projection_perspective_fov(-60, -WW/WH, 1, 32000));
        camera_apply(camera);

        for (var yy=0; yy<dungeon.height; yy++) {
            for (var xx=0; xx<dungeon.width; xx++) {

                if (point_distance(player.pos.x, player.pos.y, xx*TILE_SIZE, yy*TILE_SIZE) > 400) continue;

                var t = dungeon.tile_at(xx, yy);
                if (t.is_floor()) render_floor(xx, yy);

                switch (t.kind) {
                    case TILE.WALL:
                        if (dungeon.tile_at(xx+1, yy).is_floor())
                            render_wall(xx+1, yy, 0, -90);

                        if (dungeon.tile_at(xx-1, yy).is_floor())
                            render_wall(xx, yy+1, 0, 90);

                        if (dungeon.tile_at(xx, yy+1).is_floor())
                            render_wall(xx+1, yy+1, 0, 180);

                        if (dungeon.tile_at(xx, yy-1).is_floor())
                            render_wall(xx, yy, 0, 0);
                    break;

                    case TILE.STAIRS:
                        render_stairs(xx, yy, t.rotation-90, t.direction);
                    break;

                    case TILE.LARGE_CHEST:
                        render_chest(xx, yy, 0, 0.4, t.open);
                    break;

                    case TILE.SMALL_CHEST:
                        render_chest(xx, yy, 0, 0.15, t.open);
                    break;

                    case TILE.WELL:
                        render_well(xx, yy, 0,  t.open!=-1);
                    break;

                    case TILE.DOOR:
                        var openness = ease_io_cubic(clamp(current_time-t.open, 0, 500)/500);
                        if (t.open == -1) openness = 0;
                        var xpdoor = dungeon.tile_at(xx+1, yy).is_floor();
                        var xmdoor = dungeon.tile_at(xx-1, yy).is_floor();
                        var ypdoor = dungeon.tile_at(xx, yy+1).is_floor();
                        var ymdoor = dungeon.tile_at(xx, yy-1).is_floor();

                        var ydoor = ypdoor - ymdoor;
                        var xdoor = xpdoor - xmdoor;

                        if (xdoor!=0 && ydoor!=0) {
                            if (xdoor != ydoor) {
                                render_door(xx-0.1, yy+1.1, openness, 45);
                                render_door(xx+0.6, yy+0.4, openness, 45);
                            } else {
                                render_door(xx-0.2, yy-0.2, openness, -45);
                                render_door(xx+0.5, yy+0.5, openness, -45);
                            }
                        } else if (ypdoor||ymdoor) {
                            render_door(xx, yy+0.5, openness, 0);
                        } else if (xpdoor||xmdoor) {
                            render_door(xx+0.5, yy, openness, -90);
                        }
                    break;
                }
            }
        }

        for (var i=0; i<array_length(enemies); i++) {
            var e = enemies[i];
            e.render();
        }

        for (var i=0; i<array_length(party_members); i++) {
            var p = party_members[i];
            p.render();
        }

        player.render();
        matrix_set(matrix_world, matrix_build_identity());
    }
}

enum DIALOG {
    CHAT,
    NOTIF
};

/// @param {Enum.DIALOG} _kind
/// @param {string} _label
/// @param {string} _text
/// @param {string} _model
/// @param {string} _anim
function Dialog(_kind, _label, _text, _model, _anim) constructor {
    label = _label;
    text = _text;
    model = _model;
    anim = _anim;
    kind = _kind;

    static inst = function() {
        return get_anim_inst(model, $"dialog:{model}:{anim}");
    }
}

/// @param {string} text
function show_notif(text) {
    set_game_state(
        new GS_Dungeon_Dialog(
            global.game_state, new Dialog(
                DIALOG.NOTIF,
                "", text, "", ""
            )
        ),
        true, false
    );
}

/// @param {Struct.GS_Dungeon} _root_gs
/// @param {Struct.Dialog} _dialog
function GS_Dungeon_Dialog(_root_gs, _dialog) : Game_State() constructor {
    name = "DIALOG";
    root_gs = _root_gs;
    dialog = _dialog;
    enter_duration = 500;
    exit_duration = 500;

    static render = function() {
        root_gs.render();
    }

    static update = function() {
        if (kbd_down(vk_enter, "Enter", "Continue")) {
            set_game_state(root_gs, false, true);
        }
    }

    static gui = function() {
        do_2d();

        switch (dialog.kind) {
            case DIALOG.NOTIF:
                var w = (string_width(dialog.text)+40)/2 * ease_io_cubic(animate_io());
                var x1 = WW/4 - w;
                var x2 = WW/4 + w;

                var h = 40;
                var y1 = WH/2 - h/2;
                var y2 = y1+h;
                draw_set_color(c_blue);
                draw_rectangle(x1, y1, x2, y2, false);

                if (animate_io() == 1) {
                    draw_set_color(c_white);
                    draw_text(x1+20, y1+10, dialog.text);
                }
            break;

            case DIALOG.CHAT:
                var w = (WW-40)/2 * ease_io_cubic(animate_io());
                var x1 = WW/2 - w;
                var x2 = WW/2 + w;

                var h = 200;
                var y1 = WH - h - 20;
                var y2 = y1+h;
                draw_set_color(c_blue);
                draw_rectangle(x1, y1, x2, y2, false);

                if (animate_io() == 1) {
                    draw_set_color(c_white);
                    draw_text(x1+20, y1+20, dialog.label);
                    draw_text_ext(x1+20, y1+40, dialog.text, 2, w-40);
                }
            break;
        }
    }
}
