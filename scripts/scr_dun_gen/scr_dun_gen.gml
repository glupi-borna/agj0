#macro TILE_SIZE 48

enum TILE {
	EMPTY,
	WALL,
	FLOOR,
	LARGE_CHEST,
	SMALL_CHEST,
	DOOR,
};

randomize();

/// @param {real} x
/// @param {real} y
function render_floor(x, y, z=0) {
	matrix_set(matrix_world, mtx_mul(
		mtx_scl(TILE_SIZE, TILE_SIZE, 1),
		mtx_mov(x*TILE_SIZE, y*TILE_SIZE, z*TILE_SIZE),
	));
	vertex_submit(global.v_floor, pr_trianglelist, sprite_get_texture(spr_floor_brick, 0));
}

/// @param {real} x
/// @param {real} y
/// @param {real} z
/// @param {real} rot
function render_wall(x, y, z, rot) {
	matrix_set(matrix_world, mtx_mul(
		mtx_scl(TILE_SIZE, 1, TILE_SIZE),
		mtx_rot(0, 0, rot),
		mtx_mov(x*TILE_SIZE, y*TILE_SIZE, z*TILE_SIZE),
	));
	vertex_submit(global.v_wall, pr_trianglelist, sprite_get_texture(spr_floor_brick, 0));
}

/// @param {real} x
/// @param {real} y
/// @param {real} z
/// @param {real} rot
function render_door(x, y, z, rot) {
	matrix_set(matrix_world, mtx_mul(
		mtx_scl(TILE_SIZE, 1, TILE_SIZE),
		mtx_rot(0, 0, rot),
		mtx_mov(x*TILE_SIZE, y*TILE_SIZE, z*TILE_SIZE+2)
	));
	vertex_submit(global.v_door, pr_trianglelist, sprite_get_texture(spr_door, 0));

	var lx = lengthdir_x(1, rot+90);
	var ly = lengthdir_y(1, rot+90);
	var lrx = lengthdir_x(1, rot);
	var lry = lengthdir_y(1, rot);

	matrix_set(matrix_world, mtx_mul(
		mtx_scl(TILE_SIZE, 1, TILE_SIZE),
		mtx_rot(0, 0, rot),
		mtx_mov(x*TILE_SIZE+lx*4, y*TILE_SIZE+ly*4, TILE_SIZE)
	));
	vertex_submit(global.v_wall, pr_trianglelist, sprite_get_texture(spr_floor_brick, 0));

	matrix_set(matrix_world, mtx_mul(
		mtx_scl(TILE_SIZE, 1, TILE_SIZE),
		mtx_rot(0, 0, rot+180),
		mtx_mov(x*TILE_SIZE-lx*4 + lrx*TILE_SIZE, y*TILE_SIZE-ly*4 + lry*TILE_SIZE, TILE_SIZE)
	));
	vertex_submit(global.v_wall, pr_trianglelist, sprite_get_texture(spr_floor_brick, 0));
}

function render_chest(x, y, z, scale, open) {
	var rot = sin(x*1000)*360+sin(y*1000)*360;
	matrix_set(matrix_world, mtx_mul(
		mtx_scl(TILE_SIZE*scale, TILE_SIZE*scale, TILE_SIZE*scale),
		mtx_rot(0, 0, rot),
		mtx_mov((x+0.5)*TILE_SIZE, (y+0.5)*TILE_SIZE, 0),
	));
	shader_set(sh_smf_animate);
	if (open != -1) {
		if (current_time - open < 1000) {
			render_model_simple("chest", "chest_opening", spr_chest);
		} else {
			animation_play("chest", "chest_open", "open", 1, 1, true);
			render_model_simple("chest", "chest_open", spr_chest);
		}
	} else {
		animation_play("chest", "chest_closed", "closed", 1, true);
		render_model_simple("chest", "chest_closed", spr_chest);
	}
	shader_reset();
}

