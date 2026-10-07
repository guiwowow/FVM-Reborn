draw_notices()
draw_error_dialog()

// 场景过渡遮罩已改由上游的 Draw_73（Post-Draw）负责 —— 在本对象 Draw_0 再画一层会双重压暗，
// 故移除此处的手工黑幕（2026-10-07，合并 PR#93 补齐提交 da5cc6f24 时）。