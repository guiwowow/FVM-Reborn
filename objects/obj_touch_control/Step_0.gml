// Step 事件：安卓触屏适配
// 注意：YYC 模式下 device_* 触摸函数编译失败，暂不使用；基础点击由 mouse 模拟处理
// 返回键：GameMaker 2026 安卓返回键未映射 vk_escape，用"屏幕右上角点击 = ESC"替代
// 空格：暂停/结算时点击屏幕 = 空格（已在 obj_battle_pause_manager 处理）

prev_touch_count = 0;

// 安卓锁帧：无条件按 game_speed 忙等压帧（高刷屏 game_set_speed 失效）
// 必须锁：逻辑帧率 = 速度基准（1x=60、2x=120），165Hz 屏不压会 2.75 倍速
// -0.5ms 补偿忙等轮询过冲，使实际帧率更接近目标（120Hz 屏 2x 从 110 → ~120）
if (os_type != os_windows) {
    var _target_fps = game_get_speed(gamespeed_fps);
    if (_target_fps > 0) {
        while (current_time - _last_frame_time < 1000 / _target_fps - 0.5) {}
    }
    _last_frame_time = current_time;
}

// 帧耗时监控（调试用，发布前移除）
if (false) {
    var _now = current_time;
    var _elapsed = _now - _prev_frame_time;
    _prev_frame_time = _now;
    if (_elapsed > 150 && _now > 1000) {
        var _lg = file_text_open_append("lag_log.txt");
        file_text_write_string(_lg, "[LAG] elapsed=" + string(_elapsed) + "ms fps=" + string(fps) + " objs=" + string(instance_count) + " room=" + room_get_name(room) + " enemies=" + string(instance_number(obj_enemy_parent)) + "\n");
        file_text_close(_lg);
    }
}

if (os_type != os_windows) {
    // 屏幕左上角区域点击 = 空格暂停（战斗专属，配合 Draw 的暂停按钮）
    if (instance_exists(obj_battle) && mouse_check_button_pressed(mb_left)) {
        if (mouse_x < 150 && mouse_y < 150) {
            keyboard_key_press(vk_space);
            keyboard_key_release(vk_space);
        }
    }
    // 屏幕左下角区域点击 = ESC（安卓替代返回键，配合 Draw 的 ESC 按钮）
    if (mouse_check_button_pressed(mb_left)) {
        if (mouse_x < 130 && mouse_y > room_height - 130) {
            keyboard_key_press(vk_escape);
            keyboard_key_release(vk_escape);
        }
    }
    // 屏幕左下 ESC 上方区域点击 = 加速切换（替代 shift，1x/2x）
    if (mouse_check_button_pressed(mb_left)) {
        if (mouse_x < 130 && mouse_y > room_height - 260 && mouse_y < room_height - 130) {
            var _battle = instance_find(obj_battle, 0);
            if (instance_exists(_battle)) {
                _battle.speed_up = !_battle.speed_up;
                speed_up_set(_battle.speed_up);   // 唯一入口（含 60Hz 的半分辨率处理）
            }
        }
    }
    // 屏幕左下加速按钮上方区域点击 = 选卡缓时开关（战斗专属）
    if (mouse_check_button_pressed(mb_left)) {
        if (mouse_x < 130 && mouse_y > room_height - 390 && mouse_y < room_height - 260) {
            global.cardslow_enabled = !global.cardslow_enabled;
        }
    }
    // 屏幕左下 缓时按钮上方区域点击 = 调试：一键召唤本关 BOSS（仅 global.debug 模式 + 战斗内）
    if (global.debug && instance_exists(obj_battle) && mouse_check_button_pressed(mb_left)) {
        if (mouse_x < 130 && mouse_y > room_height - 520 && mouse_y < room_height - 390) {
            debug_summon_level_boss();
        }
    }
}

// 选卡缓时：选中卡片或铲子时战斗逻辑 12 倍减速（保持 60fps 渲染，逻辑对象每 12 帧推进）
// 帧号每帧 +1（本对象 depth 最大，Step 最先执行，其他对象读到的都是本帧值）
global.game_frame = (global.game_frame + 1) mod 12;

// 双指手势冷却：第二指抬起后再屏蔽单指点击若干帧（防"松手瞬间误触"，见 two_finger_gesture_active）
// 放这里是因为本对象每帧必跑 → 即使滚动调用点所在实例被销毁，冷却也会自然走完，不会永久屏蔽。
if (!variable_global_exists("two_finger_cooldown")) {
    global.two_finger_cooldown = 0;
}
if (device_mouse_check_button(1, mb_left)) {
    global.two_finger_cooldown = SLOWMO_TWO_FINGER_COOLDOWN;
} else if (global.two_finger_cooldown > 0) {
    global.two_finger_cooldown -= 1;
}
if (instance_exists(obj_battle)) {
    var _slow_selected = false;
    with (obj_card_slot) {
        if (is_selected) _slow_selected = true;
    }
    with (obj_shovel_slot) {
        if (is_selected) _slow_selected = true;
    }
    global.slowmo_active = global.cardslow_enabled && !global.is_paused && _slow_selected;
} else {
    global.slowmo_active = false;
}
