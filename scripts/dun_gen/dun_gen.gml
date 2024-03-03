enum TILE {
	EMPTY,
	WALL,
	FLOOR,
	DOOR,
};

/// @param {Enum.TILE} tile
function tile_color(tile) {
	switch (tile) {
	case TILE.WALL: return #335588;
	case TILE.FLOOR: return #338855;
	case TILE.DOOR: return #883333;
	}
}

/// @param {Enum.TILE} kind
function Tile(kind) constructor {
	self.kind = kind;
}

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
	static fill = function(d) {
		var xmov = sign(x_end - x_start);
		var ymov = sign(y_end - y_start);

		var x_y = variant ? y_start : y_end;
		for (var xx=x_start; xx!=x_end+xmov; xx+=xmov) {
			d.tiles[d.tile_idx(xx, x_y)] = new Tile(TILE.FLOOR);
		}

		var y_x = variant ? x_end : x_start;
		for (var yy=y_start; yy!=y_end+ymov; yy+=ymov) {
			d.tiles[d.tile_idx(y_x, yy)] = new Tile(TILE.FLOOR);
		}

		var zerox = ymov==0 ? xmov : 0;
		var zeroy = xmov==0 ? ymov : 0;

		if (variant) {
			d.tiles[d.tile_idx(x_start+xmov, y_start+zeroy)] = new Tile(TILE.DOOR);
			d.tiles[d.tile_idx(x_end-zerox, y_end-ymov)] = new Tile(TILE.DOOR);
		} else {
			d.tiles[d.tile_idx(x_start+zerox, y_start+ymov)] = new Tile(TILE.DOOR);
			d.tiles[d.tile_idx(x_end-xmov, y_end-zeroy)] = new Tile(TILE.DOOR);
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
	w = _w;
	h = _h;
	/// @type {Array<Struct.Room>}
	rooms = [];
	/// @type {Array<Struct.Tile|Undefined>}
	tiles = array_create(w*h, undefined);
	
	/// @param {real} x
	/// @param {real} y
	static tile_idx = function(x, y) {
		return y*w + x;
	}
	
	/// @param {real} x
	/// @param {real} y
	static tile_at = function(x, y) {
		if (x < 0 || y < 0 || x >= w || y >= h) return undefined;
		return tiles[tile_idx(x, y)]
	}

	/// @param {real} x
	/// @param {real} y
	static tile_kind = function(x, y) {
		var tile = tile_at(x, y);
		if (!is_undefined(tile)) return tile.kind;
		return TILE.EMPTY;
	}

	/// @param {real} x
	/// @param {real} y
	static tile_exists = function(x, y) {
		return !is_undefined(tile_at(x, y));
	}

	/// @param {real} x
	/// @param {real} y
	/// @param {Enum.TILE} kinds
	static tile_has_neighbor = function(x, y, kinds, diagonals=false) {
		if (array_contains(kinds, tile_kind(x-1, y))) return true;
		if (array_contains(kinds, tile_kind(x+1, y))) return true;
		if (array_contains(kinds, tile_kind(x, y-1))) return true;
		if (array_contains(kinds, tile_kind(x, y+1))) return true;

		if (diagonals) {
			if (array_contains(kinds, tile_kind(x-1, y-1))) return true;
			if (array_contains(kinds, tile_kind(x+1, y-1))) return true;
			if (array_contains(kinds, tile_kind(x-1, y+1))) return true;
			if (array_contains(kinds, tile_kind(x+1, y+1))) return true;
		}

		return false;
	}

	/// @param {real} x
	/// @param {real} y
	static room_exists_at = function(x, y) {
		for (var i=0; i<array_length(self.rooms); i++) {
			var r = self.rooms[i];
			if (r.contains_point(x, y)) return true;
		}
		return false;
	}

	/// @param {real} x
	/// @param {real} y
	/// @param {real} w
	/// @param {real} h
	/// @returns {bool}
	static room_overlaps_rect = function(x, y, w, h) {
		var rect = new Rect(x, y, w, h);
		for (var i=0; i<array_length(self.rooms); i++) {
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
		if (x>0 && y> 0 && x+w < self.w && y+h < self.h) {
			if (!room_overlaps_rect(x, y, w, h)) return new Room(x, y, w, h);
		}
		
		if (room_exists_at(x, y)) return undefined;
		
		for (var xx=max(x-w+1, 1); xx<=min(x,self.w-w-1); xx++) {
			for (var yy=max(y-h+1, 1); yy<=min(y,self.h-h-1); yy++) {
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
		tiles = array_create(w*h, undefined);
	}
	
	static fill_rooms = function() {
		for (var i=0; i<array_length(rooms); i++) {
			var r = rooms[i];
			for (var xx=0; xx<r.w; xx++) {
				for (var yy=0; yy<r.h; yy++) {
					tiles[tile_idx(r.x+xx, r.y+yy)] = new Tile(TILE.FLOOR);
				}
			}
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

        print($"Connecting islands {i1.name} ({array_length(i1.rooms)}) and {i2.name} ({array_length(i2.rooms)})");

		for (var i=0; i<array_length(i1.rooms); i++) {
			var r1 = i1.rooms[i];
			for (var j=0; j<array_length(i2.rooms); j++) {
				var r2 = i2.rooms[j];
				var dist = r1.manhattan_dist(r2);
				if (dist < closest_dist) {
                    print($"  +  Rooms {r1.name} and {r2.name} are closer ({dist}) than rooms {p1.name} and {p2.name} ({closest_dist})");
					p1 = r1;
					p2 = r2;
					closest_dist = dist;
				} else {
                     print($"  !  Rooms {r1.name} and {r2.name} are not closer ({dist}) than rooms {p1.name} and {p2.name} ({closest_dist})");
               }
			}
		}

		print($"Connecting islands {i1.name} and {i2.name} via rooms {p1.name} and {p2.name}");
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
        
		var dim = min(w, h);
		repeat(20) {
			var r = get_room(irandom(w-1), irandom(h-1), irandom_range(dim div 10, dim div 3), irandom_range(dim div 10, dim div 3));
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
			
			if (!is_undefined(closest)) {
                print($"Connecting {r.x},{r.y} and {closest.x},{closest.y} ({dist})");
				r.connect(closest);
			}
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
        
		for (var xx=0; xx<w; xx++) {
			for (var yy=0; yy<h; yy++) {
				if (tile_kind(xx, yy) == TILE.EMPTY && tile_has_neighbor(xx, yy, [TILE.FLOOR, TILE.DOOR])) {
					tiles[tile_idx(xx, yy)] = new Tile(TILE.WALL);
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

	static render = function(tile_size) {
		for (var xx=0; xx<w; xx++) {
			for (var yy=0; yy<h; yy++) {
				var tile = tile_at(xx, yy);
				if (!is_undefined(tile)) {
                    draw_set_color(tile_color(tile.kind));
					draw_rectangle(xx*tile_size, yy*tile_size, xx*tile_size+tile_size-2, yy*tile_size+tile_size-2, false);
				}
			}
		}

		for (var i=0; i<array_length(rooms); i++) {
			var r = rooms[i];
            draw_set_color(c_white);
			draw_rectangle(r.x*tile_size, r.y*tile_size, (r.x+r.w)*tile_size, (r.y+r.h)*tile_size, true);
			
			draw_set_color(c_blue);
			for (var j=0; j<array_length(r.connections); j++) {
				var c = r.connections[j];
				draw_line(r.xmid()*tile_size, r.ymid()*tile_size, c.xmid()*tile_size, c.ymid()*tile_size);
                draw_text(
                    (r.xmid()+c.xmid())*0.5*tile_size,
                    (r.ymid()+c.ymid())*0.5*tile_size,
                    $"{r.manhattan_dist(c)}"
                );
			}
			draw_set_color(c_red);
            draw_text(r.xmid()*tile_size, r.ymid()*tile_size, r.name);
		}
        
        for (var ii=0; ii<array_length(islands); ii++) {
            var is = islands[ii];
			draw_set_color(c_white);
		    draw_text(is.rooms[0].xmid()*tile_size, is.rooms[0].ymid()*tile_size+20, is.name);
        }

		draw_set_color(c_red);
		var l = get_leaf_room();
		if (!is_undefined(l)) draw_circle(l.xmid()*tile_size, l.ymid()*tile_size, 32, false);

		draw_set_color(c_white);
	}
}