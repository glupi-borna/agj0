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

/// @param {Struct.Game_State} gs
function set_game_state(gs) {
    global.game_state.next_state = gs;
    global.game_state.state_end = current_time;
}

function update_game_state() {
    if (!is_undefined(global.game_state.next_state)) {
        var exit_time = current_time - global.game_state.state_end;
        if (exit_time >= global.game_state.exit_duration) {
            var gs = global.game_state.next_state;
            global.game_state.next_state = undefined;
            global.game_state.state_end = undefined;
            global.game_state = gs;
            global.game_state.state_start = current_time;
            global.game_state.init();
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

function Dungeon_Player() constructor {
    pos = new v3(0, 0, 0);
    fwd = new v3(1, 1, 0).normalize();
    inventory = new Inventory();
}

function GS_Dungeon() : Game_State() constructor {
    name = "DUNGEON";
    /// @type {Struct.Dungeon}
    dungeon = undefined;
    /// @type {Id.Camera}
    camera = undefined;
    /// @type {Struct.Dungeon_Player}
    player = undefined;
    enter_duration = 500;
    exit_duration = 500;

    static init = function() {
        dungeon = new Dungeon(50, 50);
        dungeon.generate();
        player = new Dungeon_Player();
        var r = dungeon.get_leaf_room();
        player.pos.x = r.xmid()*48;
        player.pos.y = r.ymid()*48;
        player.pos.z = 0;
    }

    static gui = function() {
        do_2d();
        var px = player.pos.x/9.6;
        var py = player.pos.y/9.6;
        dungeon.render(5, -px+100, -py+100);
        var dir = point_direction(0, 0, player.fwd.x, player.fwd.y)-45;
        draw_sprite_ext(spr_arrow, 0, 100, 100, 0.125, 0.125, dir, c_white, 1);

        if (entering()||exitting()) {
            draw_set_color(c_black);
            draw_set_alpha(1-animate_io());
            draw_rectangle(0, 0, WW, WH, false);
            draw_set_alpha(1);
        }
        draw_set_color(c_white);
    }

    static update = function() {
        do_3d();
        update_animations();
        if (exitting()) return;
        var old_pos = player.pos.copy();
        player.fwd.normalize();
        var walk_speed = 2;
        if (keyboard_check(vk_up)) player.pos.add(0, 0, 2);
        if (keyboard_check(vk_down)) player.pos.add(0, 0, -2);
        if (keyboard_check(ord("W"))) player.pos.addv(player.fwd.copy().scale(2));
        if (keyboard_check(ord("S"))) player.pos.addv(player.fwd.copy().neg().scale(2));
        if (keyboard_check(ord("A"))) player.fwd.zrotate(-2);
        if (keyboard_check(ord("D"))) player.fwd.zrotate(2);
        if (keyboard_check(vk_escape)) {
            set_game_state(new GS_Main_Menu());
            return;
        }

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
                    var t = dungeon.tile_at(tx, ty);
                    var c = t.collider();
                    if (is_undefined(c)) continue;
                    var rx = tx * 48;
                    var ry = ty * 48;
                    var cx = rx + 48*c.x;
                    var cy = ry + 48*c.y;
                    var cw = 48*c.w;
                    var ch = 48*c.h;
                    if (rectangle_in_circle(cx, cy, cx+cw, cy+ch, px, py, 6) != 0) {
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

        var player_model = get_anim_inst("char", "player");
        if (!is_undefined(player_model)) {
            var lerp_spd = player_model.get_animation() == -1 ? 1 : 0.2;

            if (old_pos.eq(player.pos)) {
                player_model.play("idle", 0.01, lerp_spd, false);

            } else {
                var fwd_dir = point_direction(0, 0, player.fwd.x, player.fwd.y);
                var mv_amt = player.pos.copy().subv(old_pos);
                var mv_dir = point_direction(0, 0, mv_amt.x, mv_amt.y);
                var anim_spd = 0.015;
                if (abs(angle_difference(mv_dir, fwd_dir)) > 90) anim_spd *= -1;
                player_model.play("walk", anim_spd, lerp_spd, false);
            }
        }

        var pt = new v2(player.pos.x/48, player.pos.y/48);
        var ptf = new v2(floor(pt.x), floor(pt.y));
        dungeon.discover(ptf.x, ptf.y);

        var dir = point_direction(0, 0, player.fwd.x, player.fwd.y);
        var t1 = pt.copy();
        var t2 = new v2(t1.x+lengthdir_x(1, dir-22.5), t1.y+lengthdir_y(1, dir-22.5));
        var t3 = new v2(t1.x+lengthdir_x(1, dir+22.5), t1.y+lengthdir_y(1, dir+22.5));

        /// @type {Struct.Tile|Undefined}
        var interact_tile = undefined;
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

        if (!is_undefined(interact_tile) && keyboard_check(ord("E"))) {
            interact_tile.open = true;
        }
    }

    static render = function() {
        camera = camera_get_active();
        var cam_pos = player.pos.copy().addv(
            player.fwd.copy().neg().scale(64) // Move camera back
        ).addv(
            player.fwd.copy().zrotate(90).scale(0) // Move cam right
        );
        cam_pos.z += 20;
        var lookat = player.pos.copy().add(0, 0, 20).addv(player.fwd.copy().scale(20));
        camera_set_view_mat(camera, matrix_build_lookat(cam_pos.x, cam_pos.y, cam_pos.z, lookat.x, lookat.y, lookat.z, 0, 0, 1));
        camera_set_proj_mat(camera, matrix_build_projection_perspective_fov(-60, -WW/WH, 1, 32000));
        camera_apply(camera);

        static render_wall = function (x, y, size, rot) {
            matrix_stack_push(matrix_build(x, y, 0, 0, 0, 0, 1, 1, 1));
            matrix_stack_push(matrix_build(0, 0, 0, 0, 0, rot, 1, 1, 1));
            matrix_stack_push(matrix_build(0, 0, 0, 0, 0, 0, size, 1, size));
            matrix_set(matrix_world, matrix_stack_top());
            vertex_submit(global.v_wall, pr_trianglelist, sprite_get_texture(spr_floor_brick, 0));
            matrix_stack_pop();
            matrix_stack_pop();
            matrix_stack_pop();
            matrix_set(matrix_world, matrix_stack_top());
        }

        static render_floor = function (x, y, size) {
            matrix_stack_push(matrix_build(x, y, 0, 0, 0, 0, 1, 1, 1));
            matrix_stack_push(matrix_build(0, 0, 0, 0, 0, 0, 48, 48, 1));
            matrix_set(matrix_world, matrix_stack_top());
            vertex_submit(global.v_floor, pr_trianglelist, sprite_get_texture(spr_floor_brick, 0));
            matrix_stack_pop();
            matrix_stack_pop();
            matrix_set(matrix_world, matrix_stack_top());
        }

        for (var yy=0; yy<dungeon.height; yy++) {
            for (var xx=0; xx<dungeon.width; xx++) {
                var t = dungeon.tile_at(xx, yy);

                if (t.is_floor()) render_floor(xx*48, yy*48, 48);

                if (t.kind != TILE.WALL) continue;

                if (dungeon.tile_at(xx+1, yy).is_floor())
                    render_wall((xx+1)*48, yy*48, 48, -90);


                if (dungeon.tile_at(xx-1, yy).is_floor())
                    render_wall(xx*48, (yy+1)*48, 48, 90);

                k = dungeon.tile_kind(xx, yy+1);
                if (k==TILE.FLOOR || k==TILE.DOOR) {
                    render_wall((xx+1)*48, (yy+1)*48, 48, 180);
                }

                k = dungeon.tile_kind(xx, yy-1);
                if (k==TILE.FLOOR || k==TILE.DOOR) {
                    render_wall(xx*48, yy*48, 48, 0);
                }
            }
        }

        var pos = player.pos;
        var rot = point_direction(0, 0, player.fwd.x, player.fwd.y);
        matrix_stack_push(matrix_build(pos.x, pos.y, pos.z, 0, 0, rot, 12, 12, 12));
        matrix_set(matrix_world, matrix_stack_top());

        shader_set(sh_smf_animate);
        render_model_simple("char", "player", spr_player);
        shader_reset();

        matrix_stack_pop();
        matrix_set(matrix_world, matrix_stack_top());
    }
}
