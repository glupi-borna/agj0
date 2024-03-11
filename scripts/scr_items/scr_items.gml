function Inventory() constructor {
    /// @type {Id.DsMap<real>}
    items = ds_map_create();

    /// @param {Struct.Item} item
    /// @param {real} amount
    static add = function(item, amount) {
        /// @type {real}
        var current_count = ds_map_find_value(items, item) ?? 0;
        items[?item] = current_count+amount;
    }

    /// @param {Struct.Item} item
    /// @param {real} amount
    static remove = function(item, amount) {
        /// @type {real}
        var current_count = ds_map_find_value(items, item) ?? 0;
        assert(current_count >= amount, $"Can not remove more of {item} than exists in inventory (want {amount}, have {current_count})");
        items[? item] = current_count-amount;
        if (current_count-amount == 0) {
            ds_map_delete(items, item);
        }
    }
}

function Item() constructor {
    /// @type {real}
    idx = undefined;
    name = "unknown";
    desc = "unknown";
    sprite = spr_arrow;

    usable_on_party = false;
    usable_on_enemy = false;

    /// @param {Struct.Character} user
    /// @param {Struct.Character} target
    static effect = function(user, target) {}
}

function Item_Firecracker() : Item() constructor {
    name = "Firecracker";
    desc = "Cracks fire, as the name suggests.";

    usable_on_party = false;
    usable_on_enemy = true;

    /// @param {Struct.Character} user
    /// @param {Struct.Character} target
    static effect = function(user, target) {
        target.damaged_by(user, 15);
    }
}

/// @param {Function.Item} item_constructor
function _register_item(item_constructor) {
    var _item = new item_constructor();
    _item.idx = array_length(global.all_items);
    array_push(global.all_items, _item);
}

/// @type {Array<Struct.Item>}
global.all_items = [];
_register_item(Item_Firecracker);

function random_item() {
    return pick_arr(global.all_items);
}
