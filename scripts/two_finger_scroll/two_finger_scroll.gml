#macro SLOWMO_TWO_FINGER_COOLDOWN 12
// 触摸判定（touch slop 模型，2026-10-02）：位移超过 TOUCH_SLOP_PX ⇒ 本次手势算"滑动"，
// 期间与之后的点击一律不结算；没超过就抬起 ⇒ 算"点击"。TOUCH_LONGPRESS_FRAMES = 长按拾取阈值。
#macro TOUCH_SLOP_PX 20
#macro TOUCH_LONGPRESS_FRAMES 15

/// @function two_finger_gesture_active()
/// @description 当前是否处于「双指手势」状态 → 供各处点击处理**屏蔽单指点击**，防误触。
///
/// 语义 = **第二指按住 或 刚抬起不久（冷却期）**：
///   · 只用"第二指按住"判定不够 ✗ —— 按钮是「按下时 click_armed=true → 抬起时触发 on_click」，
///     松手瞬间第二指已经抬起，判定立刻变 false → 仍会误触（2026-09-16 实测：实验室松手后
///     会误开关卡详细页）。
///   · 所以第二指抬起后再保持 SLOWMO_TWO_FINGER_COOLDOWN 帧的屏蔽 → 覆盖"松手那一帧的抬起点击"。
///
/// 防卡死：标志挂在**全局**并由 obj_touch_control 每帧衰减，同时两个滚动调用点都会重置它；
///         即使某实例在手指按住时被销毁，冷却期也会自然走完，不会永久屏蔽。
///
/// @returns {Bool}
function two_finger_gesture_active() {
    if (os_type == os_windows) {
        return false;
    }
    // 单指滚动模式（2026-10-01）：不再用「第二指按住」判定 —— 那会把所有单指点击都屏蔽掉，
    // 单指模式下整个界面会失去响应。改为只看滚动冷却：由滚动动作本身刷新（每滚一格刷一次），
    // 递减仍由 obj_touch_control/Step_0 每帧统一驱动（那里每帧必跑 → 实例被销毁也不会卡住）。
    if (variable_global_exists("two_finger_cooldown") && global.two_finger_cooldown > 0) {
        return true;
    }
    return false;
}

/// @description 安卓「双指滑动替代滚轮」共享实现（B6 重构：原 4 处内联复制收敛到这里）
///
/// 只负责**公共部分**：判定第二指、算位移、按步长切格、维护 second_touch_* 状态。
/// 各界面**不同**的部分（步长、上下边界、是否需要跨帧累加余量）由调用方通过参数/回调决定：
///
///   two_finger_scroll(_px_per_step, _on_step);
///     _px_per_step : 第二指位移多少像素算一格
///     _on_step     : 每滚一格回调一次：_on_step(_finger_down)
///                    _finger_down == true  表示手指**下移**（= 滚轮向下 = 内容上移）
///
/// 调用方约定：
///   · 在 Create 里初始化 `second_touch_active = false; second_touch_y_prev = 0;`
///   · 若同时初始化了 `two_finger_accum = 0`，本函数会**跨帧累加余量**（慢拖也能攒够一格，
///     食神谱用这个手感）；没有该变量则按"本帧位移直接切格"（背包/合成屋/选卡用这个）。
///   · 只在需要生效时调用（例如 `if (!is_submenu_opened) two_finger_scroll(...)`）。
///
/// 防误触：各处点击处理（Button 统一闸口 / obj_card_slot / GridList）用
///         two_finger_gesture_active() 判断"第二指是否按住"，按住期间屏蔽单指点击。
///
/// 注意：只用 `device_mouse_*`（手册 §6 表 ✅）；`device_get_touch_count` 在 YYC 编译失败，别用。
///
/// @param {Real} _px_per_step
/// @param {Function} _on_step
/// @returns {Bool} 本帧是否发生了滚动
function two_finger_scroll(_px_per_step, _on_step) {
    if (os_type == os_windows) {
        return false;
    }
    // 滑动闸口（2026-10-02 标准 touch slop 模型，替换掉上一版"长按才滚"的错误做法）：
    //   · 位移没超过 TOUCH_SLOP_PX ⇒ 还不算滑动（这段留给点击/长按拾取）
    //   · global.touch_item_drag（正在拖卡）⇒ 本次手势归拖卡，列表不滚
    if (!variable_global_exists("touch_dragged") || !global.touch_dragged
        || (variable_global_exists("touch_item_drag") && global.touch_item_drag)) {
        second_touch_active = false;
        second_touch_y_prev = device_mouse_y(0);
        return false;
    }
    // 兜底初始化（2026-10-01 单指化后必须加）：调用方约定是在 Create 里初始化这两个变量，
    // 但 obj_info_island_bg 漏了（背包/选卡也有隐患）。旧双指代码只在"第二指按住"时才**读**它们，
    // 所以没暴露；改单指后，点击创建面板的那一帧手指还按着 → 立刻读到未定义变量 → GAME 自退
    // （退出原因码 1 = EXIT_SELF、logcat 干净，与手册 §31.1 记录的那类症状一致）。
    if (!variable_instance_exists(id, "second_touch_active")) {
        second_touch_active = false;
        second_touch_y_prev = 0;
    }
    var _has_acc = variable_instance_exists(id, "two_finger_accum");
    // 单指滚动（2026-10-01）：用第 0 根手指（= 鼠标轴，安卓上就是唯一那根）替代第 1 根
    if (!device_mouse_check_button(0, mb_left)) {
        second_touch_active = false;
        if (_has_acc) {
            two_finger_accum = 0;
        }
        return false;
    }
    var _sy = device_mouse_y(0);
    var _did = false;
    if (second_touch_active) {
        var _dy = _sy - second_touch_y_prev;
        if (_dy != 0) {
            if (_has_acc) {
                two_finger_accum += _dy;
                var _steps = abs(two_finger_accum) div _px_per_step;
                if (_steps > 0) {
                    var _dir = sign(two_finger_accum);
                    for (var _i = 0; _i < _steps; _i++) {
                        _on_step(_dir < 0);
                        _did = true;
                    }
                    two_finger_accum -= _dir * _steps * _px_per_step;
                }
            } else {
                var _steps = abs(_dy) div _px_per_step;
                for (var _i = 0; _i < _steps; _i++) {
                    _on_step(_dy < 0);
                    _did = true;
                }
            }
        }
    }
    second_touch_y_prev = _sy;
    second_touch_active = true;
    // 滚动时刷新"点击屏蔽"冷却：松手后若干帧内不响应单指点击，防误触。
    // （原双指方案靠"第二指按住"判定，单指模式改由滚动动作本身刷新）
    if (_did) {
        global.two_finger_cooldown = SLOWMO_TWO_FINGER_COOLDOWN;
    }
    return _did;
}
