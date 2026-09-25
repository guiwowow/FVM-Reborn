// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;

if global.is_paused{
	exit
}
timer++
if timer < 24*5{
	image_index = floor(timer/5)
}
else{
	image_index = 19
	image_alpha -= 0.1
	if image_alpha <=0{
		instance_destroy()
	}
}
if timer == 14*5{
	var inst = instance_create_depth(x-50,y-75,-500,obj_freeze_gem_effect)
	//global.audio.play(snd_mouse_frozen,0,0)
	inst.row = row
}