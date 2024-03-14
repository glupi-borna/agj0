enum EFFECT { BLINDED, CONFUSED, POISONED, CHARMED, SENSITIVE, NUMB };

/// @param {Enum.EFFECT} eff
function effect_str(eff) {
    switch (eff) {
        case EFFECT.BLINDED: return "Blinded";
        case EFFECT.CONFUSED: return "Confused";
        case EFFECT.POISONED: return "Poisoned";
        case EFFECT.CHARMED: return "Charmed";
        case EFFECT.SENSITIVE: return "Sensitive";
        case EFFECT.NUMB: return "Numb";
    }
}

/// @param {string} _name
/// @param {Struct.Stats} _stats
/// @param {string} _model
/// @param {Asset.GMSprite} _texture
/// @param {real} _size
/// @param {bool} _floating
function Character(_name, _stats, _model, _texture, _size, _floating) constructor {
    name = _name;
    stats = _stats;
    model = _model;
    texture = _texture;
    icon = asset_get_index(sprite_get_name(_texture) + "_icon");
    assert(icon!=-1, $"Failed to find sprite: {sprite_get_name(_texture) + "_icon"}")
    size = _size;
    floating = _floating;
    hp = stats.max_hp;
    effects = [];

    pos = new v3(0, 0, 0);
    fwd = new v3(1, 1, 0);

    static look_pos = function() {
        var out = pos.copy().add(0, 0, size);
        if (floating) out.add(0, 0, size*2);
        return out;
    }

    death_time = undefined;

    static render_pos = function() {
        if (!floating) return pos.copy();
        var p = look_pos().add(0, 0, sin(current_time/1000)*size*0.1);
        if (hp == 0) {
            death_time = death_time ?? current_time;
            var time = clamp((current_time - death_time)/500, 0, 1);
            return p.lerpv(pos.copy().add(0, 0, size*0.75), time);
        }
        return p;
    }

    /// @param {Enum.EFFECT} effect
    static give_effect = function(effect) {
        if (array_contains(effects, effect)) return;
        array_push(effects, effect);
    }

    /// @param {Struct.Character} attacker
    /// @param {real} damage
    static damaged_by = function(attacker, damage) {
        if (array_contains(effects, EFFECT.NUMB)) damage = ceil(damage*0.5);
        if (array_contains(effects, EFFECT.SENSITIVE)) damage = damage*2;
        hp = clamp(hp-damage, 0, stats.max_hp);
    }

    /// @param {real} x
    /// @param {real} y
    /// @param {bool} hl
    static draw_head = function(x, y, hl) {
        draw_set_color(c_white);
        shader_set(sh_flat);
        draw_sprite_ext(icon, 0, x+gui_px(5), y+gui_px(5), gui_px(1), gui_px(1), 0, hl?c_blue:c_white, 1);
        shader_reset();

        var perc = clamp(hp/stats.max_hp, 0, 1);

        var w = gui_px(64);
        var h = gui_px(10);
        var p = gui_px(2);

        draw_sprite_ext(icon, 0, x, y, gui_px(1), gui_px(1), 0, c_white, 1);
        draw_set_color(c_white);
        draw_rectangle(x, y+(w-2*p), x+w, y+w-2*p+h, false);

        draw_set_color(c_blue);
        draw_rectangle(x+p, y+w-p, x+(w-p)*perc, y+w-3*p+h, false);

        var yy = y+w-3*p+h+p;
        var th = text_height(" ")+2*p;
        for (var i=0; i<array_length(effects); i++) {
            var eff = effect_str(effects[i]);
            var tw = text_width(eff) + 2*p;
            var x1 = x+(w/2)-(tw/2);
            var x2 = x1 + tw;
            var y1 = yy;
            var y2 = yy + th;

            draw_set_color(c_red);
            draw_rectangle(x1, y1, x2, y2, false);
            draw_set_color(c_white);
            render_text(x1+p, y1+p, eff);
            yy += th+p;
        }
    }
}

enum INITIATIVE { PARTY, ENEMY, NONE };

/// @param {Struct.Character} c1
/// @param {Struct.Character} c2
function sort_chars_by_speed(c1, c2) {
    if (c1.stats.speed > c2.stats.speed) return -1;
    if (c1.stats.speed < c2.stats.speed) return 1;
    return 0;
}