/// @param {Enum.TILE} kind
function Tile(kind) constructor {
	self.kind = kind;
	self.discovered = false;
	self.open = -1;

	static color = function() {
		switch (kind) {
			case TILE.WALL: return #335588;
			case TILE.FLOOR: return #338855;
			case TILE.LARGE_CHEST: return #ffff99;
			case TILE.SMALL_CHEST: return #ffff99;
			case TILE.DOOR: return #338855;
		}
		return #ff00ff;
	}

	static is_floor = function() {
		return kind != TILE.WALL && kind != TILE.EMPTY;
	}

	static interactive = function() {
		switch (kind) {
			case TILE.LARGE_CHEST: return open == -1;
			case TILE.SMALL_CHEST: return open == -1;
			case TILE.DOOR: return open == -1;
		}
		return false;
	}

	static interact_label = function() {
		switch (kind) {
			case TILE.LARGE_CHEST: return "Open chest";
			case TILE.SMALL_CHEST: return "Open chest";
			case TILE.DOOR: return "Open door";
		}
		return "";
	}

	/// @param {Struct.Inventory} inv
	static interact = function(inv) {
		switch (kind) {
			case TILE.LARGE_CHEST:
				open = current_time;
				var i = random_item();
				var amt = irandom_range(3, 10);
				animation_play("chest", "chest_opening", "opening", 0.03, 1, true);
				inv.add(i, amt);
				show_notif($"Got {i.name} x{amt}!");
				return;

			case TILE.SMALL_CHEST:
				open = current_time;
				var i = random_item();
				var amt = irandom_range(1, 5);
				animation_play("chest", "chest_opening", "opening", 0.03, 1, true);
				inv.add(i, amt);
				show_notif($"Got {i.name} x{amt}!");
				return;

			case TILE.DOOR:
				open = current_time;
				return;
		}
	}

	static collider = function() {
		switch (kind) {
			case TILE.LARGE_CHEST: return new Rect(0.25, 0.25, 0.5, 0.5);
			case TILE.SMALL_CHEST: return new Rect(0.375, 0.375, 0.25, 0.25);
			case TILE.WALL: return new Rect(0, 0, 1, 1);
			case TILE.DOOR: return open>=0 ? undefined : new Rect(0, 0, 1, 1);
		}
		return undefined;
	}
}

global.NULL_TILE = new Tile(TILE.EMPTY);

/// @param {real} _x
/// @param {real} _y
/// @param {real} _w
/// @param {real} _h
function Room(_x, _y, _w, _h) : Rect(_x, _y, _w, _h) constructor {
	/// @type {Array<Struct.Room>}
	connections = [];
	name = gen_name();
	/// @type {Array<Struct.Hallway>}
	hallways = [];
	/// @type {Array<Struct.Tile>}
	tiles = [];

	/// @param {Struct.Dungeon} d
	/// @param {real} x
	/// @param {real} y
	/// @param {Enum.TILE} kind
	static tile = function(d, x, y, kind) {
		var t = d.tile(x, y, kind);
		array_push(tiles, t);
		return t;
	}

	/// @param {Struct.Dungeon} d
	static fill = function(d) {
		for (var xx=0; xx<w; xx++) {
			for (var yy=0; yy<h; yy++) {
				if (irandom(100) < 1) {
					tile(d, x+xx, y+yy, choose(TILE.LARGE_CHEST, TILE.SMALL_CHEST, TILE.SMALL_CHEST));
				} else {
					tile(d, x+xx, y+yy, TILE.FLOOR);
				}
			}
		}
	}

	/// @param {Struct.Room} r
	/// @param {Array<Struct.Room>} visited
	static is_connected_to = function (r, visited) {
		if (array_contains(self.connections, r)) return true;
		array_push(visited, self);
		for (var i=0; i<array_length(connections); i++) {
			var c = connections[i];
			if (array_contains(visited, c)) continue;
			if (c.is_connected_to(r, visited)) return true;
		}
		return false;
	}

	/// @param {Struct.Room} r
	static connect = function (r) {
		if (array_contains(connections, r)) return;
		array_push(connections, r);
		array_push(r.connections, self);

        var x1 = (x+w-1 < r.x) ? x+w-1 : x;
        var y1 = (y+h-1 < r.y) ? y+h-1 : y;

        var x2 = (r.x+r.w-1 < x) ? r.x+r.w-1 : r.x;
        var y2 = (r.y+r.h-1 < y) ? r.y+r.h-1 : r.y;

        var o = get_range_overlap(x, x+w-1, r.x, r.x+r.w-1);
        if (!is_undefined(o)) {
            x1 = (o[0] + o[1]) div 2;
            x2 = x1;
        }

        o = get_range_overlap(y, y+h-1, r.y, r.y+r.h-1);
        if (!is_undefined(o)) {
            y1 = (o[0] + o[1]) div 2;
            y2 = y1;
        }

		var hw = new Hallway(self, x1, y1, r, x2, y2);
		array_push(hallways, hw);
		array_push(r.hallways, hw);
	}
}

