//step事件
if global.is_paused{
	exit
}

// 点选防误触锁递减
if (select_lock_frames > 0) {
	select_lock_frames--;
}
// 选卡后短窗口递减（快速第二下点按不触发同卡取消）
if (select_recent_frames > 0) {
	select_recent_frames--;
}

if card_id != "magic_chicken"{
	current_cost = cost
	if ds_map_find_value(global.plus_card_map,card_id) != undefined{
		var plus_info = ds_map_find_value(global.plus_card_map,card_id)
		with plus_info[0]{
			if shape < plus_info[1]{
				other.current_cost += 50
			}
		}
	}
}
if global.debug{
	cooldown_timer = cooldown
}
if cooldown_timer < cooldown{
	// 选卡缓时：冷却也 12 倍慢（与战斗节奏一致）
	if (!(global.slowmo_active && global.game_frame != 0)) {
		cooldown_timer ++
	}


    // 冷却中状态
    is_ready = false;
    cooling_alpha = min(cooling_alpha + 0.05, 0.7); // 淡入冷却效果
} else {
    // 冷却完成状态
    cooling_alpha = max(cooling_alpha - 0.05, 0); // 淡出冷却效果
    
    // 检查阳光是否足够
    if (global.flame >= current_cost) {
        is_ready = true;
    } else {
        is_ready = false;
    }
}

// 检测鼠标悬停（用于显示提示）
var mx = device_mouse_x_to_gui(0);
var my = device_mouse_y_to_gui(0);
var is_hovered = point_in_rectangle(mx, my, x-42, y-55, x+42, y+50);

// 控制悬停提示透明度
if (is_hovered) {
    hover_alpha = min(hover_alpha + 0.1, 1);
} else {
    hover_alpha = 0
}

// 检测鼠标点击（选中卡槽）；双指手势中屏蔽，防误触
if (is_ready && mouse_check_button_pressed(mb_left) && !two_finger_gesture_active()) {
    mx = mouse_x;
    my = mouse_y;
    
    if (point_in_rectangle(mx, my, x-50, y-70, x+50, y+70)) {
		// 体验优化：点击放置时，再点一次同一张卡 = 取消选中
		// 防误判：刚选中几帧内的第二次点按（快速选卡后秒点地格，第二下坐标可能仍滞后在卡上）不取消，
		// 让玩家可以立即继续点地格放置；稍后再点同卡仍可正常取消
		if (is_selected) {
			if (select_recent_frames <= 0) {
				if (global.debug) { show_debug_message("卡槽取消: 同卡点击 窗口=" + string(select_recent_frames)); }
				is_selected = false;
				_drag_left_slot = false;
				if (selected_preview != noone && instance_exists(selected_preview)) {
					instance_destroy(selected_preview);
				}
				selected_preview = noone;
				global.selected_slot = noone;
			}
		}
		else{
			select_slot()
			select_recent_frames = 10;
			_drag_left_slot = false;
			// 选择即放置（无误差间隔：点卡片后立刻点地格即可放置；同帧按下由位置检测兜底）
			select_lock_frames = 0;

			// 创建放置预览对象
			if (selected_preview == noone) {
				selected_preview = instance_create_depth(mouse_x, mouse_y, depth-2, obj_card_preview);
				selected_preview.preview_sprite = card_spr; // 设置预览精灵
				if place_preview != undefined{
					selected_preview.preview_sprite = place_preview
				}
				selected_preview.parent_slot = id; // 设置父卡槽
				selected_preview.card_id = card_id
				// VM Hook：预览卡被选中（地图脚本据此自定义放置行为）
				if (buffer_exists(global._VM_CARD_PREVIEW_PICKED))
					VM_Execute(global.__vm, global._VM_CARD_PREVIEW_PICKED, "_VM_CARD_PREVIEW_PICKED");
			}
		}
    }
}

var slot_key = global.keybind_map[? "卡槽" + string(slot_index)];

if keyboard_check_pressed(slot_key) && is_ready{
        // 选中当前卡槽
		if !is_selected{
			select_slot()
        
			if global.quick_placement{
				try_place_once()
			}
			else{
	        // 创建放置预览对象
		        if (selected_preview == noone) {
		            selected_preview = instance_create_depth(mouse_x, mouse_y, depth-2, obj_card_preview);
		            selected_preview.preview_sprite = card_spr; // 设置预览精灵
					if place_preview != undefined{
						selected_preview.preview_sprite = place_preview
					}
		            selected_preview.parent_slot = id; // 设置父卡槽
					selected_preview.card_id = card_id
					// VM Hook：预览卡被选中（地图脚本据此自定义放置行为）
					if (buffer_exists(global._VM_CARD_PREVIEW_PICKED))
						VM_Execute(global.__vm, global._VM_CARD_PREVIEW_PICKED, "_VM_CARD_PREVIEW_PICKED");
		        }
			}
		}
		else{
			is_selected = false;
	        if (selected_preview != noone && instance_exists(selected_preview)) {
	            instance_destroy(selected_preview);
	        }
	        selected_preview = noone;
	        global.selected_slot = noone;
		}
    }

