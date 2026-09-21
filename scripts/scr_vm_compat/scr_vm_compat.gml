// =====================================================================
// VM 兼容层 —— 地图脚本 VM 依赖联机版「两阶段懒加载」里的几个全局/函数
// =====================================================================
// 背景：VM 代码（scr_command_VM / scr_set_var_commands / src_mod）用
//   get_load_sprite(name)  名称 → 精灵
//   global._pid_reverse    占位/动态精灵 id → 名称（VM 的临时贴图也登记在这里）
//   global._sprite_cache   名称 → 精灵 id
//   global._audio_reverse  音频 id → 名称（VM_LoadSound 登记，供音量钩子用）
//
// 联机版的这些来自 scr_sprite_load_manager（588 行）+ src_file_cache（299 行），
// 是一整套「占位精灵 + 异步加载 + 客户端资源传输」系统，本工程**不移植**
//（安卓版所有精灵都已 ASTC 烘焙进包，不存在需要占位等待的场景）。
//
// 这里只提供最小替身，保证 VM 的贴图解析路径能跑通，且不改变任何既有行为：
//   · 本工程原版没有这几个全局 → 替身不会覆盖任何东西
//   · get_load_sprite 对内置精灵名直接 asset_get_index 命中，与不移植时表现一致
//   · 真正需要异步加载的情况本工程不存在，所以不做占位/排队
// =====================================================================

if (!variable_global_exists("_sprite_cache")) {
    global._sprite_cache = ds_map_create();     // 名称 → 精灵 id
}
if (!variable_global_exists("_pid_reverse")) {
    global._pid_reverse = ds_map_create();      // 精灵 id → 名称
}
if (!variable_global_exists("_sprite_state")) {
    global._sprite_state = ds_map_create();     // 名称 → 加载状态（本工程恒为已加载）
}
if (!variable_global_exists("_pending_map")) {
    global._pending_map = ds_map_create();      // 名称 → 是否在异步队列（本工程恒空）
}
if (!variable_global_exists("_audio_reverse")) {
    global._audio_reverse = ds_map_create();    // 音频 id → 名称
}
// VM_LoadSound 第一句就是无守卫的 ds_map_exists(global._audio_cache, ...)。
// 不初始化的话，地图脚本一旦调 VM_LoadSound 就会读不存在的全局而崩
//（与 global._evt_log_enabled 同一类问题，2026-09-21 一并排查出来）。
if (!variable_global_exists("_audio_cache")) {
    global._audio_cache = ds_map_create();      // 音频路径 → 音频 id
}

/// @description 名称 → 精灵（本工程版：同步解析，无占位、无异步队列）
/// @param {String} _name 精灵名，如 "spr_blonde_mary_idle"，或 VM 加载的自定义贴图名
/// @returns {Real} 精灵 id
function get_load_sprite(_name) {
    // ① 内置资源：直接命中。顺带登记反向表，让 VM 能把 sprite_index 翻回名字
    //    （VM_GetProp("sprite_index") 等需要它）。
    // 防御：调用方可能传 sprite 索引（数字）而不是名字。不同上游版本两种用法都出现过，
    // 这里做类型分发，避免把合法 sprite 索引当成名字去查而静默退到兜底精灵。
    if (is_real(_name)) {
        if (sprite_exists(_name)) return _name;
        return spr_cloud_daytime;
    }
    if (!is_string(_name)) return spr_cloud_daytime;
    var _native_spr = asset_get_index(_name);
    if (_native_spr != -1 && sprite_exists(_native_spr)) {
        if (!ds_map_exists(global._pid_reverse, _native_spr)) {
            ds_map_add(global._pid_reverse, _native_spr, _name);
        }
        return _native_spr;
    }
    // ② VM 临时贴图（地图脚本 VM_LoadSprite 从地图目录加的，bin 重载时清理）
    if (ds_map_exists(global._VM_sprite_temp_cache, _name)) {
        var _v = global._VM_sprite_temp_cache[? _name];
        if (is_string(_v)) _v = global._VM_sprite_temp_cache[? _v];   // 别名条目
        return _v;
    }
    // ③ VM 永久贴图（VM_LoadSpritePerm，bin 重载不清）
    if (ds_map_exists(global._VM_sprite_cache, _name)) {
        return global._VM_sprite_cache[? _name];
    }
    // ④ 兜底：本工程不存在"异步加载中"的中间态，找不到就是真找不到，
    //    返回一个一定存在的精灵，避免返回 -1 让调用方崩。
    return spr_cloud_daytime;
}
