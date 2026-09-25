// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
var inst = instance_create_depth(x+50,y+50,depth-500,obj_coffeepot_bullet)
global.audio.play(snd_coffee_pot_attack,0,0)
inst.damage = atk
inst.move_speed = 0
inst.shape = 0
inst.row = grid_row
inst.start_col = grid_col