// obj_battle_pause_manager - Step Event
// 安卓适配：暂停中/结算时点击屏幕 = 空格（继续）；返回键 = ESC（GameMaker 安卓返回键映射 vk_escape）
// 安卓：切后台自动暂停（回前台保持暂停菜单，玩家点继续恢复）
if (os_type != os_windows) {
    if (os_is_paused() && !global.is_paused) {
        global.is_paused = true;
        global.show_menu = true;
        if (!instance_exists(obj_pause_menu)) {
            instance_create_depth(room_width / 2, room_height / 2, depth, obj_pause_menu);
        }
    }
}
// 上游 PR#71：PC 结算界面左键 = 继续（安卓走下面 os_type 分支的点击判定）
var _space = keyboard_check_pressed(vk_space) || (mouse_check_button_pressed(mb_left) && global.game_over);
if (os_type != os_windows && (global.is_paused || global.game_over || obj_battle.battle_time == 1)) {
    if (mouse_check_button_pressed(mb_left)) _space = true;
}
if (_space) {	
    //if global.selected_slot == noone {
        if (!global.is_paused) {
            // 空格暂停：只暂停不显示菜单
            global.is_paused = true;
            global.show_menu = false;
        }
        else if (global.is_paused && !global.show_menu) {
            // 取消暂停
			if global.game_over{
				if settlement || obj_game_over.sprite_index == spr_lose || global.level_file.version == "1.0.0"{
					if global.map_id == "tower_cake" || global.map_id == "delicious_town"{
						global.map_id = "delicious_island"
						global.map_name = "美味岛"
					}
					global.gui_stack.pop()
					if (obj_game_over.sprite_index != spr_lose) {
						global.gui_stack.pop()
					}
					global.menu_screen = true
					obj_world_map_button.world_map = 0
				}
				if global.level_file.version != "1.0.0"{
					if obj_game_over.sprite_index == spr_win && !settlement{
						if !global.laboretory_room{
							with obj_task_manager{
								refresh_task_progress()
							}
							if array_get_index(global.save_data.completed_levels,global.level_data.id) == -1{
								complete_level(global.level_data.id)
								first_complete = true
								if array_get_index(slot_unlock_level_id_list,global.level_data.id) != -1{
									if global.save_data.unlocked_items.max_slot < 21{
										global.save_data.unlocked_items.max_slot += 1
										show_notice("你解锁了一个新的卡槽",60)
									}
								}
								if global.level_data.id == "champagne_island_water"{
									global.save_data[$ "unlocked_items"][$ "elite_unlocked"] = true
								}
								if global.level_data.id == "abyss"{
									global.save_data[$ "unlocked_items"][$ "shovel"] = "copper"
								}
								if global.level_data.id == "macchiato_port"{
									global.save_data[$ "unlocked_items"][$ "shovel"] = "silver"
								}
								if global.level_data.id == "snowcap_volcano"{
									global.save_data[$ "unlocked_items"][$ "shovel"] = "gold"
								}
								if global.level_data.id == "tower_cake_35_3"{
									global.save_data[$ "player"][$ "crown_version"] = global.game_version
								}
								if global.level_file.rewards[1].player_level >= global.save_data.player.level{
									global.save_data[$ "player"][$ "level"] = global.level_file.rewards[1].player_level
								}
								if global.level_file.rewards[1].skill_level >= global.save_data.unlocked_items.max_skill_level{
									global.save_data[$ "unlocked_items"][$ "max_skill_level"] = global.level_file.rewards[1].skill_level
									var length = array_length(global.save_data.unlocked_cards)
									for (var i = 0;i < length;i++){		
										global.save_data.unlocked_cards[i].skill = global.save_data.unlocked_items.max_skill_level
									}
								
								}
								global.save_data.player.gold += global.level_file.rewards[1].gold
								var item_list = global.level_file.rewards[1].items
								for(var i = 0 ; i < array_length(item_list) ; i++){
									var item_id = item_list[i].id
									add_material_amount(item_id,real(item_list[i].amount))
								}
						
								var card_unlock_id_list = global.level_file.rewards[1].card_unlock
								for(var i = 0 ; i < array_length(card_unlock_id_list) ; i++){
									var card_id = card_unlock_id_list[i]
									unlock_card(card_id,0,0,global.save_data.unlocked_items.max_skill_level)
								}
						
								var weapon_unlock_id_list = global.level_file.rewards[1].weapon_unlock
								for(var i = 0 ; i < array_length(weapon_unlock_id_list) ; i++){
									var weapon_id = weapon_unlock_id_list[i]
									unlock_weapon(weapon_id)
								}
						
								var gem_unlock_id_list = global.level_file.rewards[1].gem_unlock
								for(var i = 0 ; i < array_length(gem_unlock_id_list) ; i++){
									var gem_id = gem_unlock_id_list[i]
									unlock_gem(gem_id)
								}
								save_file(global.save_slot)
							}
							else{
								global.save_data.player.gold += global.level_file.rewards[0].gold
								var item_list = global.level_file.rewards[0].items
								for(var i = 0 ; i < array_length(item_list) ; i++){
									var item_id = item_list[i].id
									add_material_amount(item_id,item_list[i].amount)
								}
								save_file(global.save_slot)
							}
						}
						settlement = true
						obj_game_over.image_alpha = 0
					}
				}
				
				
			}
			if obj_battle.battle_time != 0 && !global.game_over{
				global.is_paused = false;
			}
        }
    //}
}

if (keyboard_check_pressed(vk_escape)) {
    if (!global.is_paused) {
        // ESC暂停：暂停并显示菜单
        global.is_paused = true;
        global.show_menu = true;
        
        // 创建暂停菜单实例
        
        instance_create_depth(room_width / 2, room_height / 2, depth, obj_pause_menu);
    }
    else if (global.is_paused && global.show_menu) {
        // 尝试关闭菜单（菜单自身会处理ESC关闭）
        var menu = instance_find(obj_pause_menu, 0);
        if (menu != noone && !menu.submenu_open) {
            instance_destroy(menu);
            global.is_paused = false;
            global.show_menu = false;
        }
    }
}

if (keyboard_check_pressed(ord("R"))) {
	if global.game_over{
		if obj_game_over.sprite_index == spr_lose{
			room_transition_start(room)   // 重开本局也走淡出淡入
		}
	}
}

if obj_battle.battle_time == 1{
	global.is_paused = true;
}