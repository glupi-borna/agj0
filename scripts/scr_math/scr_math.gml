/// @param {real} _x
/// @param {real} _y
function v2(_x, _y) constructor {
    x = _x;
    y = _y;

    static copy = function () {
        return new v2(x, y);
    }

	static set = function (_x, _y) {
		x = _x;
		y = _y;
		return self;
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

	static toString = function() {
		return $"v2({x}, {y})"
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
		return point_in_rectangle(px, py, x, y, x+w-1, y+h-1);
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

/// @param {real} _x
/// @param {real} _y
/// @param {real} _z
function v3(_x, _y, _z) constructor {
    x = _x;
    y = _y;
    z = _z;

    static copy = function () {
        return new v3(x, y, z);
    }

    /// @param {real} _x
    /// @param {real} _y
    /// @param {real} _z
	static set = function (_x, _y, _z) {
		x = _x;
		y = _y;
		z = _z;
		return self;
	}

	/// @param {Struct.v3} v
	static setv = function (v) {
		x = v.x;
		y = v.y;
		z = v.z;
		return self;
	}

	/// @param {real} _z
	static setz = function (_z) {
		z = _z;
		return self;
	}

    /// @param {real} _x
    /// @param {real} _y
    /// @param {real} _z
    static add = function(_x, _y, _z) {
        x += _x;
        y += _y;
        z += _z;
        return self;
    }

    /// @param {Struct.v3} v
    static addv = function(v) {
        x += v.x;
        y += v.y;
        z += v.z;
        return self;
    }

    /// @param {real} _x
    /// @param {real} _y
    /// @param {real} _z
    static sub = function(_x, _y, _z) {
        x -= _x;
        y -= _y;
        z -= _z;
        return self;
    }

    /// @param {Struct.v3} v
    static subv = function(v) {
        x -= v.x;
        y -= v.y;
        z -= v.z;
        return self;
    }

	/// @param {real} deg
	static zrotate = function(deg) {
		var x2 = dcos(deg)*x - dsin(deg)*y;
		var y2 = dsin(deg)*x + dcos(deg)*y;
		x = x2;
		y = y2;
		return self;
	}

    static neg = function() {
        x *= -1;
        y *= -1;
		z *= -1;
        return self;
    }

	static len = function() {
		return point_distance_3d(0, 0, 0, x, y, z);
	}

	static normalize = function() {
		if (x==0 && y== 0 && z==0) return self;
		var l = self.len();
		x = x/l;
		y = y/l;
		z = z/l;
		return self;
	}

	/// @param {real} amt
	static scale = function(amt) {
		x *= amt;
		y *= amt;
		z *= amt;
		return self;
	}

	/// @param {Struct.v3} v
	/// @param {real} amt
	static lerpv = function(v, amt) {
		x = lerp(x, v.x, amt);
		y = lerp(y, v.y, amt);
		z = lerp(z, v.z, amt);
		return self;
	}

    /// @param {Struct.v3} v
	static eq = function(v) {
		return x==v.x && y==v.y && z==v.z;
	}

	static toString = function() {
		return $"v3({x}, {y}, {z})"
	}
}