/// @param {Struct.Room} _r1
/// @param {real} _x1
/// @param {real} _y1
/// @param {Struct.Room} _r2
/// @param {real} _x2
/// @param {real} _y2
function Hallway(_r1, _x1, _y1, _r2, _x2, _y2) constructor {
	room_start = _r1;
	room_end = _r2;
	x_start = _x1;
	x_end = _x2;
	y_start = _y1;
	y_end = _y2;
	/// @type {bool}
	variant = choose(true, false);
	/// @type {Struct.Tile}
	tiles = [];

	assert(room_start.contains_point(x_start, y_start), "Room 1 must contain point 1");
	assert(room_end.contains_point(x_end, y_end), "Room 2 must contain point 2");

	/// @param {Struct.Hallway} h
	static equals = function(h) {
		var r1match = room_start == h.room_start || room_start == h.room_end;
		var r2match = room_end == h.room_start || room_end == h.room_end;
		var x1match = x_start == h.x_start || x_start == h.x_end;
		var x2match = x_end == h.x_start || x_end == h.x_end;
		var y1match = y_start == h.y_start || y_start == h.y_end;
		var y2match = y_end == h.y_start || y_end == h.y_end;
		return r1match && r2match && x1match && x2match && y1match && y2match;
	}

	/// @param {Struct.Dungeon} d
	/// @param {real} x
	/// @param {real} y
	/// @param {Enum.TILE} kind
	static tile = function(d, x, y, kind) {
		var t = d.tile(x, y, kind);
		array_push(tiles, t);
		return t;
	}

	static has_point = function(px, py) {
		var xmov = sign(x_end - x_start);
		var ymov = sign(y_end - y_start);

		var x_y = variant ? y_start : y_end;
		for (var xx=x_start; xx!=x_end+xmov; xx+=xmov) {
			if (xx==px && x_y==py) return true;
		}

		var y_x = variant ? x_end : x_start;
		for (var yy=y_start; yy!=y_end+ymov; yy+=ymov) {
			if (px==y_x && py==yy) return true;
		}
	}

	/// @param {Struct.Dungeon} d
	static fill = function(d) {
		var xmov = sign(x_end - x_start);
		var ymov = sign(y_end - y_start);

		var x_y = variant ? y_start : y_end;
		for (var xx=x_start; xx!=x_end+xmov; xx+=xmov) {
			tile(d, xx, x_y, TILE.FLOOR);
		}

		var y_x = variant ? x_end : x_start;
		for (var yy=y_start; yy!=y_end+ymov; yy+=ymov) {
			tile(d, y_x, yy, TILE.FLOOR);
		}

		var zerox = ymov==0 ? xmov : 0;
		var zeroy = xmov==0 ? ymov : 0;

		if (variant) {
			tile(d, x_start+xmov, y_start+zeroy, TILE.DOOR);
			tile(d, x_end-zerox, y_end-ymov, TILE.DOOR);
		} else {
			tile(d, x_start+zerox, y_start+ymov, TILE.DOOR);
			tile(d, x_end-xmov, y_end-zeroy, TILE.DOOR);
		}
	}
}

