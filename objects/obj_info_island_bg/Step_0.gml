// 安卓：双指滑动替代滚轮（情报岛）
// B6 重构：公共部分（第二指判定/位移/切格/状态维护）收敛到 scripts/two_finger_scroll；
// 本界面差异 = 步长 20px、y_offset 步进 40px（与 Mouse_60/Mouse_61 滚轮事件完全同逻辑）。
// 注意：只用 device_mouse_*（§4 表 ✅）；device_get_touch_count 在 YYC 编译失败，别用。
if (os_type != os_windows) {
    two_finger_scroll(20, function(_finger_down) {
        if (_finger_down) {
            // 滚轮向下（Mouse_61 逻辑）
            if (y_offset <= 142*1.5*info_rows - 40 - surface_height) {
                y_offset += 40
            } else {
                y_offset = 142*1.5*info_rows - surface_height
            }
        } else {
            // 滚轮向上（Mouse_60 逻辑）
            if (y_offset > 40) {
                y_offset -= 40
            } else {
                y_offset = 0
            }
        }
    });
}
