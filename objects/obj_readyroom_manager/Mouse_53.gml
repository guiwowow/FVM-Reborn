// 修复：安卓触摸→鼠标映射对一次物理点按可能重复触发本事件（本项目 4/7/53/54 事件编号都被当点击绑定），
// 同一手势 150ms 内只处理一次，防止同一张卡被 add 两次（两个槽位同卡）或同一槽被 delete 两次。
if (current_time - last_card_click_time < 150) {
	exit
}
last_card_click_time = current_time

if hover_card_index != -1 && !is_submenu_open{
	// VM 卡槽上限：地图脚本用 VM_SetMaxSlots() 指定本局卡槽数，可以比存档解锁数更低。
	// 无脚本时 _VM_max_slots = -1 → _max_slot 就是存档解锁数，行为不变。
	var _max_slot = global.save_data.unlocked_items.max_slot;
	if (global._VM_max_slots >= 0 && global._VM_max_slots < _max_slot) {
		_max_slot = global._VM_max_slots;
	}
	if deck_slot_count() < _max_slot && deck_slot_first_empty() != -1{
		var card_id = global.player_deck[| hover_card_index*2];
		// VM 禁卡：地图脚本用 VM_BanCard() 禁掉的卡不允许进卡组，并给出提示。
		// global.banned_cards_online 在 scr_command_VM 顶层创建，无脚本时恒为空 map。
		if !is_undefined(global.banned_cards_online[? card_id]){
			show_notice("该关卡暂不支持此卡片使用", 60)
			return;
		}
		// 去重：卡已在卡组内则忽略（Draw_0 已选中卡片会置灰，但同一帧内的重复事件在置灰前还会再 add）
		var _dup = false
		for (var i = 0; i < ds_list_size(global.selected_deck); i++) {
			if global.selected_deck[| i][? "card_id"] == card_id {
				_dup = true
				break
			}
		}
		if (!_dup) {
			global.audio.play(snd_button,0,0)
			add_to_deck(card_id,get_card_info_simple(card_id).shape)
		}
	}
}
if hover_slot_index != -1 && !is_submenu_open{
	if !deck_slot_is_empty(hover_slot_index){
		global.audio.play(snd_button,0,0)
		remove_from_deck(hover_slot_index)
	}
}
if(mouse_x > 785 && mouse_x < 1546 && mouse_y > 762 && mouse_y < 980) && !is_submenu_open{
	global.audio.play(snd_button,0,0)
	var inst = instance_create_depth(0,0,-500,obj_level_preview)
	inst.enemy_type_list = enemy_type_list
	inst.boss_type_list = boss_type_list
}