// =====================================================================
// 选卡缓时：触发时**玩法（游戏世界的钟）= 现实时间的 1/12**
// =====================================================================
// 定义（2026-09-19 与用户确认）：缓时触发后，玩法的钟走得只有现实时间的 1/12。
//   · **逻辑 / 玩法**：只有 global.game_frame == 0 的帧跑后续逻辑 → 每 12 帧推进 1 次 = 1/12
//   · **动画（image_speed 驱动）**：image_speed 缩到 SLOWMO_ANIM_SCALE
//   · **动画（手动计时器驱动）**：见 slowmo_anim_advance()，**只补偿可证明纯视觉的计时器**
//   · 渲染仍是 60fps（画面不卡，只是"世界的钟"走得慢）
//
// ⚠️ 为什么动画补偿必须走白名单（2026-09-19 全项目审计的结论）：
//    `timer` 这个名字被 187 个文件共用，在子弹/特效类里它是**同名双职**：
//        timer++
//        image_alpha = 1 - 0.1 * (timer - 10)          ← 淡出动画
//        if timer >= 20 { instance_destroy() }         ← 寿命（玩法）
//    → 无差别补推 `timer` 会让这些特效提前约 3.75 倍消失 = **破坏平衡**。
//    同理 `attack_timer`（99 个文件）是纯玩法计时器（攻击周期/状态机），绝不能碰。
//    所以 slowmo_anim_advance() 只补偿两类：全局零玩法引用的名字 + 显式 opt-in 的对象。
//
// 想改动画流畅度只动下面这一个数字：
//   1.0        = 动画不减速（最流畅，但与 1/12 的玩法脱节 → 卡片"动画跑完还在冷却"）
//   0.25       = 默认。非逻辑帧每帧累积 0.25 → 每 12 帧补 3 格，加逻辑帧自己的 1 格
//                ≈ 1/3 速（这是 2026-09 之前旧机制的手感，已装机验证）
//   0.08333333 = 动画与玩法严格同速（最"一致"但最卡顿，见下方历史教训）
#macro SLOWMO_ANIM_SCALE 0.25

// 历史教训（2026-09-19 移除过一次，2026-09-19 晚按用户要求以白名单方式加回）：
//   旧实现在非逻辑帧给**任意**叫 `timer` 的变量补推 +1 → 连带加速了玩法计时器。
//   现在的实现把「动画可以比玩法顺」这件事**限制在已审计的范围内**，其余一切保持 1/12。

// ---- 缓时视觉叠加层 obj_slowmo_overlay 的可调参数（想改观感只动这几个数字）----
#macro SLOWMO_OVERLAY_TINT_ALPHA      0.10   // 冷色调滤镜强度（0.06 极轻 / 0.10 轻 / 0.16 中；>0.2 开始影响辨认植物）
#macro SLOWMO_OVERLAY_VIGNETTE_ALPHA  0.27   // 暗角最外圈峰值透明度
#macro SLOWMO_OVERLAY_VIGNETTE_REACH  0.18   // 暗角作用范围（屏幕短边比例）
#macro SLOWMO_OVERLAY_FADE_IN         0.12   // 淡入步长（≈8 帧 / 0.15s）
#macro SLOWMO_OVERLAY_FADE_OUT        0.07   // 淡出步长（≈14 帧 / 0.25s）

