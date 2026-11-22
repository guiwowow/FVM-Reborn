// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
/// 煮蛋投手子弹 Step：通用帧循环 + 目标中途死亡时落地
event_inherited();
if (global.is_paused) exit;

if (target_enemy != noone && (!instance_exists(target_enemy) || target_enemy.hp <= 0)) {
	if (y >= thrower_y) {
		instance_create_depth(x, y, depth, obj_eggboilerpult_bullet_effect);
		instance_destroy();
	}
}