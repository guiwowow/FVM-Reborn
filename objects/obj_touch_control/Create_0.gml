// ============================================================
// obj_touch_control —— 触屏适配控制器（持久对象）
// 为 Android 触屏补充原版依赖鼠标右键/键盘的操作：
//  1) 双指点击  = 取消当前选中（替代右键 / Esc）
//  2) 屏幕右上角取消按钮（替代右键 / Esc）
//  3) 触屏铲子/卡槽的选取已由对象自身点击逻辑支持
// 本对象不依赖具体平台，Windows 上也可正常使用。
// ============================================================

persistent = true
depth = 1000000

prev_touch_count = 0
prev_paused = false   // 回前台首帧检测用（后台期间抬指事件会丢）

// 取消按钮（GUI 坐标系，游戏内 1920x1080 空间，右上角）
cancel_btn = { x: 1800, y: 20, w: 90, h: 90 }
// 铲子切换按钮（GUI 坐标系，左上角）——触屏上快速切换铲子
shovel_btn = { x: 24, y: 20, w: 90, h: 90 }


/// @description 是否处于战斗/出击界面（存在卡槽或铲子槽）
function in_battle_hud() {
    return instance_exists(obj_shovel_slot) || instance_exists(obj_card_slot)
}

// 选卡缓时门控 slowmo_gate() 已移入 script 资源 scripts/slowmo_gate/slowmo_gate.gml
// （写在对象事件里会变成该实例的方法，其它对象调用会报 not set before reading it ✗）


// 帧耗时监控（安卓卡顿定位用）
_prev_frame_time = 0;

// 锁帧状态
_last_frame_time = 0;

// 选卡缓时：全局帧号 + 缓时激活标志（保持 60fps 渲染，逻辑对象每 12 帧推进一次）
global.game_frame = 0;
global.slowmo_active = false;

// ============================================================
// 调试模式（global.debug = 1）专用：一键召唤本关 BOSS
//   BOSS 数据来源 = global.level_file.waves[*] 中 boss_wave = true 的波次（boss / boss2）
//   每按一次轮换到下一个 BOSS 波次；计数器挂在 obj_battle 实例上 → 每场战斗自动归零
//   生成位置/HP 修正与 obj_battle/Step_0 的正常 BOSS 波次逻辑完全一致
// ============================================================
/// @description 调试：召唤本关 BOSS（多 BOSS 波次轮换）
function debug_summon_level_boss() {
    var _battle = instance_find(obj_battle, 0);
    if (!instance_exists(_battle)) {
        show_notice("仅战斗中可用", 60);
        return;
    }
    var _lv = global.level_file;
    if (!is_struct(_lv) || !variable_struct_exists(_lv, "waves")) {
        show_notice("无关卡波次数据", 60);
        return;
    }
    var _waves = _lv.waves;

    // 收集所有 BOSS 波次：[boss1, hp_mod1, boss2, hp_mod2]
    var _entries = [];
    for (var i = 0; i < array_length(_waves); i++) {
        var _w = _waves[i];
        if (!is_struct(_w) || !variable_struct_exists(_w, "boss_wave") || !_w.boss_wave) continue;
        var _b1 = variable_struct_exists(_w, "boss") ? _w.boss : "";
        if (!is_string(_b1)) _b1 = "";
        var _b2 = variable_struct_exists(_w, "boss2") ? _w.boss2 : "";
        if (!is_string(_b2)) _b2 = "";
        var _m1 = (variable_struct_exists(_w, "boss_1_hp_modify") && is_real(_w.boss_1_hp_modify)) ? _w.boss_1_hp_modify : 1.0;
        var _m2 = (variable_struct_exists(_w, "boss_2_hp_modify") && is_real(_w.boss_2_hp_modify)) ? _w.boss_2_hp_modify : 1.0;
        if (_b1 != "" || _b2 != "") array_push(_entries, [_b1, _m1, _b2, _m2]);
    }
    if (array_length(_entries) == 0) {
        show_notice("本关没有 BOSS", 60);
        return;
    }

    // 轮换选择
    if (!variable_instance_exists(_battle, "debug_boss_idx")) _battle.debug_boss_idx = 0;
    if (_battle.debug_boss_idx >= array_length(_entries)) _battle.debug_boss_idx = 0;
    var _e = _entries[_battle.debug_boss_idx];
    _battle.debug_boss_idx = (_battle.debug_boss_idx + 1) mod array_length(_entries);

    // 生成（boss1 / boss2 各一次）
    var _spawned = "";
    for (var j = 0; j < 2; j++) {
        var _bid = _e[j * 2];
        var _mod = _e[j * 2 + 1];
        if (!is_string(_bid) || _bid == "" || !ds_map_exists(global.enemy_map, _bid)) continue;
        var _row = irandom_range(0, global.grid_rows - 1);
        var _pos = get_world_position_from_grid(10, _row);
        var _inst = instance_create_depth(_pos.x - 80, _pos.y + 30, -200, global.enemy_map[? _bid]._obj);
        if (is_real(_mod) && _mod > 0) {
            _inst.hp *= _mod;
            _inst.maxhp *= _mod;
        }
        _battle.boss_count++;
        _spawned += string(ds_map_exists(global.boss_list, _bid) ? global.boss_list[? _bid].name : _bid) + " ";
    }
    if (_spawned == "") show_notice("召唤失败（enemy_map 缺少该 BOSS）", 60);
    else show_notice("召唤 BOSS：" + _spawned, 90);
}
