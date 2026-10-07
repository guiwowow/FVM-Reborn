image_xscale = 1.8
image_yscale = 1.8
image_speed = 0

btn_index = 0
btn_text = "1-1"
level_index = 0

is_unlocked = false

// ── 瀑布流入场状态（动效等级 2）· 默认值兜底 ──────────────────────────────
// 真实创建方 objects/obj_tower_cake_bg/Create_0.gml:64 写了 wf_y0 / wf_dur / wf_t；
// 这里兜底，避免以后新增创建点漏写字段（PR#93 同款缺陷已造成 2 次闪退）。
wf_y0  = y       // 入场基准 y（创建方会覆盖）
wf_dur = 18      // 入场时长（帧）
wf_t   = 18      // 18 = 已完成