/// @param {Struct.GS_Battle} gs
function battle_turn_cam_target(gs) {
    var current_char = gs.turn_order[gs.current_turn];
    var is_enemy_turn = array_contains(gs.enemies, current_char);
    /// @type {Struct.v3}
    var cam_pos = undefined;

    if (is_enemy_turn) {
        cam_pos = gs.chars_mid(gs.party).scale(2).setz(40);
    } else {
        var lp = current_char.look_pos();
        cam_pos = lp.subv(current_char.fwd.copy().normalize().setz(0).zrotate(45).scale(TILE_SIZE)).setz(20);
    }

    var cam_fwd = current_char.look_pos().addv(current_char.fwd.copy().scale(TILE_SIZE*0.5)).subv(cam_pos).normalize();
    return [cam_pos, cam_fwd];
}

enum BATTLE_STATE { TURN, ANIMATION };

/// @param {Struct.Character} _char
/// @param {string|Undefined} _anim_name
/// @param {real} _spd
function Seq_Anim(_char, _anim_name, _spd) constructor {
    char = _char;
    anim_name = _anim_name;
    spd = _spd;
}

/// @param {Struct.v3} _pos
/// @param {Struct.v3} _look_at
function Seq_Cam(_pos, _look_at) constructor {
    pos = _pos;
    look_at = _look_at;
}

/// @param {Struct.Character} _char
/// @param {Struct.v3} _target
/// @param {real} _time
function Seq_Move(_char, _target, _time) constructor {
    char = _char;
    target = _target;
    time = _time;
}

/// @param {string} _text
/// @param {real} _time
function Seq_Text(_text, _time) constructor {
    text = _text;
    time = _time;
}

/// @param {Asset.GMSound} _sfx
/// @param {Struct.v3} _pos
function Seq_Sfx(_sfx, _pos) constructor {
    sfx = _sfx;
    pos = _pos;
}

/// @param {real} _time
function Seq_Wait(_time) constructor {
    time = _time;
}

/// @param {Function} _fn
/// @param {Array} _args
function Seq_Do(_fn, _args) constructor {
    fn = _fn;
    args = _args;
}

enum BATTLE_MENU { MAIN, ITEMS, TARGETING };

