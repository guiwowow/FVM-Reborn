// =====================================================================
// 2 倍速（战斗加速）的唯一开关点
// =====================================================================
// 机制背景：GM 引擎的**逻辑帧与显示帧 1:1 绑定**，所以逻辑速度 = 屏幕刷新率。
//   · 面板 >= 120Hz：game_set_speed(120) 直接生效 → 120 逻辑帧/秒 = 2x
//   · 面板 60Hz：刷新率封顶 60，靠 game_set_speed 拿不到 120
//
// 60Hz 的解法（2026-09-19 定案）：runtime 侧补丁在**一个显示帧里跑 2 次逻辑步**
//   （见 F:\FVM-Reborn\tools\android_resume_fix\patch_gm_runner_preserve_egl.py 的 2x 段）。
//   代价是同一显示帧里要渲染两次 → 必须把 application_surface 降到半分辨率（渲染量 1/4），
//   两次渲染才装得进 vsync 预算。
//
// ⚠️ 为什么必须降分辨率（这是 2026-09 旧补丁 "logic 58/s" 的真正原因）：
//   一个逻辑步的预算 = 1000/120 ≈ 8.33ms（60 显示帧/秒 × 2 步/帧）。
//   全屏渲染在 3200x1440 上约 9ms > 8.33ms → 错过 vsync 截止线 →
//   每次迭代吃掉 2 个 vsync 周期 → 帧率掉到 30 显示帧/秒 × 2 步 = 60 逻辑帧/秒 ≈ 1x，
//   正好把双倍步进全抵消掉。半分辨率后单次渲染 ~2.3ms，两次仍稳稳落在预算内。
//
// 注：obj_touch_control/Step_0 开头的忙等压帧块按 `1000 / game_get_speed(fps)` 计时，
//     它作用在**每个逻辑步**上，所以一帧跑 2 步时天然就是 120 步/秒的节拍器，无需再动。

/// @description 切换 1x / 2x 倍速（触屏按钮与 shift 键都必须走这里，别再各自调 game_set_speed）
/// @param {Bool} _on
function speed_up_set(_on) {
    if (!variable_global_exists("speed_up_active")) {
        global.speed_up_active = false;
    }
    global.speed_up_active = _on;
    game_set_speed(_on ? 120 : 60, gamespeed_fps);
    speed_up_write_flag();
    speed_up_surface_fit();
}

/// @description 把「是否开了 2x」告诉 runtime 的 Java 层
///
/// 为什么需要这条通道：60Hz 面板上 native 会把请求帧率**钳到面板刷新率**，
/// `RunnerJNILib.mGameSpeedControl` 恒为 60，Java 侧无法据此区分 1x/2x
/// （这正是 2026-09 旧补丁"打了没效果"的原因）。
/// 复用已验证的 FVMBridge 文件轮询通道（与 share_request.txt 同一机制）：
/// **文件存在 = 开了 2x**。runtime 侧 FVMBridge.tick() 每帧 stat 一次，结果存进
/// `FVMBridge.s_speed2x`，DemoRenderer 据此决定一个显示帧里是否追加第二个逻辑步。
function speed_up_write_flag() {
    // ⛔ 2026-09-19 放弃 60Hz 双步进方案：不再创建标志文件。
    // runtime 侧 FVMBridge.s_speed2x 因此恒为 false → DemoRenderer 的双步进永不触发
    // → 行为与实施此方案之前完全一致（只保留 game_set_speed(60/120)）。
    if (file_exists("fvm_speed2x.txt")) file_delete("fvm_speed2x.txt");
    if (file_exists("fvm_2xsub.txt"))  file_delete("fvm_2xsub.txt");
}

/// @description 按「当前倍速 + 面板刷新率」调整 application_surface 分辨率
///              面板 >= 110Hz：引擎自己就能跑满 120 → 保持原生分辨率（最清晰）
///              面板 < 110Hz 且开了 2x：需要「一帧两次渲染」的补偿 → 降到半分辨率
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
    // 只有「双步进真的生效」时才降分辨率 —— 由 runtime 侧回执文件决定，不猜刷新率。
    // runtime 的 FVMBridge.ackSubstep() 在 (玩家开了 2x 且面板当前刷新率 <110Hz) 时
    // 创建 fvm_2xsub.txt，否则删除。这是唯一准确的判据：
    //   · 用 display_get_frequency() 不可靠（可能返回 0，或返回面板**最高**而非**当前**刷新率）
    //   · 用实测 fps 会**振荡**（降分辨率→fps 升到 120→判据变假→恢复→fps 掉回 60→…）
    // ⛔ 2026-09-19 放弃 60Hz 双步进方案 → 半分辨率一并停用，2x 不再改变 application_surface。
    // 保留整段代码与 runtime 侧补丁（休眠状态），备日后重启此方向时用。
    var _need_half = false;
    var _w = _need_half ? max(2, global.app_surf_w div 2) : global.app_surf_w;
    var _h = _need_half ? max(2, global.app_surf_h div 2) : global.app_surf_h;
    if (surface_get_width(application_surface) != _w or surface_get_height(application_surface) != _h) {
        surface_resize(application_surface, _w, _h);
    }
}