/// @param {Struct.Room} r
function Island(r) constructor {
	/// @type {Array<Struct.Room>}
	rooms = [r];
	name = gen_name();

	/// @param {Struct.Room} my_room
	/// @param {Struct.Room} new_room
	/// @param {Struct.Island} island
	static connect_island = function(my_room, new_room, island) {
		assert(array_contains(rooms, my_room), "Trying to connect to room that is not part of this island!");
		assert(!array_contains(rooms, new_room), "Trying to connect room that is already part of this island!");
		assert(array_contains(island.rooms, new_room), "Connecting room must be part of connecting island!");
		my_room.connect(new_room);
		for (var i=0; i<array_length(island.rooms); i++) {
			array_push(rooms, island.rooms[i]);
		}
	}
}

/// @param {real} _w
/// @param {real} _h
function Dungeon(_w, _h) constructor {
	width = _w;
	height = _h;
	/// @type {Array<Struct.Room>}
	rooms = [];
	/// @type {Array<Struct.Tile|Undefined>}
	tiles = array_create(width*height, global.NULL_TILE);

	static tile = function(x, y, kind) {
		var t = tile_at(x, y);
		if (t == global.NULL_TILE) {
			t = new Tile(kind);
			tiles[y*width + x] = t;
		} else {
			t.kind = kind;
		}
		return t;
	}

	/// @param {real} x
	/// @param {real} y
	/// @returns {Struct.Tile}
	static tile_at = function(x, y) {
		if (x < 0 || y < 0 || x >= width || y >= height) return global.NULL_TILE;
		return tiles[y*width + x];
	}

	/// @param {real} x
	/// @param {real} y
	static tile_kind = function(x, y) {
		return tile_at(x, y).kind;
	}

	/// @param {real} x
	/// @param {real} y
	/// @param {Enum.TILE} kinds
	static tile_has_floor_neighbor = function(x, y, diagonals=false) {
		if (tile_at(x-1, y).is_floor()) return true;
		if (tile_at(x+1, y).is_floor()) return true;
		if (tile_at(x, y-1).is_floor()) return true;
		if (tile_at(x, y+1).is_floor()) return true;

		if (diagonals) {
			if (tile_at(x-1, y-1).is_floor()) return true;
			if (tile_at(x+1, y-1).is_floor()) return true;
			if (tile_at(x-1, y+1).is_floor()) return true;
			if (tile_at(x+1, y+1).is_floor()) return true;
		}

		return false;
	}

	/// @param {real} x
	/// @param {real} y
	/// @returns {Struct.Hallway|Undefined}
	static hallway_at = function(x, y) {
		for (var i=0; i<array_length(rooms); i++) {
			var r = rooms[i];
			for (var j=0; j<array_length(r.hallways); j++) {
				var h = r.hallways[j];
				if (h.has_point(x, y)) return h;
			}
		}
		return undefined;
	}

	/// @param {real} x
	/// @param {real} y
	/// @returns {Struct.Room|Undefined}
	static room_at = function(x, y) {
		for (var i=0; i<array_length(rooms); i++) {
			var r = rooms[i];
			if (r.contains_point(x, y)) return r;
		}
		return undefined;
	}

	/// @param {real} x
	/// @param {real} y
	static room_exists_at = function(x, y) {
		return !is_undefined(room_at(x, y));
	}

	/// @param {real} x
	/// @param {real} y
	static discover = function(x, y) {
		static last_check = new v2(-1, -1);
		if (last_check.x == x && last_check.y == y) return;
		last_check.set(x, y)

		var r = room_at(x, y);
		if (!is_undefined(r)) {
			for (var i=0; i<array_length(r.tiles); i++) {
				r.tiles[i].discovered = true;
			}
			return;
		}

		var h = hallway_at(x, y);
		if (!is_undefined(h)) {
			for (var i=0; i<array_length(h.tiles); i++) {
				h.tiles[i].discovered = true;
			}
		}
	}

	/// @param {real} x
	/// @param {real} y
	/// @param {real} w
	/// @param {real} h
	/// @returns {bool}
	static room_overlaps_rect = function(x, y, w, h) {
		var rect = new Rect(x, y, w, h);
		for (var i=0; i<array_length(rooms); i++) {
			var r = rooms[i];
			if (r.overlaps_rect(rect)) return true;
		}
		return false;
	}

	/// @param {real} x
	/// @param {real} y
	/// @param {real} w
	/// @param {real} h
	/// @returns {Struct.Room | Undefined}
	static get_room = function(x, y, w, h) {
		if (x>0 && y> 0 && x+w < self.width && y+h < self.height) {
			if (!room_overlaps_rect(x, y, w, h)) return new Room(x, y, w, h);
		}

		if (room_exists_at(x, y)) return undefined;

		for (var xx=max(x-w+1, 1); xx<=min(x,self.width-w-1); xx++) {
			for (var yy=max(y-h+1, 1); yy<=min(y,self.height-h-1); yy++) {
				if (!room_overlaps_rect(xx, yy, w, h)) {
					return new Room(xx, yy, w, h);
				}
			}
		}
		return undefined;
	}

	static clear = function() {
		/// @type {Array<Struct.Room>}
		rooms = [];
		tiles = array_create(width*height, global.NULL_TILE);
	}

	static fill_rooms = function() {
		for (var i=0; i<array_length(rooms); i++) {
			rooms[i].fill(self);
		}
	}

    static find_islands = function() {
		/// @type {Array<Struct.Island>}
        var islands = [];

        for (var i=0; i<array_length(self.rooms); i++) {
            var r = rooms[i];
            var connected = false;
            for (var j=0; j<array_length(islands); j++) {
                var island = islands[j];
                if (island.rooms[0].is_connected_to(r, [])) {
                    connected = true;
                    array_push(island.rooms, r);
                    break;
                }
            }
            if (!connected) {
				array_push(islands, new Island(r));
			}
        }

        return islands;
    }

	/// @param {Struct.Island} i1
	/// @param {Struct.Island} i2
	static island_distance = function(i1, i2) {
		var closest_dist = infinity;
		for (var i=0; i<array_length(i1.rooms); i++) {
			var r1 = i1.rooms[i];
			for (var j=i+1; j<array_length(i2.rooms); j++) {
				var r2 = i2.rooms[j];
				var dist = r1.manhattan_dist(r2);
				if (dist < closest_dist) closest_dist = dist;
			}
		}
		return closest_dist;
	}

	/// @param {Struct.Island} i1
	/// @param {Array<Struct.Island>} islands
	static closest_island = function(i1, islands) {
		var closest_dist = infinity;
		var closest_pair = [i1, islands[0]];
		for (var i=0; i<array_length(islands); i++) {
			var i2 = islands[i];
			if (i1 == i2) continue;
			var dist = island_distance(i1, i2);
			if (dist < closest_dist) {
				closest_dist = dist;
				closest_pair = [i1, i2];
			}
		}
		return closest_pair;
	}

	/// @param {Struct.Island} i1
	/// @param {Struct.Island} i2
    static island_connection = function(i1, i2) {
        var p1 = i1.rooms[0];
        var p2 = i2.rooms[0];
		var closest_dist = infinity;

		for (var i=0; i<array_length(i1.rooms); i++) {
			var r1 = i1.rooms[i];
			for (var j=0; j<array_length(i2.rooms); j++) {
				var r2 = i2.rooms[j];
				var dist = r1.manhattan_dist(r2);
				if (dist < closest_dist) {
					p1 = r1;
					p2 = r2;
					closest_dist = dist;
				}
			}
		}

		return [p1, p2];
    }

    /// @param {Struct.Room} r1
    /// @param {Struct.Room} r2
    static make_hallway = function(r1, r2) {
        assert(array_contains(r1.connections, r2), "Can't make hallway between unconnected rooms!");
        var x1 = (r1.x+r1.w-1 < r2.x) ? r1.x+r1.w-1 : r1.x;
        var y1 = (r1.y+r1.h-1 < r2.y) ? r1.y+r1.h-1 : r1.y;

        var x2 = (r2.x+r2.w-1 < r1.x) ? r2.x+r2.w-1 : r2.x;
        var y2 = (r2.y+r2.h-1 < r1.y) ? r2.y+r2.h-1 : r2.y;

        var o = get_range_overlap(r1.x, r1.x+r1.w-1, r2.x, r2.x+r2.w-1);
        if (!is_undefined(o)) {
            x1 = (o[0] + o[1]) div 2;
            x2 = x1;
        }

        o = get_range_overlap(r1.y, r1.y+r1.h-1, r2.y, r2.y+r2.h-1);
        if (!is_undefined(o)) {
            y1 = (o[0] + o[1]) div 2;
            y2 = y1;
        }
    }

	static get_leaf_room = function() {
		for (var i=0; i<array_length(rooms); i++) {
			var r = rooms[i];
			if (array_length(r.connections) == 1) return r;
		}
		return undefined;
	}

	static generate = function() {
        var t0 = get_timer();

		var dim = min(width, height);
		var attempts = 0;
		while (array_length(rooms)<2 || attempts<20) {
			attempts++;
			var r = get_room(irandom(width-1), irandom(height-1), irandom_range(dim div 10, dim div 6), irandom_range(dim div 10, dim div 6));
			if (!is_undefined(r)) {
				array_push(rooms, r);
			}
		}

        var t1 = get_timer();
		fill_rooms();
        var t2 = get_timer();

		for (var i=0; i<array_length(rooms); i++) {
			var r = rooms[i];

			/// @type {Struct.Room|Undefined}
			var closest = undefined;
			var dist = infinity;
			for (var j=0; j<array_length(rooms); j++) {
                if (i==j) continue;
				var r2 = rooms[j];
				var rdist = r.manhattan_dist(r2);
				if (rdist < dist) {
					closest = r2;
					dist = rdist;
				}
			}

			if (!is_undefined(closest)) r.connect(closest);
		}
        var t3 = get_timer();

		islands = find_islands();
		while (array_length(islands) > 1) {
			// Optimization: these two functions both have to find closest rooms
			// between a pair of islands - i.e., what connect_islands has to calculate
			// is already calculated by closest_island. This could be eliminated by
			// folding the functions together.
			var pair = closest_island(islands[0], islands);
			var room_pair = island_connection(pair[0], pair[1]);
            var p2i = array_get_index(islands, pair[1]);
			pair[0].connect_island(room_pair[0], room_pair[1], pair[1]);
			array_delete(islands, p2i, 1);
		}
        var t4 = get_timer();

        for (var i=0; i<array_length(islands[0].rooms); i++) {
            var r = islands[0].rooms[i];
            for (var j=0; j<array_length(r.connections); j++) {
                var r2 = r.connections[j];
                make_hallway(r, r2);
            }

			for (var j=0; j<array_length(r.hallways); j++) {
				r.hallways[j].fill(self);
			}
        }
        var t5 = get_timer();

		for (var xx=0; xx<width; xx++) {
			for (var yy=0; yy<height; yy++) {
				if (tile_kind(xx, yy) == TILE.EMPTY && tile_has_floor_neighbor(xx, yy)) {
					tile(xx, yy, TILE.WALL);
				}
			}
		}

		var t6 = get_timer();

        print($"Create rooms      {t1-t0}us");
        print($"Fill rooms        {t2-t1}us");
        print($"Connect closest   {t3-t2}us");
        print($"Find/conn islands {t4-t3}us");
        print($"Hallways          {t5-t4}us");
        print($"Walls             {t6-t5}us");
        print($"Total             {t6-t0}us");
	}

	/// @type {Array<Struct.Island>}
	islands = [];

	static render = function(tile_size, xoff, yoff) {
		var debug_display = keyboard_check(vk_f1);

		draw_set_alpha(0.4);
		for (var xx=0; xx<width; xx++) {
			for (var yy=0; yy<height; yy++) {
				var tile = tiles[xx+yy*width];
				if (!tile.discovered && !debug_display) continue;
				draw_set_color(tile.color());
				draw_rectangle(xoff+xx*tile_size, yoff+yy*tile_size, xoff+xx*tile_size+tile_size-1, yoff+yy*tile_size+tile_size-1, false);
				if (!tiles[xx-1+yy*width].is_floor()) {
					draw_set_color(c_white);
					draw_line(xoff+xx*tile_size, yoff+yy*tile_size, xoff+xx*tile_size, yoff+(yy+1)*tile_size);
				}

				if (!tiles[xx+1+yy*width].is_floor()) {
					draw_set_color(c_white);
					draw_line(xoff+(xx+1)*tile_size, yoff+yy*tile_size, xoff+(xx+1)*tile_size, yoff+(yy+1)*tile_size);
				}

				if (!tiles[xx+(yy-1)*width].is_floor()) {
					draw_set_color(c_white);
					draw_line(xoff+xx*tile_size, yoff+yy*tile_size, xoff+(xx+1)*tile_size, yoff+yy*tile_size);
				}

				if (!tiles[xx+(yy+1)*width].is_floor()) {
					draw_set_color(c_white);
					draw_line(xoff+xx*tile_size, yoff+(yy+1)*tile_size, xoff+(xx+1)*tile_size, yoff+(yy+1)*tile_size);
				}
			}
		}
		draw_set_alpha(1);

		if (debug_display) {
			for (var i=0; i<array_length(rooms); i++) {
				var r = rooms[i];
				draw_set_color(c_white);
				draw_rectangle(xoff+r.x*tile_size, yoff+r.y*tile_size, xoff+(r.x+r.w)*tile_size, yoff+(r.y+r.h)*tile_size, true);

				draw_set_color(c_blue);
				for (var j=0; j<array_length(r.connections); j++) {
					var c = r.connections[j];
					draw_line(xoff+r.xmid()*tile_size, yoff+r.ymid()*tile_size, xoff+c.xmid()*tile_size, yoff+c.ymid()*tile_size);
					draw_text(
						xoff+(r.xmid()+c.xmid())*0.5*tile_size,
						yoff+(r.ymid()+c.ymid())*0.5*tile_size,
						$"{r.manhattan_dist(c)}"
					);
				}
				draw_set_color(c_red);
				draw_text(xoff+r.xmid()*tile_size, yoff+r.ymid()*tile_size, r.name);
			}

			for (var ii=0; ii<array_length(islands); ii++) {
				var is = islands[ii];
				draw_set_color(c_white);
				draw_text(xoff+is.rooms[0].xmid()*tile_size, yoff+is.rooms[0].ymid()*tile_size+20, is.name);
			}

			var mx = floor((WMX-xoff)/tile_size);
			var my = floor((WMY-yoff)/tile_size);
			var t = tile_at(mx, my);
			draw_text(WMX, WMY+20, $"{t.kind} {t.is_floor()}");
		}

		draw_set_color(c_white);
	}
}