/// @param {Struct.GS_Dungeon} _gs
/// @param {Array<Struct.Character>} _enemies
/// @param {Enum.INITIATIVE} _initiative
function GS_Battle(
    _gs,
    _enemies,
    _initiative
) : Game_State() constructor {
    gs = _gs;
    party = gs.party;
    /// @type {Array<Struct.Character>}
    enemies = _enemies;
    initiative = _initiative;
    /// @type {Array<Struct.Character>}
    turn_order = [];
    current_turn = 0;
    state = BATTLE_STATE.TURN;
    /// @type {Struct.Item}
    selected_item = undefined;
    menu = BATTLE_MENU.MAIN;
    ui = new UI();

    /// @type {Struct.Seq_Anim | Struct.Seq_Do | Struct.Seq_Move | Struct.Seq_Wait | Struct.Seq_Cam | Struct.Seq_Sfx}
    current_seq_item = undefined;
    /// @type {Struct.Seq_Anim | Struct.Seq_Do | Struct.Seq_Move | Struct.Seq_Wait | Struct.Seq_Cam | Struct.Seq_Sfx}
    seq_item_start = undefined;
    /// @type {Struct.v3}
    lerp_from = undefined;
    /// @type {Array<Struct.Seq_Anim | Struct.Seq_Do | Struct.Seq_Move | Struct.Seq_Wait | Struct.Seq_Cam | Struct.Seq_Sfx>}
    sequence = [];

    display_text = "";

    cam_target_pos = new v3(0, 0, 30);
    cam_target_fwd = new v3(0, 0, -1);

    cam_pos = new v3(0, 0, 30);
    cam_fwd = new v3(0, 0, -1);

    will_run = -1;

    outline = -1;

    enter_duration = 500;
    exit_duration = 1000;

    static no_initiative_positions = [
        new v3(0, TILE_SIZE*0.5, 0),
        new v3(-TILE_SIZE*0.75, TILE_SIZE*1.25, 0),
        new v3( TILE_SIZE*0.75,  TILE_SIZE*1.25, 0),
    ];

    static initiative_positions = [
        new v3(0, -TILE_SIZE, 0),
        new v3(-TILE_SIZE, 0, 0),
        new v3( TILE_SIZE, 0, 0),
    ];

    /// @param {Array<Struct.Character>} chars
    static chars_mid = function(chars) {
        var mid = new v3(0, 0, 0);
        for (var i=0; i<array_length(chars); i++) {
            mid.addv(chars[i].look_pos());
        }
        mid.scale(1/array_length(chars));
        return mid;
    }

    static is_party_turn = function() {
        return state == BATTLE_STATE.TURN && array_contains(party, turn_order[current_turn])
    }

    static is_enemy_turn = function() {
        return state == BATTLE_STATE.TURN && array_contains(enemies, turn_order[current_turn])
    }

    static default_look_dir = function(char) {
        var look_dir = new v3(1, 1, 0);
        if (array_contains(enemies, char)) {
            look_dir.setv(chars_mid(party));
        } else {
            look_dir.setv(chars_mid(enemies));
        }
        return look_dir.subv(char.pos).normalize();
    }

    static init = function () {
        if (initiative == INITIATIVE.ENEMY) {
            array_sort(enemies, sort_chars_by_speed);
            for (var i=0; i<array_length(enemies); i++) {
                array_push(turn_order, enemies[i]);
                enemies[i].pos.setv(initiative_positions[i]);
            }

            array_sort(party, sort_chars_by_speed);
            for (var i=0; i<array_length(party); i++) {
                array_push(turn_order, party[i]);
                party[i].pos.setv(no_initiative_positions[i]);
            }

        } else if (initiative == INITIATIVE.PARTY) {
            array_sort(party, sort_chars_by_speed);
            for (var i=0; i<array_length(party); i++) {
                array_push(turn_order, party[i]);
                party[i].pos.setv(initiative_positions[i]);
            }

            array_sort(enemies, sort_chars_by_speed);
            for (var i=0; i<array_length(enemies); i++) {
                array_push(turn_order, enemies[i]);
                enemies[i].pos.setv(no_initiative_positions[i]);
            }

        } else {
            for (var i=0; i<array_length(party); i++) {
                array_push(turn_order, party[i]);
                party[i].pos.setv(initiative_positions[i]);
            }
            for (var i=0; i<array_length(enemies); i++) {
                array_push(turn_order, enemies[i]);
                enemies[i].pos.setv(no_initiative_positions[i]);
            }
            array_sort(turn_order, sort_chars_by_speed);
        }

        for (var i=0; i<array_length(turn_order); i++) {
            var char = turn_order[i];
            anim_char(char, "default", 0.01, 1);
            char.fwd.setv(default_look_dir(char));
        }

        var char = turn_order[current_turn];
        while (char.hp <= 0) {
            current_turn = (current_turn+1)%array_length(turn_order);
            char = turn_order[current_turn];
            char.effects = [];
        }

        var ct = battle_turn_cam_target(self);
        cam_target_pos = ct[0];
        cam_target_fwd = ct[1];
    }

    /// @param {Struct.Character} char
    /// @param {string} anim_name
    /// @param {real} spd
    /// @param {real} lspd
    static anim_char = function(char, anim_name, spd, lspd) {
        var idx = array_get_index(turn_order, char);
        if (anim_name == "default") {
            if (char.hp == 0) {
                if (animation_name(char.model, $"battle:{idx}") != "death") {
                    anim_char(char, "death", spd, 0.2);

                    if (array_contains(enemies, char)) {
                        after(250, play_sfx, [choose(sfx_nme_death1, sfx_nme_death2), char.look_pos()]);
                    }
                }
            } else if (char.hp < char.stats.max_hp*0.33 && animation_exists(char.model, "idle_hurt")) {
                anim_char(char, "idle_hurt", spd, 0.2);
            } else {
                anim_char(char, "idle", spd, 0.2);
            }
        } else {
            animation_play(char.model, $"battle:{idx}", anim_name, spd, lspd, true);
        }
    }

    static update = function () {
        if (entering()||exitting()) { return }

        if (state == BATTLE_STATE.TURN) {
            if (array_all(enemies, function(e) {return e.hp==0})) {
                /// @type {Array<Struct.Item>}
                var items = [];
                set_game_state(new GS_Menu_Battle_Stats(self, items), false, true);
            }

            if (array_all(party, function(e) {return e.hp==0})) {
                gs.level_transition(gs.lvl);
                return;
            }
        }

        if (state == BATTLE_STATE.ANIMATION) {
            if (is_undefined(current_seq_item)) {
                if (array_length(sequence) == 0) {
                    var char = turn_order[current_turn];
                    char.fwd = default_look_dir(char);

                    for (var i=0; i<array_length(turn_order); i++) {
                        var ch = turn_order[i];
                        if (ch.hp <= 0) anim_char(ch, "death", 0.1, 1);
                    }

                    current_turn = (current_turn+1)%array_length(turn_order);
                    char = turn_order[current_turn];
                    while (char.hp <= 0) {
                        if (will_run == current_turn) {
                            gs.level_transition(-1, ["You managed to get away!"]);
                            return;
                        }

                        current_turn = (current_turn+1)%array_length(turn_order);
                        char = turn_order[current_turn];
                    }

                    state = BATTLE_STATE.TURN;
                    var ct = battle_turn_cam_target(self);
                    cam_target_pos = ct[0];
                    cam_target_fwd = ct[1];
                    return;
                }

                current_seq_item = sequence[0];
                array_shift(sequence);
                seq_item_start = current_time;

                if (is_instanceof(current_seq_item, Seq_Wait)) {
                    /// @type {Struct.Seq_Wait}
                    var w = current_seq_item;
                    after(w.time, function(battle) { battle.current_seq_item = undefined; }, [self]);

                } else if (is_instanceof(current_seq_item, Seq_Text)) {
                    /// @type {Struct.Seq_Text}
                    var t = current_seq_item;
                    display_text = t.text;
                    after(t.time, function(battle) {
                        battle.current_seq_item = undefined;
                        battle.display_text = "";
                    }, [self]);

                } else if (is_instanceof(current_seq_item, Seq_Move)) {
                    /// @type {Struct.Seq_Move}
                    var m = current_seq_item;
                    lerp_from = m.char.pos.copy();
                    after(m.time, function(battle) { battle.current_seq_item = undefined; }, [self]);

                } else if (is_instanceof(current_seq_item, Seq_Anim)) {
                    /// @type {Struct.Seq_Anim}
                    var a = current_seq_item;
                    anim_char(a.char, a.anim_name, a.spd, 0.2);
                    current_seq_item = undefined;

                } else if (is_instanceof(current_seq_item, Seq_Do)) {
                    /// @type {Struct.Seq_Do}
                    var d = current_seq_item;
                    script_execute_ext(d.fn, d.args);
                    current_seq_item = undefined;

                } else if (is_instanceof(current_seq_item, Seq_Sfx)) {
                    /// @type {Struct.Seq_Sfx}
                    var s = current_seq_item;
                    play_sfx(s.sfx, s.pos);
                    current_seq_item = undefined;

                } else if (is_instanceof(current_seq_item, Seq_Cam)) {
                    /// @type {Struct.Seq_Cam}
                    var c = current_seq_item;
                    cam_target_pos = c.pos;
                    cam_target_fwd = c.look_at.subv(c.pos).normalize();
                    current_seq_item = undefined;
                }

            } else if (is_instanceof(current_seq_item, Seq_Move)) {
                /// @type {Struct.Seq_Move}
                var m = current_seq_item;
                var amt = clamp((current_time-seq_item_start)/m.time, 0, 1);
                m.char.pos.setv(lerp_from).lerpv(m.target, amt);
                if (lerp_from.x != m.target.x || lerp_from.y != m.target.y) {
                    m.char.fwd.setv(m.target).subv(lerp_from).normalize();
                }
                if (amt == 1) current_seq_item = undefined;
            }
        } else if (is_enemy_turn()) {
            var enemy = turn_order[current_turn];
            var old_pos = enemy.pos.copy();

            var target_arr = party;

            if (array_contains(enemy.effects, EFFECT.CHARMED)) {
                target_arr = array_dup(enemies);
                var self_idx = array_get_index(target_arr, enemy);
                array_delete(target_arr, self_idx, 1);
            }

            if (array_contains(enemy.effects, EFFECT.CONFUSED)) {
                var conf_idx = array_get_index(enemy.effects, EFFECT.CONFUSED);
                array_delete(enemy.effects, conf_idx, 1);
                target_arr = [enemy];
            }

            if (array_length(target_arr) == 0) {
                sequence = [new Seq_Text($"{enemy.name} refuses to move!", 3000)];
                state = BATTLE_STATE.ANIMATION;
                return;
            }

            /// @type {Struct.Character}
            var target = pick_arr(array_filter(target_arr, function(p) { return p.hp > 0; }));

            var target_dir = target.pos.copy().subv(enemy.pos).normalize();
            var target_pos = target.pos.copy().subv(target_dir.copy().scale(enemy.size*0.75));

            if (enemy.floating) target_pos.z -= enemy.size;

            var new_cam_pos = target.look_pos().addv(target_dir.copy().zrotate(90).scale(TILE_SIZE));

            if (target == enemy) {
                new_cam_pos = cam_pos;
            }

            sequence = [
                new Seq_Wait(500),
                new Seq_Cam(new_cam_pos, target.look_pos()),
                new Seq_Anim(enemy, "idle", 0.01),
                new Seq_Move(enemy, target_pos, 500),
                new Seq_Anim(enemy, "attack", 0.03),
                new Seq_Wait(250),
                new Seq_Sfx(choose(sfx_nme_attack1, sfx_nme_attack2), enemy.look_pos()),
                new Seq_Sfx(choose(sfx_nme_slurp1, sfx_nme_slurp2, sfx_nme_slurp3), target.look_pos()),
                new Seq_Anim(target, "damage", 0.02),
                new Seq_Do(function(target, enemy){ target.damaged_by(enemy, enemy.stats.attack); }, [target, enemy]),
                new Seq_Wait(250),
                new Seq_Anim(target, "default", 0.01),
                new Seq_Anim(enemy, "default", 0.01),
                new Seq_Move(enemy, old_pos, 500),
            ];

            if (array_contains(enemy.effects, EFFECT.BLINDED)) {
                var eff_idx = array_get_index(enemy.effects, EFFECT.BLINDED);
                array_delete(enemy.effects, eff_idx, 1);
                sequence = [
                    new Seq_Text($"{enemy.name} is blinded!", 3000),
                ];
            }

            if (array_contains(enemy.effects, EFFECT.POISONED)) {
                array_push(sequence,
                    new Seq_Cam(new_cam_pos, enemy.look_pos()),
                    new Seq_Wait(250),
                    new Seq_Anim(enemy, "damage", 0.02),
                    new Seq_Sfx(choose(sfx_nme_slurp1, sfx_nme_slurp2, sfx_nme_slurp3), target.look_pos()),
                    new Seq_Wait(250),
                    new Seq_Do(function(enemy) {
                        var dmg = ceil(enemy.stats.max_hp*0.1);
                        enemy.hp = clamp(enemy.hp - dmg, 1, 999999);
                    }, [enemy]),
                    new Seq_Wait(250),
                    new Seq_Anim(enemy, "default", 0.01),
                );
            }

            state = BATTLE_STATE.ANIMATION;

        } else if (is_party_turn() && current_turn == will_run) {
            gs.level_transition(-1, ["You managed to get away!"]);
            return;
        }
    }

    static gui = function() {
        outline = -1;
        do_2d();

        if (entering()||exitting()) {
            draw_set_color(c_black);
            draw_set_alpha(1-animate_io());
            draw_rectangle(0, 0, WW, WH, false);
            draw_set_alpha(1);
            return;
        }

        var Y = WH*0.33;
        for (var i=0; i<array_length(enemies); i++) {
            var e = enemies[i];
            e.draw_head(gui_px(10), Y, turn_order[current_turn]==e);
            Y += gui_px(WH*0.2);
        }

        Y = WH*0.33;
        for (var i=0; i<array_length(party); i++) {
            var c = party[i];
            c.draw_head(WW-gui_px(74), Y, turn_order[current_turn]==c);
            Y += gui_px(WH*0.2);
        }

        switch (state) {
            case BATTLE_STATE.TURN:
                if (!is_party_turn()) return;
                ui.start_frame();

                bp_register("Arrows, WASD", "Change selection");
                bp_register("Enter", "Confirm");

                ui.cursor.set(WW/4-100, WH/3);

                if (menu == BATTLE_MENU.MAIN) {

                    if (ui.button("throw", "Attack", gui_px(200))) {
                        selected_item = undefined;
                        menu = BATTLE_MENU.TARGETING;
                    }
                    ui.hint("Throw whatever at the enemy. Won't do much damage.");

                    if (ds_map_size(gs.inventory.items) > 0) {
                        if (ui.button("use", "Use item", gui_px(200))) {
                            menu = BATTLE_MENU.ITEMS;
                        }
                        ui.hint("Throw something from your backpack at the enemy.");
                    }

                    if (will_run == -1) {
                        if (ui.button("run", "Run", gui_px(200))) {
                            will_run = current_turn;
                            state = BATTLE_STATE.ANIMATION;
                            sequence = [];
                        }
                        ui.hint("Skip turn to try and escape on your next one.");
                    }

                    ui.label_bg(ui.hint_text, c_black, 0, c_white);

                } else if (menu == BATTLE_MENU.ITEMS) {
                    /// @type {Array<Struct.Item>}
                    var inv = ds_map_keys_to_array(gs.inventory.items);

                    for (var i=0; i<array_length(inv); i++) {
                        var item = inv[i];
                        var count = gs.inventory.items[? item];

                        ui.start_row();
                            if (ui.button($"item:{item.name}", item.name, gui_px(200))) {
                                selected_item = item;
                                menu = BATTLE_MENU.TARGETING;
                                gs.inventory.remove(item, 1);
                            }
                            ui.hint(item.desc);
                            ui.label_bg($"x{count}", c_white);
                        ui.end_container();
                    }

                    ui.start_row();
                        ui.get_rect(gui_px(50), 0);
                        ui.label_bg(ui.hint_text, c_black, 0, c_white);
                    ui.end_container();

                    if (ui.button("back", "Back")) {
                        menu = BATTLE_MENU.MAIN;
                    }

                } else if (menu == BATTLE_MENU.TARGETING) {
                    /// @type {Array<Struct.Character>}
                    var targets = [];
                    if (!is_undefined(selected_item)) {
                        if (selected_item.usable_on_party) {
                            for (var i=0; i<array_length(party); i++) {
                                var char = party[i];
                                if (selected_item.usable_on_downed && char.hp == 0) {
                                    array_push(targets, char);
                                } else if (!selected_item.usable_on_downed && char.hp > 0) {
                                    array_push(targets, char);
                                }
                            }
                        }

                        if (selected_item.usable_on_enemy) {
                            for (var i=0; i<array_length(enemies); i++) {
                                var e = enemies[i];
                                if (e.hp > 0) array_push(targets, e);
                            }
                        }
                    } else {
                        targets = enemies;
                    }

                    for (var i=0; i<array_length(targets); i++) {
                        var t = targets[i];

                        if (ui.button($"target:{i}", t.name, 200)) {
                            var char = turn_order[current_turn];
                            var old_pos = char.pos.copy();
                            var target_dir = t.pos.copy().subv(char.pos).normalize();
                            var target_pos = char.pos.copy().addv(target_dir);

                            var new_cam_pos1c1 = char.look_pos().lerpv(t.look_pos(), 0.5).addv(target_dir.copy().zrotate(90).scale(TILE_SIZE));
                            var new_cam_pos1c2 = char.look_pos().lerpv(t.look_pos(), 0.5).addv(target_dir.copy().zrotate(-90).scale(TILE_SIZE));
                            var new_cam_pos1 = new_cam_pos1c1;

                            var deg = 90;
                            if (new_cam_pos1c1.len() > new_cam_pos1c2.len()) {
                                new_cam_pos1 = new_cam_pos1c2;
                                deg = -90;
                            }

                            var new_cam_pos2 = char.look_pos().addv(target_dir.copy().zrotate(deg).scale(TILE_SIZE));

                            var sound = choose(sfx_punch1, sfx_punch2);
                            var target_anim = "damage";
                            var seq_effect = new Seq_Do(function(t, char){ t.damaged_by(char, char.stats.attack); }, [t, char]);

                            if (!is_undefined(selected_item)) {
                                sound = pick_arr(selected_item.sound);
                                target_anim = selected_item.target_anim;
                                seq_effect = new Seq_Do(function(t, char, i){ i.effect(char, t); }, [t, char, selected_item]);
                            }

                            if (t == char) {
                                new_cam_pos1 = cam_pos;
                                new_cam_pos2 = cam_pos;
                            }

                            sequence = [
                                new Seq_Cam(new_cam_pos1, char.look_pos()),
                                new Seq_Anim(char, "walk", 0.01),
                                new Seq_Move(char, target_pos, 100),
                                new Seq_Anim(char, "item", 0.01),
                                new Seq_Wait(700),
                                new Seq_Sfx(choose(sfx_swing1, sfx_swing2, sfx_swing3), char.look_pos()),
                                new Seq_Wait(500),
                                new Seq_Cam(new_cam_pos2, t.look_pos()),
                                new Seq_Wait(250),
                                new Seq_Anim(t, target_anim, 0.02),
                                new Seq_Sfx(sound, t.pos),
                                seq_effect,
                                new Seq_Wait(250),
                                new Seq_Anim(t, "default", 0.01),
                                new Seq_Anim(char, "walk", 0.01),
                                new Seq_Move(char, old_pos, 100),
                                new Seq_Anim(char, "default", 0.01),
                            ];
                            menu = BATTLE_MENU.MAIN;
                            state = BATTLE_STATE.ANIMATION;
                        }

                        if (ui.last == ui.focused) {
                            outline = array_get_index(turn_order, t);
                            cam_target_fwd.setv(t.look_pos().copy().subv(cam_pos));
                            cam_target_pos.z = t.look_pos().z + 10;
                        }
                    }

                    if (ui.button("back", "Back")) {
                        if (is_undefined(selected_item)) {
                            menu = BATTLE_MENU.MAIN;
                        } else {
                            menu = BATTLE_MENU.ITEMS;
                            ui.focused = $"item:{selected_item.name}";
                        }
                    }
                }

                ui.end_frame();
            break;

            case BATTLE_STATE.ANIMATION:
                if (display_text != "") {
                    ui.start_frame();
                    ui.cursor.set(WW/4, WH/2);
                    ui.label_bg(display_text, c_red, 0, c_white);
                }
            break;
        }

    }

    static render = function () {
        do_3d(600, cull_noculling);
        update_animations();

        draw_clear(gpu_get_fog()[1]);

        var current_char = turn_order[current_turn];

        cam_pos.lerpv(cam_target_pos, 0.1);
        cam_fwd.lerpv(cam_target_fwd.normalize(), 0.1);

        var lookat = cam_pos.copy().addv(cam_fwd);
        camera = camera_get_active();
        camera_set_view_mat(camera, matrix_build_lookat(cam_pos.x, cam_pos.y, cam_pos.z, lookat.x, lookat.y, lookat.z, 0, 0, 1));
        camera_set_proj_mat(camera, matrix_build_projection_perspective_fov(-60, -WW/WH, 1, 32000));
        camera_apply(camera);

        matrix_set(matrix_world, mtx_mul(
            mtx_scl(30*TILE_SIZE, 30*TILE_SIZE, 1),
            mtx_mov(-15*TILE_SIZE, -15*TILE_SIZE, 0),
        ));
        vertex_submit(global.v_floor_battle, pr_trianglelist, sprite_get_texture(get_floor_tex(), 0));

        for (var i=0; i<array_length(turn_order); i++) {
            var char = turn_order[i];

            var rot = point_direction(0, 0, char.fwd.x, char.fwd.y);
            var pos = char.render_pos();

            matrix_set(matrix_world, mtx_mul(
                mtx_scl(char.size, char.size, char.size),
                mtx_rot(0, 0, rot),
                mtx_mov(pos.x, pos.y, pos.z)
            ));

            shader_set(sh_smf_animate);

            static uni_col = shader_get_uniform(sh_smf_animate, "outlineColor");
            if (outline == i) shader_set_uniform_f_array(uni_col, [255, 0, 0, 255]);
            render_model_simple(char.model, $"battle:{i}", char.texture);
            if (outline == i) shader_set_uniform_f_array(uni_col, [0, 0, 0, 0]);

            shader_reset();
        }

        matrix_set(matrix_world, matrix_build_identity());
    }
}