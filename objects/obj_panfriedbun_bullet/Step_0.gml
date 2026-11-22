// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
/// 生煎包投手子弹 Step：通用帧循环 + 落地留溅射源
event_inherited();
if (global.is_paused) exit;

if (y >= thrower_y) {
	var _gp = get_grid_position_from_world(x, y);
	bullet_pan_splash(_gp.x, _gp.y, _gp.row);
	instance_destroy();
}