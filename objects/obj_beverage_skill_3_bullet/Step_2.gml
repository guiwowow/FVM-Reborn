// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
// Inherit the parent event
event_inherited();

frozen_timer = 0
stun_timer = 0
scare_timer = 0
y_move = 0