/// 缓时视觉叠加：整体冷色调 + 外围暗角
/// 色调用 draw_rectangle_color（与 obj_screen_flash_manager/Draw_0.gml 同源，已在战斗真机验证）。
/// 暗角用 draw_vertex_colour 逐顶点渐变（Gouraud）—— 顶点 alpha 由 GPU 插值，
/// 因此**绝对平滑、没有台阶、没有接缝**。
///
/// 为什么暗角不能用矩形堆叠：每层矩形只有一个固定 alpha，N 层就是 N 级台阶；
/// 而且相邻矩形边界有 1px 重叠会二次混色，在画面上表现为一条条可见条纹。
/// 逐顶点渐变没有这个问题：相邻环共享顶点，插值天然连续。
if (overlay_a <= 0) exit;

var _w = room_width;
var _h = room_height;

// ① 整体冷色调
var _t = overlay_tint;
draw_set_alpha(overlay_a * SLOWMO_OVERLAY_TINT_ALPHA);
draw_rectangle_color(0, 0, _w, _h, _t, _t, _t, _t, false);

// ② 外围暗角：3 条同心矩形环，alpha 按原来的二次衰减取 0 / 0.25 / 1 三个采样点
//    两段之间由 GPU 线性插值，视觉上等价于平滑的二次渐变
var _peak  = overlay_a * SLOWMO_OVERLAY_VIGNETTE_ALPHA;
var _reach = min(_w, _h) * SLOWMO_OVERLAY_VIGNETTE_REACH;
var _ins = [_reach, _reach * 0.5, 0];            // 内 → 外：距离屏幕边的内缩量
var _alp = [0, _peak * 0.25, _peak];             // 对应 alpha（(1-t)^2 在 t=0.5 处 = 0.25）

for (var _r = 0; _r < 2; _r++) {
    var _i = _ins[_r];      var _a = _alp[_r];       // 内环
    var _j = _ins[_r + 1];  var _b = _alp[_r + 1];   // 外环
    draw_primitive_begin(pr_trianglestrip);
    // 绕一圈：内环 4 角与外环 4 角交替；k=4 时回到第 0 个角以闭合
    for (var _k = 0; _k <= 4; _k++) {
        var _m = _k mod 4;
        var _right = (_m == 1 || _m == 2);
        var _bottom = (_m >= 2);
        draw_vertex_colour(_right ? _w - _i : _i, _bottom ? _h - _i : _i, c_black, _a);
        draw_vertex_colour(_right ? _w - _j : _j, _bottom ? _h - _j : _j, c_black, _b);
    }
    draw_primitive_end();
}

draw_set_alpha(1);
