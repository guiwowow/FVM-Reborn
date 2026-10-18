// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
if global.is_paused{
	exit
}
timer++
if state == "start"{
	image_index = floor(timer/5) mod 4
	y -= 15
	if y <= -200{
		var target_pos = get_world_position_from_grid(target_col,target_row)
		x = target_pos.x 
		y = target_pos.y - room_height
		state = "drop"
	}
}
if state == "drop"{
	image_index = floor(timer/5) mod 12
	var target_pos = get_world_position_from_grid(target_col,target_row)
	if timer == 4 * 5 + 2{
		with obj_card_parent{
			if abs(grid_col - other.target_col) <= 1 && abs(grid_row - other.target_row) <= 1 &&
			plant_id != "player" && plant_type != "coffee" && !invincible && plant_id != "cotton_candy"  && plant_id != "soda_bubble"{
				frozen_timer = 240
				ice_timer = 600
			}
		}
	}
	if timer >= 12 * 5 - 1{
		instance_destroy()
	}
}