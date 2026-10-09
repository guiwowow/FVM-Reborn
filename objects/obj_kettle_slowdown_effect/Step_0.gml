if global.is_paused{
	image_speed = 0
	exit
}
// 缓时门控（2026-09-19 补 §21 遗留缺口）
if (slowmo_gate()) exit;
// 动画速度交给 slowmo_gate 统一管理（缓时下它会缩到 SLOWMO_ANIM_SCALE 并保存原值）。
// ⚠️ 这里**不能**再无条件写 image_speed = 1 —— 那会覆盖门控设的缩放，缓时下动画仍全速。
if global.slowmo_active{
	image_speed = SLOWMO_ANIM_SCALE
}
else{
	image_speed = 1
}

var _x = x;
var _y = y;
var _range = 320
var _row_range = 2

timer ++

if timer mod 30 == 5{
	with (obj_enemy_parent) {
		if (abs(x - other.x) < _range && abs(grid_row-other.grid_row) <= _row_range){
			if ice_timer < 600{
				ice_timer = 600
			}
		}
	}
}