// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
/// 烤蜥蜴投手子弹 Step：通用帧循环 + 落地炸开
event_inherited();
if (global.is_paused) exit;

if (y >= thrower_y) {
	bullet_create_effect(obj_coke_bomb_explode, spr_roast_lizard_pult_bullet_effect);
	instance_destroy();
}