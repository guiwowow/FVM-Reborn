image_xscale = 1
image_yscale = 1

// 默认状态为关闭
state = false;
image_speed = 0; // 停止动画

// 配置键名（由创建者设置）
config_key = "";
tooltip_text = "";

// ── 缩放回弹状态（2026-10-07 修闪退）─────────────────────────────
// 上游 PR#93 的 Step 事件读这些实例变量，但上游 Create 事件漏了初始化
// （全树 grep bounce_ 只有那个 Step 文件）⇒ 进「设置→操作设置」即
// "Variable obj_setting_toggle.bounce_prev not set before reading it"。
bounce_prev   = state;          // 与创建时的 state 一致 ⇒ 首帧不误触发
bounce_t      = -1;             // -1 = 不在回弹中（>=0 = 回弹帧计数）
bounce_base_x = image_xscale;   // 回弹基准缩放（结束时原样还原）
bounce_base_y = image_yscale;
bounce_frames = 12;             // 回弹时长（帧）≈0.2s
bounce_amount = 0.18;           // 峰值放大比例（1.0 → 1.18 → 1.0）