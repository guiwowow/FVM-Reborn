image_xscale = 1.8
image_yscale = 1.8
image_speed = 0

cookbook_title = "南翔小笼包"
btn_index = 0
desc = ""
spr_index = 0
cookbook_id = "nanxiang_bun"
cookbook_rank = 0

banding_btn = instance_create_depth(x+280,y,depth-1,obj_equipcookbook_btn)

// ── 瀑布流入场状态（动效等级 2）· 默认值兜底 ──────────────────────────────
// 上游 PR#93 的创建方 objects/obj_cookbook_bg/Create_0.gml:39 只写了 wf_t、没写 wf_dur
// ⇒ 本对象 Step_2 读 wf_dur 直接闪退（Variable obj_cookbook_list_btn.wf_dur not set
//    before reading it，2026-10-07 用户报告「点食神谱的详细列表闪退了 动效等级2」）。
// 创建方在动效等级 2 时会把 wf_t 覆盖成负数做逐行延迟；这里给"已完成"的默认值。
wf_dur = 18      // 入场时长（帧）
wf_t   = 18      // 18 = 已完成
wf_off = 0       // 垂直偏移（46 → 0）
wf_a   = 1       // 淡入系数
