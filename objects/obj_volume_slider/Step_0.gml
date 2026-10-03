// 处理滑块拖动
if (dragging) {
    current_x = clamp(mouse_x, min_x, max_x);
    update_volume();
	x = current_x
}

// 检查鼠标释放
if (dragging && !mouse_check_button(mb_left)) {
    dragging = false;
    save_volume();
}

// 星星位置：入场动画期间从最左端（0）非线性涨到记忆的位置；平时按真实音量定位
if (!dragging) {
	if (global.vol_intro_p >= 0) {
	    var _tgt = (volume_type == "music") ? global.music_volume : global.sound_volume;
	    var _ip  = global.vol_intro_p;
	    var _e   = 1 - (1 - _ip) * (1 - _ip) * (1 - _ip);   // ease-out：起步快、收尾慢
	    x = min_x + (_tgt * _e) * (max_x - min_x);
	} else if (volume_type == "music") {
	    x = min_x + global.music_volume * (max_x - min_x)
	} else if (volume_type == "sound") {
	    x = min_x + global.sound_volume * (max_x - min_x)
	}
}

// 星星滚动：位置每变一点就转一点（拖动和入场动画都算），单帧限幅免得转糊
// 方向：向右拖动时逆时针转（手感上像星星在条上"滚"，与直觉一致）
var _dx = x - star_prev_x;
if (abs(_dx) > 0.01) spin_angle -= clamp(_dx * 2.5, -15, 15);
star_prev_x = x;
image_angle = spin_angle;
