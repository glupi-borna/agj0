button_prompts_step();
drain_exec_queue();
update_game_state();

if (keyboard_check_pressed(vk_f12)) {
    global.dd = !global.dd;
    show_debug_overlay(global.dd);
}