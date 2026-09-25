// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;



var inst = instance_create_depth(x+40,y+70,depth-500,obj_waterpipe_bullet)
inst.damage = atk
inst.move_speed = 8
inst.row = grid_row

var inst3 = instance_create_depth(x-80,y+60,depth-500,obj_waterpipe_bullet)
inst3.damage = atk
inst3.move_speed = -8
inst3.row = grid_row
inst3.image_angle = 180

var inst2 = instance_create_depth(x-40,y+60,depth-500,obj_waterpipe_bullet)
inst2.damage = atk
inst2.move_speed = -8
inst2.row = grid_row
inst2.image_angle = 180

global.audio.play(snd_shot, 0, 0);