// 如果当前卡槽被选中，处理放置逻辑
if (is_selected) {
    // 更新预览位置
    if (selected_preview != noone && instance_exists(selected_preview)) {
        selected_preview.x = mouse_x;
        selected_preview.y = mouse_y;
    }

    // 体验优化：拖动放置时，若卡片拖出卡槽后拖回任意卡槽位置 = 取消选中
    var _on_any_slot = false;
    with (obj_card_slot) {
        if (point_in_rectangle(mouse_x, mouse_y, x-50, y-70, x+50, y+70)) {
            _on_any_slot = true;
            break;
        }
    }
    if (!_on_any_slot) {
        // 鼠标已离开所有卡槽，标记已拖出
        _drag_left_slot = true;
    } else if (_drag_left_slot) {
        // 拖出后又回到任意卡槽区域：取消选中
        if (global.debug) { show_debug_message("卡槽取消: 拖回卡槽"); }
        _drag_left_slot = false;
        is_selected = false;
        if (selected_preview != noone && instance_exists(selected_preview)) {
            instance_destroy(selected_preview);
        }
        selected_preview = noone;
        global.selected_slot = noone;
    }
    
    // 取消选择：仅 ESC（安卓长按/双击会被引擎合成为 mb_right → 右键取消在移动端禁用；
    // PC 右键分支已按 mobile-only 移除）
    if (keyboard_check_pressed(vk_escape)) {
        if (global.debug) { show_debug_message("卡槽取消: 右键/ESC"); }
        is_selected = false;
        if (selected_preview != noone && instance_exists(selected_preview)) {
            instance_destroy(selected_preview);
        }
        selected_preview = noone;
        global.selected_slot = noone;
    }
    
    // 放置：松手放置（点击地格后松手 / 拖动到地格松手）；按下不立即放，可按住微调位置
    var _dist = point_distance(mouse_x, mouse_y, _prev_mx, _prev_my);
    _prev_mx = mouse_x;
    _prev_my = mouse_y;
    var _release_left = mouse_check_button_released(mb_left);
        // 安卓快速双击会把第二次点按模拟成 mb_right（左键按下+松手都被引擎吞掉）：
        // 这里把右键松手也当作放置触发（右键按下仍不取消——长按卡片取消保持禁用）
        var _release_emu = (os_type != os_windows && mouse_check_button_released(mb_right));
        if (_release_left || _release_emu) {
        // 检查是否在可种植区域
		
        var card_shape = get_card_info_simple(card_id).shape
		var card_data = deck_get_card_data(card_id,card_shape)
		
		if card_id == "magic_chicken"{
			if global.prev_place_id != ""{
				card_shape = get_card_info_simple(global.prev_place_id).shape
				card_data = deck_get_card_data(global.prev_place_id,card_shape)
			}
		}
        
        var found_plat = noone;
        var platform_shift_x = 0;
        var platform_shift_y = 0;
        var logical_col = -1;
        var logical_row = -1;
        var grid_pos_visual = get_grid_position_from_world(mouse_x, mouse_y);
        var direct_in_platform = false;

        with (obj_platform) {
            var is_axis_x = (variable_instance_exists(id, "move_axis") && move_axis == "x");
            var shift_x = is_axis_x ? visual_x_shift : 0;
            var shift_y = (!is_axis_x) ? visual_y_shift : 0;
            var adj_x = mouse_x - shift_x;
            var adj_y = mouse_y - shift_y;
            var grid_pos_adj = get_grid_position_from_world(adj_x, adj_y);

            var c_off = is_axis_x ? current_offset : 0;
            var r_off = (!is_axis_x) ? current_offset : 0;
            var p_start_c = start_col + c_off;
            var p_start_r = start_row + r_off;

            if (grid_pos_adj.col >= p_start_c && grid_pos_adj.col < p_start_c + width &&
                grid_pos_adj.row >= p_start_r && grid_pos_adj.row < p_start_r + length) {
                found_plat = id;
                logical_col = grid_pos_adj.col;
                logical_row = grid_pos_adj.row;
                platform_shift_x = shift_x;
                platform_shift_y = shift_y;
                break;
            }

            // 记录鼠标视觉格子是否落在某平台逻辑范围内（用于检测移动方向外一格）
            if (!direct_in_platform &&
                grid_pos_visual.col >= p_start_c && grid_pos_visual.col < p_start_c + width &&
                grid_pos_visual.row >= p_start_r && grid_pos_visual.row < p_start_r + length) {
                direct_in_platform = true;
            }
        }

        if (found_plat == noone) {
            if (direct_in_platform) {
                // 鼠标视觉在平台外但格子属于平台逻辑范围（平台移动方向外一格），禁止放置
                logical_col = -1;
                logical_row = -1;
            } else {
                logical_col = grid_pos_visual.col;
                logical_row = grid_pos_visual.row;
            }
        }
// 触控宽容：逻辑网格原点(约228)比校准贴图网格(约192)下沉约36px，玩家按可见棋盘顶行点按
        // 松手会落在 row=-1 → 放置失败，必须再点一次。若落点不在平台/非禁止位、逻辑行=-1、
        // 且落在校准网格第0行的可见范围内，则吸附到第0行（只赦免"可见顶行"，点卡片 row=-2 不受影响）
        if (found_plat == noone && !direct_in_platform && logical_row == -1 && logical_col >= 0 && logical_col < global.grid_cols) {
            var _pg_forgive = get_painted_grid(global.level_data.level_sprite, 0);
            if (_pg_forgive != undefined && mouse_y >= _pg_forgive.oy && mouse_y < _pg_forgive.oy + _pg_forgive.ch) {
                logical_row = 0;
            }
        }
        
        var logical_world = get_world_position_from_grid(logical_col, logical_row);

        var can_plant = (can_place_at_position(logical_world.x, logical_world.y, card_data[? "plant_type"],card_data[? "feature_type"],card_data[? "target_card"]));
        
        if (can_plant && global.flame >= current_cost) {
            // 创建植物实例
			var plant_list = ds_grid_get(global.grid_plants, logical_col, logical_row);
			var target_card_id = card_data[? "target_card"];
			
			// 如果有target_card，替换底座卡片
			if card_data[? "feature_type"] == "upgrade"{
				if (target_card_id != undefined && target_card_id != "none") {
					// 销毁目标卡片
					for (var i = 0; i < ds_list_size(plant_list); i++) {
						var plant = ds_list_find_value(plant_list, i);
						if (instance_exists(plant) && variable_instance_exists(plant, "plant_id") && plant.plant_id == target_card_id) {
							card_destroyed(plant);
							instance_destroy(plant);
							break;
						}
					}
				}
			}
			// 通用替换逻辑（替换同类植物或开启替换模式）
			if global.replace_placement{
				for (var i = 0; i < ds_list_size(plant_list); i++) {
					var plant = ds_list_find_value(plant_list, i);
					if (instance_exists(plant) && plant.plant_type == card_data[? "plant_type"] && plant.plant_id != "player" && plant.plant_type != "coffee"
					&& !((card_data[? "feature_type"]=="bun" && plant.feature_type == "king_bun")||(card_data[? "feature_type"]=="king_bun" && plant.feature_type == "king_bun"))
					&& !((card_data[? "feature_type"]=="tbun" && plant.feature_type == "king_tbun")||(card_data[? "feature_type"]=="king_tbun" && plant.feature_type == "king_tbun"))) {
						card_destroyed(plant);
						instance_destroy(plant);
					}
				}
			}
            var new_plant = instance_create_depth(logical_world.x + platform_shift_x, logical_world.y + platform_shift_y, 0,card_obj);
			// 计算深度值
			var depth_value = calculate_plant_depth(logical_col, logical_row, new_plant.plant_type);
			card_created(new_plant, logical_col, logical_row);
			new_plant.depth = depth_value
			// 平台移动期间放置时锁定逻辑网格位置，防止视觉位置覆盖grid_col/grid_row
			if (found_plat != noone && variable_instance_exists(found_plat, "state") && found_plat.state == "moving") {
				new_plant.platform_grid_lock = true;
			}
			if global.grid_terrains[logical_row][logical_col].type == "normal"{
				instance_create_depth(logical_world.x + platform_shift_x, logical_world.y + platform_shift_y,-2,obj_place_effect)
			}
			else if global.grid_terrains[logical_row][logical_col].type == "water"{
				var inst = instance_create_depth(logical_world.x + platform_shift_x, logical_world.y + platform_shift_y + 20,-2500,obj_place_effect)
				inst.sprite_index = spr_enter_water_effect
			}
            
            // 扣除阳光
            global.flame -= current_cost;
			
            
            // 重置冷却计时器
            cooldown_timer = 0;
            is_ready = false;
			if array_get_index(cooldown_ignore_list,card_id) == -1{
				global.prev_place_id = card_id
			}
            
			if global.grid_terrains[logical_row][logical_col].type == "normal"{
				global.audio.play(snd_place1,0,0)
			}
			else if global.grid_terrains[logical_row][logical_col].type == "water"{
				global.audio.play(snd_enter_water,0,0)
			}
            // 取消选择
            is_selected = false;
            if (selected_preview != noone && instance_exists(selected_preview)) {
                instance_destroy(selected_preview);
            }
            selected_preview = noone;
            global.selected_slot = noone;
        }
        if (global.debug) {
            var _release_btn = _release_left ? "左" : "右(双击模拟)";
            if (is_selected) { show_debug_message("放置结果: FAIL(卡片保留) btn=" + _release_btn + " room(" + string(mouse_x) + "," + string(mouse_y) + ") cell(" + string(logical_col) + "," + string(logical_row) + ")"); }
            else { show_debug_message("放置结果: OK(卡片已放→消失正常) btn=" + _release_btn + " room(" + string(mouse_x) + "," + string(mouse_y) + ") cell(" + string(logical_col) + "," + string(logical_row) + ")"); }
        }
    }
}

depth = -1 * slot_index - 1000
if info_got == false{
	event_user(0)
}