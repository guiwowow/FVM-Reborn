
    if (not audio_is_playing(readyroom_music)) {
        // 停止可能存在的暂停实例
        audio_stop_sound(readyroom_music);
        // 从头开始播放新实例
        global.audio.play(readyroom_music, 0, 0);
    }
// 安卓适配：不加右键返回（安卓双击会被引擎合成为 mb_right，选卡界面双击查看卡片会误退）；返回键映射 vk_escape
if keyboard_check_pressed(vk_escape){
	if instance_exists(obj_quit_confirm){
		instance_destroy(obj_quit_confirm)
	}
	else{
		if !is_submenu_open{
			instance_create_depth(room_width / 2,room_height / 2,-100,obj_quit_confirm)
		}
	}
}

if instance_exists(obj_quit_confirm) || instance_exists(obj_level_preview){
	is_submenu_open = true
}
else{
	is_submenu_open = false
}

// 安卓：双指滑动替代滚轮（选卡列表 y_offset，与 Mouse_60/61 滚轮逻辑一致）
// B6 重构：公共部分收敛到 scripts/two_finger_scroll；本界面差异 = 步长 20px、y_offset 步进 40px
if (os_type != os_windows && !is_submenu_open) {
    two_finger_scroll(20, function(_finger_down) {
        if (_finger_down) {
            // 滚轮向下（Mouse_61 逻辑）
            if y_offset <= 96*slot_rows - 40 - 515 { y_offset += 40 } else { y_offset = 96*slot_rows - 515 }
        } else {
            // 滚轮向上（Mouse_60 逻辑）
            if y_offset > 40 { y_offset -= 40 } else { y_offset = 0 }
        }
    });
}