/// @description 选卡缓时门控（B5 重构：原 492 处逐字重复的内联块收敛到这里）
///
/// 调用方式（必须由调用方 exit —— 函数无法让调用者退出）：
///     if (slowmo_gate()) exit;
///
/// 返回 true = 本帧跳过后续逻辑（世界这一帧不动）；false = 正常执行（逻辑帧）。
///
/// 注：必须放在 **script 资源** 里才是真全局函数；写在对象事件里会变成该实例的方法，
/// 其它对象调用会报 "Variable <obj>.slowmo_gate(...) not set before reading it"（2026-09-15 踩过）。
function slowmo_gate() {
    // 2026-10-07 恢复：2026-10-06 曾在此直接 `return false;` 把整个缓时模块下线
    // （战斗内「缓时:开/关」按钮同时被删）。现在闸口恢复原逻辑；缓时是否触发由
    // global.slowmo_active 决定（战斗内「缓时:开/关」按钮 / config.ini 的 settings/cardslow_enabled）；
    // 画面特效另有「动效等级 >= 基础（ui_anim_on(1)）」条件，见 objects/obj_slowmo_overlay/Step_0.gml。
    if (global.slowmo_active) {
        if (!variable_instance_exists(id, "__slow_base_ispeed")) {
            __slow_base_ispeed = image_speed;
        }
        // 动画：image_speed 驱动的部分按 SLOWMO_ANIM_SCALE 减速
        image_speed = __slow_base_ispeed * SLOWMO_ANIM_SCALE;

        // 非逻辑帧：调用方 exit 会跳过**全部玩法逻辑**（攻击周期、冷却、状态机、寿命…）
        // —— 这些因此严格保持 1/12。
        // 但纯视觉的手动动画计时器需要单独推进，否则会卡在 1/12（见 slowmo_anim_advance）。
        if (global.game_frame != 0) {
            slowmo_anim_advance();
            return true;
        }
        // 逻辑帧：正常往下跑
        return false;
    }
    // 非缓时：恢复各对象原本的 image_speed
    if (variable_instance_exists(id, "__slow_base_ispeed")) {
        image_speed = __slow_base_ispeed;
    }
    return false;
}

/// @description 缓时下的纯视觉动画补偿：累积到 1 就推一格（2026-09-19 审计后的白名单版）
///
/// 只推两类，其余一概不动（保证不破坏平衡）：
///
///   ① 全局纯视觉计时器 —— 这几个名字在全项目 .gml 里**零玩法引用**，
///      只用来驱动 image_index / image_alpha。复核方式：
///          grep -rn "anim_timer" objects/ scripts/     # 只有动画
///      名单由 2026-09-19 的审计脚本（逐文件判定「是否喂 image_*」+「是否出现在玩法分支」）得出。
///
///   ② 显式 opt-in —— 对象在 Create 里写 `slowmo_anim_timer = true`，
///      表示「本对象的 timer 只用于算 image_index，攻击/状态周期走的是别的变量」。
///      已逐行核实并声明的两个：
///        · obj_card_parent      —— 战场卡牌。其 Step 里 timer 只出现在
///                                  `if timer < current_flash_speed-1 { timer++ } else { image_index++; timer=0 }`
///                                  （攻击周期走 attack_timer）
///        · obj_player_character —— 玩家角色。其 Step 里 timer 只出现在 line 9/10/24
///                                  （`if timer < flash_speed-1 { timer++ } … timer = 0`）
///                                  注意它 Create 里没有 event_inherited，不继承 obj_card_parent，须单独声明。
///      ⚠️ **敌人一律不加**（obj_enemy_parent 及其 171 个后代，含老鼠与 boss）：
///         2026-09-19 用户实测会出 bug。不要因为「timer 看着只喂 image_index」就加回去。
///      ⚠️ 新增 opt-in 前**必须**先逐行确认该对象没有用 timer 做寿命/伤害/状态转移。
function slowmo_anim_advance() {
    if (!variable_instance_exists(id, "__slow_anim_acc")) {
        __slow_anim_acc = 0;
    }
    __slow_anim_acc += SLOWMO_ANIM_SCALE;
    while (__slow_anim_acc >= 1) {
        __slow_anim_acc -= 1;

        // ① 全局纯视觉计时器（零玩法引用）
        if (variable_instance_exists(id, "anim_timer"))    anim_timer    += 1;
        if (variable_instance_exists(id, "land_timer"))    land_timer    += 1;
        if (variable_instance_exists(id, "wake_timer"))    wake_timer    += 1;
        if (variable_instance_exists(id, "appear_timer"))  appear_timer  += 1;
        if (variable_instance_exists(id, "upgrade_timer")) upgrade_timer += 1;
        if (variable_instance_exists(id, "relax_timer"))   relax_timer   += 1;

        // ② opt-in 对象的 timer（只喂 image_index 的那些）
        if (variable_instance_exists(id, "slowmo_anim_timer")) {
            if (variable_instance_exists(id, "timer")) timer += 1;
        }
    }
}
