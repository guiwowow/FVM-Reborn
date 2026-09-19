/// 缓时且未暂停且开关打开 → 目标 1，否则 0；线性逼近，淡入比淡出快
///
/// 注：本对象**不挂 slowmo_gate**，Step 每帧都跑 —— 淡入淡出必须是实时的，
/// 缓时只负责放慢战斗世界，不该把过场动画也一起拖慢。
/// global.slowmo_active 由 obj_touch_control（depth 1000000，Step 最先执行）本帧写入，
/// 本对象 depth -1100 后执行 → 读到的一定是本帧最新值。
var _target = (global.slowmo_overlay && global.slowmo_active && !global.is_paused) ? 1 : 0;

if (_target > overlay_a) {
    overlay_a = min(overlay_a + SLOWMO_OVERLAY_FADE_IN, 1);
} else if (_target < overlay_a) {
    overlay_a = max(overlay_a - SLOWMO_OVERLAY_FADE_OUT, 0);
}
