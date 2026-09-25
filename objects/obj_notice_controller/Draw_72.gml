/// Draw Begin —— 每帧把 application_surface 不透明清成黑色。
///
/// 治「界面顶端残留一条 toast 边」的根因（2026-09-21 真机逐像素定位）。
///
/// 【现象】点按钮触发 toast1，toast1 正常弹出/消失，但顶端**永久**留下一条影像，
///   宽 233 屏幕px、只有 5 行高（实测 y=0..4，x=[1485..1717]），连拍 12 秒 md5 不变。
///   里面冻着的正是 toast 面板白 (247,247,247) 与文字色 (25,28,41)
///   （= show_notice.gml 的 make_color_rgb(246,246,248) / make_color_rgb(28,28,38)）。
///
/// 【为什么不是"第二条 toast"】守卫 `if (_y2 < NOTICE_PAD_Y) continue;`（=18 房间px）
///   保证任何**被画出来**的 toast 可见高度 ≥ 18 房间px = 24 屏幕px。
///   实测条子只有 5 行 < 24 ⇒ 它不可能是正在被绘制的 toast，只能是**没人重画的像素**。
///
/// 【为什么只留 5 行】room_ready 房间 1920x1080，背景图 spr_reday_room 只有 1751x1080，
///   且画在 (960, **544**) 而非 (960, 540)（origin=4 正中，正确值是 540）
///   ⇒ 房间 y=0..3 永远不被重画。toast 从屏幕上方滑入时必经这几行 → 那一帧被烙死。
///
/// 【为什么之前用 Pre Draw 没修好】Pre Draw / Post Draw **不在 application_surface 上作画**
///   （它们是给 surface 之外的内容用的，例如黑边），所以在那里 draw_clear 清掉的是
///   display buffer，随后带着残影的 application_surface 照样贴上去 = 白清一场。
///   **只有普通绘制管线（Draw Begin / Draw / Draw End）才天然渲染到 application_surface**；
///   这也是 obj_readyroom_manager/Create_0.gml 必须在 Create 里显式
///   `surface_set_target(application_surface)` 才能清屏的原因（Create 不在绘制管线里）。
///
/// 【本对象为何适合挂这里】persistent（room_init.yy 里就有实例）⇒ 每个房间、每一帧都执行；
///   Draw Begin 先于所有 Draw 事件 ⇒ 清屏在房间自己的绘制之前，不会盖住任何东西。
///   全项目**没有任何对象**有 Draw Begin 事件（已核对 objects/*/Draw_72.gml 为空）⇒ 零冲突。
///   全项目 4 个 Pre Draw 事件（obj_craft_bg / obj_info_island_bg / obj_package_bg /
///   obj_readyroom_manager）也只做 surface_create、不绘制。
///
/// 清成黑是与现状一致的颜色：未被画到的区域原本就露出黑色窗口背景。
draw_clear(c_black)

// 一次性自检标记：确认本事件真的被编译并在真机上执行（adb logcat | grep FVM-FIX）。
// 验证通过后可以删掉这 4 行。
if (!variable_global_exists("_fvm_clear_logged")) {
    global._fvm_clear_logged = true
    show_debug_message("[FVM-FIX] obj_notice_controller DrawBegin clear active")
}
