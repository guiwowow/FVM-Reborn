draw_notices()
draw_error_dialog()

// ── 场景过渡黑幕（2026-10-07 修黑屏）──
// room_transition_alpha() 在 PR#93 里同样无任何调用点（漏了绘制宿主）⇒ 淡出/淡入根本看不见。
// 本对象 depth = -9900（绘制在最上层）是遮罩的天然宿主。矩形放大 3 倍保证铺满，画完复位 alpha。
var _ta = room_transition_alpha()
if (_ta > 0) {
    draw_set_color(c_black)
    draw_set_alpha(_ta)
    draw_rectangle(-room_width, -room_height, room_width * 2, room_height * 2, false)
    draw_set_alpha(1)
}