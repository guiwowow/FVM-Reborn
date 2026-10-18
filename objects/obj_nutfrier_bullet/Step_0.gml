// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
if global.is_paused{
	image_speed = 0
	exit	
}
image_speed = 1
if burnt == 1{
	sprite_index = spr_fire_bullet
}
x += move_speed
y += y_move_speed
if x > 2200 or y > 1200 or x < 0 or y < -200{
	instance_destroy()
}