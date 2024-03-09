/// @type {Id.DsMap<Struct.smf_model|real>}
global.loaded_models = ds_map_create();
/// @type {Array<Struct.smf_model>}
global.loaded_models_arr = [];

/// @param {string} name
/// @returns {Struct.smf_model|undefined}
function get_model(name) {
    /// @type {Struct.smf_model|real}
    var mmod = ds_map_find_value(global.loaded_models, name);

    if (is_undefined(mmod)) {
        var path = name + ".smf";
        var buf = buffer_create(1, buffer_grow, 1);
        var async_id = buffer_load_async(buf, path, 0, -1);
        global.loaded_models[? path] = async_id;

        on_async(async_id, new Callback(function(buf, name){
            var model = smf_model_load_from_buffer(buf);
            global.loaded_models[? name] = model;
            array_push(global.loaded_models_arr, model);
            // var anim_inst = smf_instance_create(model);
            // var lm = new Loaded_Model(model, anim_inst);
        }, [buf, name], undefined));

    } else if (is_struct(mmod)) {
        return mmod;
    }
}

/// @type {Id.DsMap<Struct.smf_instance>}
global.loaded_anim_inst = ds_map_create();
/// @type {Array<Struct.smf_instance>}
global.loaded_anim_inst_arr = [];

/// @param {string} model_name
/// @param {string} inst_name
function get_anim_inst(model_name, inst_name) {
    var key = model_name + ":" + inst_name;
    var _inst = ds_map_find_value(global.loaded_anim_inst, key);

    if (is_undefined(_inst)) {
        var _mod = get_model(model_name);
        if (is_undefined(_mod)) return undefined;
        _inst = smf_instance_create(_mod);
        global.loaded_anim_inst[?key] = _inst;
        array_push(global.loaded_anim_inst_arr, _inst);
    }

    return _inst;
}

/// @param {Struct.smf_instance} inst
/// @param {Asset.GMSprite} tex
function render_model(inst, tex) {
    /// @type {Struct.smf_model}
    var model = inst.model;
    if (!is_array(model.texPack) || model.texPack[0] != tex) {
        model.texPack = [tex];
    }
    inst.draw();
}

/// @param {string} model_name
/// @param {string} inst_name
/// @param {Asset.GMSprite} tex
function render_model_simple(model_name, inst_name, tex) {
    var inst = get_anim_inst(model_name, inst_name);
    if (!is_undefined(inst)) {
        render_model(inst, tex);
    }
}

function update_animations() {
    for (var i=0; i<array_length(global.loaded_anim_inst_arr); i++) {
        global.loaded_anim_inst_arr[i].step(1);
    }
}
