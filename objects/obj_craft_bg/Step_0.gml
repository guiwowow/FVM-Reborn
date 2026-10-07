if close_timer > 0{
	close_timer --
}
if close_timer == 0{
	instance_destroy()
}

// 安卓：双指滑动替代滚轮（合成屋卡片列表，与选卡界面一致）
// B6 重构：公共部分收敛到 scripts/two_finger_scroll；本界面差异 = 步长 20px、y_offset 步进 40px
if (os_type != os_windows) {
    two_finger_scroll(20, function(_finger_down) {
        if (_finger_down) {
            // 滚轮向下（Mouse_61 逻辑）
            if y_offset <= 96*20 - 40 - 815 { y_offset += 40 } else { y_offset = 96*20 - 815 }
        } else {
            // 滚轮向上（Mouse_60 逻辑）
            if y_offset > 40 { y_offset -= 40 } else { y_offset = 0 }
        }
    });
}
	// 反向滑出 + 淡出；播完由 panel_anim_step 销毁（close_timer 归位，别每帧重复触发）
	panel_anim_close(id)
	close_timer = -1
