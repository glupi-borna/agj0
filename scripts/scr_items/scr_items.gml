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

    sound = [sfx_swing1, sfx_swing2, sfx_swing3];
    target_anim = "damage";

    usable_on_downed = false;
    usable_on_party = false;
    usable_on_enemy = false;
    usable_outside_battle = false;

    /// @param {Struct.Character} user
    /// @param {Struct.Character} target
    static effect = function(user, target) {}
}

function Item_Firecracker() : Item() constructor {
    name = "Firecracker";
    desc = "This could hurt someone.";
    sound = [sfx_firework1, sfx_firework2, sfx_firework3];

    usable_on_party = false;
    usable_on_enemy = true;

    /// @param {Struct.Character} user
    /// @param {Struct.Character} target
    static effect = function(user, target) {
        target.damaged_by(user, 15);
    }
}

function Item_Sand() : Item() constructor {
    name = "Sand";
    desc = "For throwing in people's eyes.";
    sound = [sfx_sand];

    usable_on_party = false;
    usable_on_enemy = true;

    /// @param {Struct.Character} user
    /// @param {Struct.Character} target
    static effect = function(user, target) {
        target.give_effect(EFFECT.BLINDED);
    }
}

function Item_Programmer_Spaghetti() : Item() constructor {
    name = "Programmer Spaghetti";
    desc = "Merely looking at it is confusing.";
    sound = [sfx_chest1];

    usable_on_party = false;
    usable_on_enemy = true;

    /// @param {Struct.Character} user
    /// @param {Struct.Character} target
    static effect = function(user, target) {
        target.give_effect(EFFECT.CONFUSED);
    }
}

function Item_Rat_Poison() : Item() constructor {
    name = "Rat Poison";
    desc = "No rats around here. Must be effective.";
    sound = [sfx_nme_slurp1, sfx_nme_slurp2, sfx_nme_slurp3];

    usable_on_party = false;
    usable_on_enemy = true;

    /// @param {Struct.Character} user
    /// @param {Struct.Character} target
    static effect = function(user, target) {
        target.give_effect(EFFECT.POISONED);
    }
}

function Item_Charm() : Item() constructor {
    name = "Charm";
    desc = "Can be attached to a necklace. Could charm someone.";
    sound = [sfx_chest1];

    usable_on_party = false;
    usable_on_enemy = true;

    /// @param {Struct.Character} user
    /// @param {Struct.Character} target
    static effect = function(user, target) {
        target.give_effect(EFFECT.CHARMED);
    }
}

function Item_Rusty_Razor() : Item() constructor {
    name = "Rusty Razor";
    desc = "Trims the whiskers, gives you a rash.";
    sound = [sfx_metalscrape1, sfx_metalscrape2];

    usable_on_party = false;
    usable_on_enemy = true;

    /// @param {Struct.Character} user
    /// @param {Struct.Character} target
    static effect = function(user, target) {
        target.give_effect(EFFECT.SENSITIVE);
    }
}

function Item_Anaesthetic() : Item() constructor {
    name = "Anaesthetic";
    desc = "Numbs the pain.";
    sound = [sfx_pills];

    usable_on_party = true;
    usable_on_enemy = false;

    /// @param {Struct.Character} user
    /// @param {Struct.Character} target
    static effect = function(user, target) {
        target.give_effect(EFFECT.NUMB);
    }
}

function Item_Bandage() : Item() constructor {
    name = "Adhesive Bandage";
    desc = "Makes your booboos all better.";
    sound  = [sfx_bandage];

    usable_on_party = true;
    usable_on_enemy = false;
    usable_outside_battle = true;

    /// @param {Struct.Character} user
    /// @param {Struct.Character} target
    static effect = function(user, target) {
        target.hp = clamp(target.hp + 10, 0, target.stats.max_hp);
    }
}

function Item_Bucket_Of_Water() : Item() constructor {
    name = "Bucket Of Water";
    desc = "Splashing someone with it might be rude, but will wake them up.";
    sound  = [sfx_splash1, sfx_splash2];

    usable_on_downed = true;
    usable_on_party = true;
    usable_on_enemy = false;
    usable_outside_battle = true;

    /// @param {Struct.Character} user
    /// @param {Struct.Character} target
    static effect = function(user, target) {
        target.hp = target.stats.max_hp;
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
_register_item(Item_Sand);
_register_item(Item_Programmer_Spaghetti);
_register_item(Item_Rat_Poison);
_register_item(Item_Charm);
_register_item(Item_Rusty_Razor);
_register_item(Item_Anaesthetic);
_register_item(Item_Bandage);
_register_item(Item_Bucket_Of_Water);

function random_item() {
    return pick_arr(global.all_items);
}
