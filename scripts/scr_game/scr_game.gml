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

/// @param {string} _name
/// @param {Asset.GMSprite} _sprite
function Item(_name, _sprite, _amount=1) constructor {
    Name = _name;
    Sprite = _sprite;
    count = _amount;
}

function Inventory() constructor {
    /// @type {Id.DsMap<Struct.Item>}
    items = ds_map_create();

    /// @param {Struct.Item} item
    static add = function(item) {
        /// @type {Struct.Item}
        var existing = ds_map_find_value(items, item.Name);
        if (!is_undefined(existing)) existing.count += item.count;
    }

    /// @param {string} item
    /// @param {real} count
    static remove = function(item, count) {
        /// @type {Struct.Item}
        var existing = ds_map_find_value(items, count);
        assert(!is_undefined(existing), $"Item {item} does not exist in inventory");
        assert(existing.count >= count, $"Can not remove more of {item} than exists in inventory (want {count}, have {existing.count})");
        existing.count -= count;
        if (existing.count == 0) ds_map_delete(items, item);
    }
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

enum ELEMENT {
    BLUNT,
    SHARP,
    FIRE,
    WATER,
    WIND,
    ICE,
    ELEC,
    RAW,
};

/// @param {real} _lvl,
/// @param {Array<Enum.ELEMENT>} _weak
/// @param {Array<Enum.ELEMENT>} _blocks
/// @param {real} _max_hp,
/// @param {real} _max_dp,
/// @param {real} _attack,
/// @param {real} _defense,
/// @param {real} _speed,
/// @param {real} _luck
function Stats(
    _lvl,
    _weak,
    _blocks,
    _max_hp,
    _max_dp,
    _attack,
    _defense,
    _speed,
    _luck
) constructor {
    lvl = _lvl
    weak_to = _weak;
    blocks = _blocks;
    max_hp = _max_hp;
    max_dp = _max_dp;
    attack = _attack;
    defense = _defense;
    speed = _speed;
    luck = _luck;
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
        return new Character(stats, model, texture, size, floating);
    }
}

