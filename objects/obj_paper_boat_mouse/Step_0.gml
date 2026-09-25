// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
// Inherit the parent event
if hp <= 0 && state != ENEMY_STATE.DEAD{
	timer = 0
	state = ENEMY_STATE.DEAD
	if (grid_col < 0 || grid_col >= global.grid_cols || grid_row < 0 || grid_row >= global.grid_rows){
		sprite_index = spr_paper_boat_mouse_land
		death_anim = 12
	}
	else{
		if global.grid_terrains[grid_row][grid_col].type == "water"{
			sprite_index = spr_paper_boat_mouse
			death_anim = 10
		}
		else{
			sprite_index = spr_paper_boat_mouse_land
			death_anim = 12
		}
	}
		
}
if (grid_col < 0 || grid_col >= global.grid_cols || grid_row < 0 || grid_row >= global.grid_rows) {
	sprite_index = spr_paper_boat_mouse_land
	death_anim = 12
}
else{
	if state != ENEMY_STATE.DEAD{
		if global.grid_terrains[grid_row][grid_col].type == "water"{
			if sprite_index == spr_paper_boat_mouse_land{
				state = ENEMY_STATE.ACTING
				sprite_index = spr_paper_boat_mouse_enter
				timer = 0
				global.audio.play(snd_enter_water,0,0)
				reversed = false
			}
		
			death_anim = 10
		}
		else{
			if sprite_index == spr_paper_boat_mouse{
				state = ENEMY_STATE.ACTING
				sprite_index = spr_paper_boat_mouse_enter
				timer = 0
				global.audio.play(snd_enter_water,0,0)
				reversed = true
			}
		
			death_anim = 12
		}
	}
}

event_inherited();
if global.is_paused or is_frozen{
	exit
}
if state == ENEMY_STATE.ACTING{
	x -= move_speed
	if hp > maxhp * hurt_rate{
		if reversed{
			image_index = 8 - (floor(timer/flash_speed) mod 8)
		}
		else{
			image_index = floor(timer/flash_speed) mod 8
		}
	}
	else{
		if reversed{
			image_index = 8 - (floor(timer/flash_speed) mod 8) + 7
		}
		else{
			image_index = (floor(timer/flash_speed) mod 8) + 7
		}
	}
	if timer >= flash_speed * 8 or hp <= 0{
		state = ENEMY_STATE.NORMAL
		if reversed{
			sprite_index = spr_paper_boat_mouse_land
		}
		else{
			sprite_index = spr_paper_boat_mouse
		}
	}
}