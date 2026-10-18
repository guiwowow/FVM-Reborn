// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
if global.is_paused{
	exit
}
timer++
if timer < 35*5{
	image_index = floor(timer/5)
}
else{
	image_alpha = 0
}
with obj_card_parent{
	if hp < max_hp{
		hp = max_hp
		instance_create_depth(x,y+30,depth-4,obj_card_heal_effect)
	}
}
if timer >= max_time{
	instance_destroy()
}