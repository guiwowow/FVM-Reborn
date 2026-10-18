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
	image_index = floor(timer/5) mod 4
	var target_pos = get_world_position_from_grid(target_col,target_row)
	y += 15
	if y >= target_pos.y{
		with obj_card_parent{
			if abs(grid_col - other.target_col) <= 1 && abs(grid_row - other.target_row) <= 1 &&
			plant_id != "player" && plant_type != "coffee" && !invincible && plant_id != "cotton_candy"  && plant_id != "soda_bubble"{
				if hp >= max_hp{
					obj_task_manager.card_loss++
				}
				instance_destroy()
			}
		}
		var inst = instance_create_depth(x,y-30,-800,obj_coke_bomb_explode)
		inst.sprite_index = spr_mermaid_mary_bullet_effect
		instance_destroy()
	}
}