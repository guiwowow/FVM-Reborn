// =====================================================================
// 2 倍速（战斗加速）的唯一开关点
// =====================================================================
// 机制背景：GM 引擎的**逻辑帧与显示帧 1:1 绑定**，所以逻辑速度 = 屏幕刷新率。
//   · 面板能跑到 120Hz：game_set_speed(120) 直接生效 → 120 逻辑帧/秒 = 2x
//   · 面板封顶 60Hz ：靠 game_set_speed 拿不到 120（平台不给 60Hz 面板开 120fps）
//
// 支持性判定（2026-09-20 定案）：**实测法**
//   ⚠️ 血泪教训：第一版用 display_get_frequency() >= 110 判定，**120Hz 平板也被误拦**。
//      原因：它返回的是**当前**刷新率，不是面板上限 —— 平板空闲时正好停在 60Hz。
//      （手册 §25.7 早就记过「可能返回 0，或返回面板最高而非当前值」，结果被按相反方向误用。）
//      任何“读一个数就下结论”的做法都不可靠：mGameSpeedControl 被 native 钳、刷新率读数随时间漂移。
//   ✅ 所以改成**实际请求一次 120，然后看真实逻辑帧率上不上得去**：
//        · 窗口内最快一帧 >= SPEED_UP_MIN_OK_FPS → 面板确实能上 120
//        · 上不去                                → 自动撤回 1x 并提示玩家
//
// ⚠️ 判定结果**不缓存**（第二版曾缓存，出过 bug：设备先跑 120 再被锁 60Hz 时，
//    旧的“支持”结论仍生效 → 按钮能开、无效果、也不提示）。
//    现在改为**持续监控**：只要 2x 开着，就不断开新窗口复检，
//    面板中途被改回 60Hz 也会在约 1 秒内被自动撤回并提示。
//
// 判定用 delta_time（上一帧真实微秒数）自算**瞬时**帧率，不用 fps——
// 后者是约 1 秒窗口的**平滑值**，探测刚开始读到的还是切换前的旧值（§25.7 记录的“振荡”根源）。

#macro SPEED_UP_PROBE_WARMUP_US     600000    // 每个窗口开头忽略这么久（面板切频/负载波动期间不代表稳态）
#macro SPEED_UP_PROBE_SAMPLE_US     800000    // 窗口采样时长（微秒）
#macro SPEED_UP_MIN_OK_FPS          70        // 窗口内**最快一帧**低于此值 = 面板确实上不去 120
#macro SPEED_UP_PROBE_INTERVAL_US   800000    // 窗口结束后到下个窗口开始的间隔

/// @description 开一个探测/监控窗口（speed_up_set 打开 2x 时调用）
/// 状态机 global.speed_up_probe_state：0=空闲 1=空转期 2=采样期
function speed_up_probe_begin() {
    global.speed_up_probe_state = 1;              // 空转期
    global.speed_up_probe_left = SPEED_UP_PROBE_WARMUP_US;
    global.speed_up_probe_max_fps = 0;
}

/// @description 每帧调用（obj_touch_control/Step_0.gml 的压帧块之后）—— 推进探测/监控窗口
///
/// 必须在压帧之后调用：压帧是按 game_get_speed(fps) 计的，先压帧才能让本帧的
/// delta_time 反映真实节拍。
///
/// 窗口结束 → 判定 → 若通过则**立刻开下一个窗口**（开着 2x 就一直复检）。
function speed_up_probe_tick() {
    if (!variable_global_exists("speed_up_probe_state")) {
        return;
    }
    if (global.speed_up_probe_state == 0) {
        return;   // 空闲：没开 2x
    }

    // ---- 空转期：等面板切过去，这期间不采样（否则读到的是切换前的旧节奏）----
    if (global.speed_up_probe_state == 1) {
        global.speed_up_probe_left -= delta_time;
        if (global.speed_up_probe_left > 0) {
            return;
        }
        // 进入采样期
        global.speed_up_probe_state = 2;
        global.speed_up_probe_left = SPEED_UP_PROBE_SAMPLE_US;
        global.speed_up_probe_max_fps = 0;
        return;
    }

    // ---- 采样期：记录窗口内最快的一帧 ----
    if (delta_time > 0) {
        var _inst = 1000000 / delta_time;
        if (_inst > global.speed_up_probe_max_fps) {
            global.speed_up_probe_max_fps = _inst;
        }
    }
    global.speed_up_probe_left -= delta_time;
    if (global.speed_up_probe_left > 0) {
        return;
    }

    // ---- 窗口结束 → 判定 ----
    var _best = global.speed_up_probe_max_fps;

    // 阈值取 70 而非 100：双阈值不能定太高。
    //   60Hz 面板：帧时恒为 16.6ms ≈ 60fps（离 70 还差一截，能抓准）
    //   120Hz 面板在重负载下可能只跑到 80~110fps —— 用 100 会把这种情况误判成“不支持”。
    //   70~100 属模糊区，不动（宁可放过，也不要误撤掉真的支持 2x 的设备）。
    if (_best >= SPEED_UP_MIN_OK_FPS) {
        // 面板确实能上 120 → 开下一个窗口继续监控（不缓存结论）
        global.speed_up_probe_state = 1;
        global.speed_up_probe_left = SPEED_UP_PROBE_INTERVAL_US;
        global.speed_up_probe_max_fps = 0;
        return;
    }

    // 面板上不去 120（当前被锁在 60Hz / 面板本身只有 60Hz）→ 撤回 1x 并提示
    global.speed_up_active = false;
    global.speed_up_probe_state = 0;
    global.speed_up_probe_left = 0;
    game_set_speed(60, gamespeed_fps);
    speed_up_write_flag();
    speed_up_surface_fit();
    if (!global.speed_up_retract_notified) {
        global.speed_up_retract_notified = true;
        show_notice("2倍速仅支持120hz刷新率设备", 180);
    }
}

