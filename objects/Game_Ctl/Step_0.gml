button_prompts_step();
drain_exec_queue();
update_game_state();
update_sfx();
update_bgm();

if (keyboard_check_pressed(vk_f12)) {
    global.dd = !global.dd;
    show_debug_overlay(global.dd);
}