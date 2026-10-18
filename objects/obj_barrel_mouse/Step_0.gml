// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
// Inherit the parent event
if global.is_paused{
	exit
}
if hp <= 0 && state != ENEMY_STATE.DEAD{
	state = ENEMY_STATE.DEAD
	sprite_index = spr_barrel_mouse
	timer = 0
	target_plant = noone
}

event_inherited();

if act_cooldown > 0{
	act_cooldown --
}

if hp > 0 && state != ENEMY_STATE.DEAD{
	if state = ENEMY_STATE.ACTING{
		anim_timer ++
		if anim_timer <= 10 * 5 - 1{
			if hp > maxhp * hurt_rate{
				image_index = floor(anim_timer/5) mod 10
			}
			else{
				image_index = floor(anim_timer/5) mod 10 + 24
			}
		}
		else{
			if hp > maxhp * hurt_rate{
				image_index = floor((anim_timer-50)/5) mod 14 + 10
			}
			else{
				image_index = floor((anim_timer-50)/5) mod 14 + 34
			}
		}
		if anim_timer >= 350{
			anim_timer = 0
			state = ENEMY_STATE.DIG
			sprite_index = spr_barrel_mouse_return
		}
	}
	if state = ENEMY_STATE.DIG{
		anim_timer ++
		if hp > maxhp * hurt_rate{
			image_index = floor(anim_timer/5) mod 10
		}
		else{
			image_index = floor(anim_timer/5) mod 10 + 10
		}
		
		if anim_timer >= 10 * 5 - 1{
			anim_timer = 0
			state = ENEMY_STATE.NORMAL
			sprite_index = spr_barrel_mouse
			act_cooldown = 300
		}
	}
}