/// @description 切换 1x / 2x 倍速（触屏按钮与 shift 键都必须走这里，别再各自调 game_set_speed）
///
/// 开启时**立刻**切到 120 并开一个探测窗口；约 1.4s 后若面板确实上不去 120，会被
/// speed_up_probe_tick 自动撤回 1x 并提示。开着期间持续复检 → 中途锁回 60Hz 也会被撤回。
///
/// ⚠️ 「返回 true」只代表**已切入 2x**，不代表**已确认可用** —— 不可用的设备会在约 1 秒后被
///    tick 撤回 + 提示。调用方照返回值同步按钮即可；撤回后实例变量由
///    obj_battle/Step_0.gml 顶部的 speed_up = global.speed_up_active; 每帧纠正。
///
/// @param {Bool} _on
/// @return {Bool} 请求后的倍速状态
function speed_up_set(_on) {
    if (!variable_global_exists("speed_up_active")) {
        global.speed_up_active = false;
    }
    if (_on) {
        global.speed_up_active = true;
        global.speed_up_retract_notified = false;   // 每次玩家主动开 → 允许再提示一次
        game_set_speed(120, gamespeed_fps);
        speed_up_probe_begin();                     // 持续监控：开着就一直复检
        speed_up_write_flag();
        speed_up_surface_fit();
        return true;
    }

    // 关掉：回 1x，并停掉监控（半途关掉不该再弹提示）
    global.speed_up_active = false;
    global.speed_up_probe_state = 0;
    global.speed_up_probe_left = 0;
    game_set_speed(60, gamespeed_fps);
    speed_up_write_flag();
    speed_up_surface_fit();
    return false;
}

/// @description 把「是否开了 2x」告诉 runtime 的 Java 层
///
/// 为什么需要这条通道：60Hz 面板上 native 会把请求帧率**钳到面板刷新率**，
/// RunnerJNILib.mGameSpeedControl 恒为 60，Java 侧无法据此区分 1x/2x
/// （这正是 2026-09 旧补丁“打了没效果”的原因）。
/// 复用已验证的 FVMBridge 文件轮询通道（与 share_request.txt 同一机制）：
/// **文件存在 = 开了 2x**。runtime 侧 FVMBridge.tick() 每帧 stat 一次，结果存进
/// FVMBridge.s_speed2x，DemoRenderer 据此决定一个显示帧里是否追加第二个逻辑步。
function speed_up_write_flag() {
    // ⛔ 2026-09-19 放弃 60Hz 双步进方案：不再创建标志文件。
    // runtime 侧 FVMBridge.s_speed2x 因此恒为 false → DemoRenderer 的双步进永不触发
    // → 行为与实施此方案之前完全一致（只保留 game_set_speed(60/120)）。
    if (file_exists("fvm_speed2x.txt")) file_delete("fvm_speed2x.txt");
    if (file_exists("fvm_2xsub.txt"))  file_delete("fvm_2xsub.txt");
}

/// @description 按「当前倍速 + 面板刷新率」调整 application_surface 分辨率
///              面板能上 120Hz：引擎自己就能跑满 120 → 保持原生分辨率（最清晰）
///              面板上不去且开了 2x：需要「一帧两次渲染」的补偿 → 降到半分辨率
///              每帧调用是安全的（尺寸相同则直接返回，不做任何事）
function speed_up_surface_fit() {
    if (!surface_exists(application_surface)) {
        return;
    }
    // 不能假设原始分辨率等于 room_width/height：安卓上 application_surface 通常是**屏幕**分辨率
    if (!variable_global_exists("app_surf_w") or global.app_surf_w <= 0 or global.app_surf_h <= 0) {
        global.app_surf_w = surface_get_width(application_surface);
        global.app_surf_h = surface_get_height(application_surface);
    }
    if (!variable_global_exists("speed_up_active")) {
        global.speed_up_active = false;
    }
    // ⛔ 2026-09-19 放弃 60Hz 双步进方案 → 半分辨率一并停用，2x 不再改变 application_surface。
    // 保留整段代码与 runtime 侧补丁（休眠状态），备日后重启此方向时用。
    var _need_half = false;
    var _w = _need_half ? max(2, global.app_surf_w div 2) : global.app_surf_w;
    var _h = _need_half ? max(2, global.app_surf_h div 2) : global.app_surf_h;
    if (surface_get_width(application_surface) != _w or surface_get_height(application_surface) != _h) {
        surface_resize(application_surface, _w, _h);
    }
}

/// @description 启动时初始化 2 倍速状态（obj_game_init/Create_0 调用）
function speed_up_init() {
    if (!variable_global_exists("speed_up_active")) {
        global.speed_up_active = false;
    }
    global.speed_up_probe_state = 0;      // 0=空闲 1=空转期 2=采样期
    global.speed_up_probe_left = 0;
    global.speed_up_probe_max_fps = 0;
    global.speed_up_retract_notified = false;
}
