enum UI_DIR { HORIZONTAL, VERTICAL };

function UI() constructor {
    dir = UI_DIR.VERTICAL;
    cursor = new v2(0, 0);
    gap = new v2(4, 4);

    static get_rect = function (w, h) {
        var r = new Rect(cursor.x, cursor.y, w, h);
        if (dir == UI_DIR.VERTICAL) {
            cursor.y += h + gap.y;
        } else {
            cursor.x += w + gap.x;
        }
        return r;
    }

    static start_row = function () {
        
    }
}