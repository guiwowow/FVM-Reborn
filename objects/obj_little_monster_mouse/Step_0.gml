// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
// Inherit the parent event

if state == ENEMY_STATE.ATTACK{
	target_type = "normal"
}
else{
	target_type = "dance"
}
if hp <= 0 && state != ENEMY_STATE.DEAD{
	state = ENEMY_STATE.DEAD
	timer = 0
	sprite_index = spr_little_monster_mouse
}
event_inherited();



if global.is_paused || is_frozen || is_stun{
	exit
}

if dance_cooldown > 0{
	dance_cooldown --
}

if state == ENEMY_STATE.ACTING{
	if sprite_index == spr_little_monster_mouse_dance_1{
		if hp > maxhp * hurt_rate{
			image_index = floor(timer/flash_speed) mod 23
		}
		else{
			image_index = floor(timer/flash_speed) mod 23 + 23
		}
	}
	else{
		if hp > maxhp * hurt_rate{
			image_index = floor(timer/flash_speed) mod 12
		}
		else{
			image_index = floor(timer/flash_speed) mod 12 + 12
		}
	}
	if timer >= 23*flash_speed - 1 || hp<=0{
		timer = 0
		sprite_index = spr_little_monster_mouse
		state = ENEMY_STATE.NORMAL
		dance_cooldown = 120
		if is_slowdown{
			dance_cooldown = 240
		}
	}
}