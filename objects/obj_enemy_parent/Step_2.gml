// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
damage_amount = 0
damage_type = ""

if not hp_modified{
	if global.difficulty == 0{
		maxhp *= 0.8
		hp *= 0.8
		helmet_hp *= 0.8
		helmet_max_hp *= 0.8
		shield_hp *= 0.8
		shield_max_hp *= 0.8
	}
	if global.difficulty >= 3{
		if global.map_id != "tower_cake"{
			maxhp *= 1.2
			hp *= 1.2
			helmet_hp *= 1.2
			helmet_max_hp *= 1.2
			shield_hp *= 1.2
			shield_max_hp *= 1.2
		}
		else{
			maxhp *= 1.2
			hp *= 1.2
			helmet_hp *= 1.2
			helmet_max_hp *= 1.2
			shield_hp *= 1.2
			shield_max_hp *= 1.2
		}
	}
	if is_real(global.level_file.version) && !is_boss{
		maxhp *= global.level_file.hp_modify
		hp *= global.level_file.hp_modify
		helmet_hp *= global.level_file.hp_modify
		helmet_max_hp *= global.level_file.hp_modify
		shield_hp *= global.level_file.hp_modify
		shield_max_hp *= global.level_file.hp_modify
	}
	
	hp_modified = true
}
with obj_lava{
	if other.grid_row == row && other.grid_col == col &&
	(other.target_type == "normal" || other.target_type == "dance" || other.target_type == "air" || other.target_type == "obstacle"){
		other.move_speed_modify = 2
		break
	}
	else{
		other.move_speed_modify = 1
	}
}
with obj_mucus{
	if other.grid_row == row && other.grid_col == col &&
	(other.target_type == "normal" || other.target_type == "dance"){
		other.move_speed_modify = 2
		break
	}
	else{
		other.move_speed_modify = 1
	}
}

// 受伤 VM 挂载点：本帧血量下降 → 触发脚本的 _VM_ENEMY_DAMAGED
if (pre_hp > hp && buffer_exists(global._VM_ENEMY_DAMAGED)) {
	global._VM_last_damaged_enemy = id;
	VM_Execute(global.__vm, global._VM_ENEMY_DAMAGED, "_VM_ENEMY_DAMAGED");
}
pre_hp = hp;