/// @param {real} lvl
function mouth(lvl) {
    return new Enemy(
        "Mouth", "mouth", spr_mouth, 12, true,
        new Stats(
            lvl,
            [ELEMENT.SHARP, ELEMENT.WIND],
            [ELEMENT.ELEC],
            50 + lvl*5,
            10 + lvl*1,
            3+floor(lvl*0.25),
            2+floor(lvl*0.25),
            1+floor(lvl*0.25),
            1+floor(lvl*0.1)
        )
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
                    set_game_state(
                        new GS_Battle(global.game_state, [data.char()], INITIATIVE.ENEMY)
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

function Dungeon_Party() constructor {
    pos = new v3(0, 0, 0);
    fwd = new v3(1, 1, 0).normalize();
    look_dir = fwd.copy();
    formation_offset = 0;
    texture = spr_player;

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
        if (keyboard_check(vk_up)) mv.add(0, 0, 2);
        if (keyboard_check(vk_down)) mv.add(0, 0, -2);
        if (keyboard_check(ord("W"))) mv.addv(fwd.copy().scale(walk_speed));
        if (keyboard_check(ord("S"))) mv.addv(fwd.copy().neg().scale(walk_speed));
        if (keyboard_check(ord("A"))) fwd.zrotate(-2);
        if (keyboard_check(ord("D"))) fwd.zrotate(2);
        if (keyboard_check(vk_escape)) {
            set_game_state(new GS_Main_Menu());
            return;
        }

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

function GS_Dungeon() : Game_State() constructor {
    name = "DUNGEON";
    /// @type {Struct.Dungeon}
    dungeon = undefined;

    inventory = new Inventory();

    /// @type {Struct.Dungeon_Player}
    player = new Dungeon_Player();

    /// @type {Array<Struct.Dungeon_Party>}
    party_members = [new Dungeon_Party(), new Dungeon_Party()];

    party = [
        new Character(
            new Stats(1, [], [], 100, 0, 1, 1, 1, 1),
            "char", spr_player, 12, false
        ),
        new Character(
            new Stats(1, [], [], 100, 0, 1, 1, 1, 1),
            "char", spr_player, 12, false
        ),
        new Character(
            new Stats(1, [], [], 100, 0, 1, 1, 1, 1),
            "char", spr_player, 12, false
        ),
        new Character(
            new Stats(1, [], [], 100, 0, 1, 1, 1, 1),
            "char", spr_player, 12, false
        ),
    ];

    /// @type {Array<Struct.Dungeon_Enemy>}
    enemies = [];

    /// @type {Struct.Tile|Undefined}
    interact_tile = undefined;
    enter_duration = 500;
    exit_duration = 500;

    static generate_dungeon = function() {
        dungeon.clear();
        dungeon.generate();
        var player_room = dungeon.get_leaf_room();
        player.pos.set(player_room.xmid()*TILE_SIZE, player_room.ymid()*TILE_SIZE, 0);

        var f = -0.5;
        for (var i=0; i<array_length(party_members); i++) {
            var p = party_members[i];
            p.formation_offset = f;
            f++;
            p.pos.setv(p.target_pos(player));
        }

        repeat(10) {
            var enemy_room = pick_arr(dungeon.rooms);
            if (enemy_room == player_room) continue;
            var xx = irandom_range(enemy_room.x+1, enemy_room.x+enemy_room.w-2);
            var yy = irandom_range(enemy_room.y+1, enemy_room.y+enemy_room.h-2);
            var e = new Dungeon_Enemy(get_enemy(1));
            e.pos.set((xx+0.5)*TILE_SIZE, (yy+0.5)*TILE_SIZE, 0);
            array_push(enemies, e);
        }
    }

    static init = function() {
        dungeon = new Dungeon(50, 50);
        generate_dungeon();
    }

    static gui = function() {
        do_2d();
        var px = player.pos.x/9.6;
        var py = player.pos.y/9.6;
        dungeon.render(5, floor(-px+100), floor(-py+100));
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
            set_game_state(new GS_Battle(self, [mouth(1).char(), mouth(1).char(), mouth(1).char(), mouth(1).char()], INITIATIVE.ENEMY))
        }

        player.update(dungeon);

        for (var i=0; i<array_length(enemies); i++) {
            var e = enemies[i];
            e.update(dungeon, player);
        }

        for (var i=0; i<array_length(party_members); i++) {
            var p = party_members[i];
            p.update(dungeon, player);
        }

        if (keyboard_check_pressed(vk_tab)) {
            generate_dungeon();
        }

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

        if (!is_undefined(interact_tile) && keyboard_check_pressed(ord("E"))) {
            interact_tile.interact();
        }
    }

    static render = function() {
        do_3d();
        update_animations();

        draw_clear(gpu_get_fog()[1]);

        var camera = camera_get_active();
        var cam_pos = player.pos.copy().add(0, 0, 20);
        var target_cam_pos = cam_pos.copy().addv(
            player.fwd.copy().neg().scale(64) // Move camera back
        ).addv(
            player.fwd.copy().zrotate(90).scale(0) // Move cam right
        );
        var lookat = player.pos.copy().add(0, 0, 20).addv(player.fwd.copy().scale(20));

        cam_pos = get_cam_pos(dungeon, cam_pos, target_cam_pos);

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

                    case TILE.LARGE_CHEST:
                        render_chest(xx, yy, 0, 0.4, t.open);
                    break;

                    case TILE.SMALL_CHEST:
                        render_chest(xx, yy, 0, 0.15, t.open);
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
                "", "Opened a chest!", "", ""
            )
        ),
        true, false
    );
}

/// @param {Struct.GS_Dungeon} _root_gs
/// @param {Struct.Dialog} _dialog
function GS_Dungeon_Dialog(_root_gs, _dialog) : Game_State() constructor {
    root_gs = _root_gs;
    dialog = _dialog;
    enter_duration = 500;
    exit_duration = 500;

    static render = function() {
        root_gs.render();
    }

    static update = function() {
        if (keyboard_check_pressed(vk_enter)) {
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
