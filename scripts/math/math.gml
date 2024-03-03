/// @param {real} _x
/// @param {real} _y
function v2(_x, _y) constructor {
    x = _x;
    y = _y;

    static copy = function () {
        return new v2(x, y);
    }

    /// @param {real} _x
    /// @param {real} _y
    static add = function(_x, _y) {
        x += _x;
        y += _y;
        return self;
    }

    /// @param {Struct.v2} v
    static addv = function(v) {
        x += v.x;
        y += v.y;
        return self;
    }

    static neg = function() {
        x *= -1;
        y *= -1;
        return self;
    }
}

/// A basic rect struct. 
/// The point x,y is considered to be part of the rect, 
/// while the point (x+w, y+h) is not considered to be
/// part of it.
/// @param {real} _x
/// @param {real} _y
/// @param {real} _w
/// @param {real} _h
function Rect(_x, _y, _w, _h) constructor {
	x = _x;
	y = _y;
	w = _w;
	h = _h;
  
	static xmid = function xmid() { return x+w/2; }
	static ymid = function ymid() { return y+h/2; }
	
	/// @param {Struct.Rect} r
	static manhattan_dist = function manhattan_dist(r) {
		var dx = 0;
		if (!range_overlap(x, x+w, r.x, r.x+r.w)) {
			dx = min(abs(x+w-r.x), abs(r.x+r.w-x));
		}

		var dy = 0;
		if (!range_overlap(y, y+h, r.y, r.y+r.h)) {
			dy = min(abs(y+h-r.y), abs(r.y+r.h-y));
		}

        return dx + dy
	}
	
	/// @param {real} px
	/// @param {real} py
	/// @returns {bool}
	static contains_point = function (px, py) {
		var xoff = px - x;
		var yoff = py - y;
		return (
			xoff >= 0 && xoff < x+w &&
			yoff >= 0 && yoff < y+h
		);
	}
	
	/// @param {Struct.Rect} r
	static overlaps_rect = function (r) {
		return rectangle_in_rectangle(x, y, x+w, y+h, r.x, r.y, r.x+r.w, r.y+r.h) != 0;
	}
}

/// @param {real} x1
/// @param {real} x2
/// @param {real} y1
/// @param {real} y2
function range_overlap(x1, x2, y1, y2) {
	return x1 <= y2 && y1 <= x2;
}

/// @param {real} x1
/// @param {real} x2
/// @param {real} y1
/// @param {real} y2
/// @returns {Array<Real> | Undefined}
function get_range_overlap(x1, x2, y1, y2) {
    if (!range_overlap(x1, x2, y1, y2)) return undefined;
    return [max(x1, y1), min(x2, y2)];
}
