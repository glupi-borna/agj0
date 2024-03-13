/// @type {Asset.GMSound}
global.current_bgm = undefined;

/// @param {Asset.GMSound} track
function set_bgm(track) {
    if (global.options.audio_mute) {
        global.current_bgm = undefined;
        audio_stop_all();
        return;
    }

    if (!is_undefined(track) && global.current_bgm == track) {
        return;
    }

    if (!is_undefined(global.current_bgm)) {
        audio_sound_gain(global.current_bgm, 0, 500);
        after(500, audio_stop_sound, [global.current_bgm]);
    }

    global.current_bgm = track;
    if (!is_undefined(track)) {
        audio_play_sound(global.current_bgm, 1, true);
        audio_sound_gain(global.current_bgm, 0, 0);
        audio_sound_gain(global.current_bgm, 0.25, 500);
    }
}

function update_bgm() {
	if (is_instanceof(global.game_state, GS_Battle)) set_bgm(mus_s1);
	else if (!is_undefined(get_dungeon_gs())) set_bgm(mus_s2);
	else set_bgm(undefined);
}

/// @type {Array<Id.AudioEmitter>}
global.emitter_pool = [];
global.num_emitters = 0;

function get_sfx_emitter() {
    if (array_length(global.emitter_pool) > 0) {
        /// @type {Id.AudioEmitter}
        var emitter = array_pop(global.emitter_pool);
        return emitter;
    }
    var emitter = audio_emitter_create();
    audio_emitter_bus(emitter, global.dungeon_bus);
    print($"Created {++global.num_emitters} total emitters");
    return emitter;
}

/// @param {Id.AudioEmitter} emitter
function free_sfx_emitter(emitter) {
    array_push(global.emitter_pool, emitter);
}

/// @param {Asset.GMSound} sfx
/// @param {Struct.v3} pos
function play_sfx(sfx, pos) {
    var emitter = get_sfx_emitter();

    audio_emitter_position(emitter, pos.x, pos.y, pos.z);
    audio_play_sound_on(emitter, sfx, false, 2);

    var duration = audio_sound_length(sfx)*1000 + 1000;
    after(duration, function(emitter){ free_sfx_emitter(emitter); }, [emitter]);
}

function update_sfx() {
    var dgs = get_dungeon_gs();
    /// @type {Struct.GS_Battle}
    var bgs = is_instanceof(global.game_state, GS_Battle) ? global.game_state : undefined;
    if (!is_undefined(bgs)) {
        audio_listener_position(bgs.cam_pos.x, bgs.cam_pos.y, bgs.cam_pos.z);
        audio_listener_orientation(bgs.cam_fwd.x, bgs.cam_fwd.y, bgs.cam_fwd.z, 0, 0, -1);
    } else if (!is_undefined(dgs)) {
        audio_listener_position(dgs.cam_pos.x, dgs.cam_pos.y, dgs.cam_pos.z);
        audio_listener_orientation(dgs.cam_fwd.x, dgs.cam_fwd.y, dgs.cam_fwd.z, 0, 0, -1);
    } else {
        audio_listener_position(0, 0, 0);
        audio_listener_orientation(0, 0, 1, 0, -1, 0);
    }
}

global.dungeon_bus = audio_bus_create();
global.dungeon_bus.effects[0] = audio_effect_create(AudioEffectType.Reverb1, {size: 1, damp: 0.5, mix: 0.5});