enum TILE {
	WALL,
	FLOOR,
};

/// @param {enum.TILE} kind
function Tile(kind) constructor {
	self.kind = kind;
}

/// @returns {struct.Tile}
function cast_tile(val) { return val; }
/// @returns {Array<struct.Tile>}
function cast_tile_arr(val) { return val; }

/**
 * @desc A basic rect struct.
 *		 The point x,y is considered to be part of the
 *		 rect, while the point (x+w, y+h) is not considered
 *		 to be part of it.
 * @param {real} x
 * @param {real} y
 * @param {real} w
 * @param {real} h
 */
function Rect(x, y, w, h) constructor {
	self.x = x;
	self.y = y;
	self.w = w;
	self.h = h;
	
	static xmid = function() { return x+w/2; }
	static ymid = function() { return y+h/2; }
	
	/**
	 * @param {struct.Rect} r
	 */
	static manhattan_dist = function(r) {
		var t1 = y;
		var t2 = r.y;
		var b1 = y+h-1;
		var b2 = r.y+r.h-1;

		var l1 = x;
		var l2 = r.x;
		var r1 = x+w-1;
		var r2 = r.x+r.w-1;

		var xdist = max(abs(l1-r2), abs(l2-r1));
		var ydist = max(abs(t1-b2), abs(t2-b1));

		return xdist+ydist;
	}
	
	/**
	 * @param {real} px
	 * @param {real} py
	 * @returns {bool}
	 */
	static contains_point = function (px, py) {
		var xoff = px - x;
		var yoff = py - y;
		return (
			xoff >= 0 && xoff < x+w &&
			yoff >= 0 && yoff < y+h
		);
	}
	
	/**
	 * @param {struct.Rect} r
	 */
	static overlaps_rect = function (r) {
		return rectangle_in_rectangle(x, y, x+w, y+h, r.x, r.y, r.x+r.w, r.y+r.h) != 0;
	}
}

/// @returns {struct.Rect}
function cast_rect(val) { return val; }
/// @returns {Array<struct.Rect>}
function cast_rect_arr(val) { return val; }
/// @returns {struct.Rect OR undefined}
function cast_optional_rect(val) { return val; }

function Room(x, y, w, h) : Rect(x, y, w, h) constructor {
	self.connections = cast_room_arr([]);

	/**
	 * @param {struct.Room} r
	 * @param {Array<struct.Room>} visited
	 * @self {struct.Room}
	 */
	static is_connected_to = function (r, visited) {
		if (array_contains(self.connections, r)) return true;
		array_push(visited, self);
		for (var i=0; i<array_length(self.connections); i++) {
			var c = self.connections[i];
			if (array_contains(visited, c)) continue;
			if (c.is_connected_to(r, visited)) return true;
		}
		return false;
	}
	
	/**
	 * @param {struct.Room} r
	 * @self {struct.Room}
	 */
	static connect = function (r) {
		if (array_contains(connections, r)) return;
		array_push(connections, r);
		array_push(r.connections, self);
	}
}

/// @returns {struct.Room}
function cast_room(val) { return val; }
/// @returns {Array<struct.Room>}
function cast_room_arr(val) { return val; }
/// @returns {struct.Room OR undefined}
function cast_optional_room(val) { return val; }

/**
 * @param {real} w 
 * @param {real} h
 */
function Dungeon(w, h) constructor {
	self.w = w;
	self.h = h;
	rooms = cast_room_arr([]);
	tiles = cast_tile_arr(array_create(self.w*self.h, undefined));
	
	/**
	 * @param {real} x
	 * @param {real} y
	 */
	static tile_idx = function(x, y) {
		return y*w + x;
	}
	
	static tile_at = function(x, y) {
		return tiles[tile_idx(x, y)]
	}

	static tile_exists = function(x, y) {
		return !is_undefined(tile_at(x, y));
	}

	static room_exists_at = function(x, y) {
		for (var i=0; i<array_length(self.rooms); i++) {
			var r = self.rooms[i];
			if (r.contains_point(x, y)) return true;
		}
		return false;
	}

	/**
	 * @param {real} x
	 * @param {real} y
	 * @param {real} w
	 * @param {real} h
	 * @returns {bool}
	 */
	static room_overlaps_rect = function(x, y, w, h) {
		var rect = new Rect(x, y, w, h);
		for (var i=0; i<array_length(self.rooms); i++) {
			var r = rooms[i];
			if (r.overlaps_rect(rect)) return true;
		}
		return false;
	}

	/**
	 * @param {real} x
	 * @param {real} y
	 * @param {real} w
	 * @param {real} h
	 * @returns {struct.Room OR undefined}
	 */
	static get_room = function(x, y, w, h) {
		if (x+w < self.w && y+h < self.h) {
			if (!room_overlaps_rect(x, y, w, h)) return cast_optional_room(new Room(x, y, w, h));
		}
		
		if (room_exists_at(x, y)) return cast_optional_room(undefined);
		
		for (var xx=max(x-w+1, 0); xx<=min(x,self.w-w); xx++) {
			for (var yy=max(y-h+1, 0); yy<=min(y,self.h-h); yy++) {
				if (!room_overlaps_rect(xx, yy, w, h)) {
					return cast_optional_room(new Room(xx, yy, w, h));
				}
			}
		}
		return cast_optional_room(undefined);
	}
	
	/** @self {struct.Dungeon} */
	static clear = function() {
		self.rooms = cast_rect_arr([]);
		self.tiles = cast_tile_arr(array_create(w*h, undefined));
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
	
	/** @self {struct.Dungeon} */
	static generate = function() {
		var dim = min(w, h);
		repeat(10) {
			var r = get_room(irandom(w-1), irandom(h-1), irandom_range(dim div 10, dim div 3), irandom_range(dim div 10, dim div 3));
			if (!is_undefined(r)) {
				array_push(rooms, cast_rect(r));
			}
		}
		
		fill_rooms();

		for (var i=0; i<array_length(rooms); i++) {
			var r = cast_room(rooms[i]);
			
			var closest = cast_optional_room(undefined);
			var dist = infinity;
			for (var j=i+1; j<array_length(rooms); j++) {
				var r2 = rooms[j];
				var rdist = r.manhattan_dist(r2);
				if (rdist < dist) {
					closest = r2;
					dist = rdist;
				}
			}
			
			if (!is_undefined(closest)) {
				r.connect(closest);
			}
		}
	}
	
	static render = function(tile_size) {
		draw_set_color(c_red);
		for (var xx=0; xx<w; xx++) {
			for (var yy=0; yy<h; yy++) {
				var tile = tile_at(xx, yy);
				if (!is_undefined(tile)) {
					draw_rectangle(xx*tile_size, yy*tile_size, xx*tile_size+tile_size-2, yy*tile_size+tile_size-2, false);
				}
			}
		}

		draw_set_color(c_white);

		for (var i=0; i<array_length(rooms); i++) {
			var r = rooms[i];
			draw_rectangle(r.x*tile_size, r.y*tile_size, (r.x+r.w)*tile_size, (r.y+r.h)*tile_size, true);
			
			draw_set_color(c_blue);
			for (var j=0; j<array_length(r.connections); j++) {
				var c = r.connections[j];
				draw_line(r.xmid()*tile_size, r.ymid()*tile_size, c.xmid()*tile_size, c.ymid()*tile_size);
			}
			draw_set_color(c_white);
		}
	}
}