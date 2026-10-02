if !obj_readyroom_manager.is_submenu_open{
	audio_play_sound(snd_button,0,0)
	clear_deck()
	obj_readyroom_manager.deck_first_slot_index = 0   // 清空后回到第一页
}