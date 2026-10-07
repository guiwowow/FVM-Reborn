image_xscale = 1.8
image_yscale = 1.8
image_speed = 0

task_title = "冒险家的第一战"
btn_index = 0
state = "new"

// ── 瀑布流入场状态（动效等级 2）· 默认值兜底 ──────────────────────────────
// 上游 PR#93 的创建方 objects/obj_task_bg/Create_0.gml:71 只写了 wf_t、没写 wf_dur
// ⇒ 本对象 Draw_0.gml:3 读 wf_dur 直接闪退（同食神谱那起，2026-10-07）。
// 创建方在动效等级 2 时会把 wf_t 覆盖成负数做逐行延迟；这里给"已完成"的默认值。
wf_dur = 18      // 入场时长（帧）
wf_t   = 18      // 18 = 已完成
wf_off = 0       // 垂直偏移（46 → 0）
wf_a   = 1       // 淡入系数
