// obj_plant_parent 的 Create 事件
// ========== 基础属性 ==========
name = "未命名植物"
cost = 0
description = ""
cooldown = 0
hp = 100
max_hp = 100
atk = 0
range = 0
attack_type = ATTACK_TYPE.PRODUCER
plant_type = ""
feature_type = "normal"
target_card = "none"
target_type = "normal"
shape = 0
skill = 0
invincible = false
can_shovel_remove = true
is_slowdown = false

// ========== 生产相关 ==========
state = CARD_STATE.IDLE
timer = 0
attack_timer = 0
cycle = 0
origin_cycle = 0
first_produce = 0
first_produce_delay = 0
flame_produce = 0
awake_buff_timer = 0

// ========== 位置信息 ==========
grid_col = -1
grid_row = -1
depth_value = 0
depth_group = 0  // 0=前景, 1=中景, 2=背景

// ========== 动画控制 ==========
image_speed = 0
flash_speed = 6
attack_anim = 0
banding_star_obj = noone
banding_water_obj = noone
banding_sleep_obj = noone
flash_value = 0
idle_anim = 0
ice_timer = 0
frozen_timer = 0
is_frozen = false
awake_anim = 0

// ========== 注册信息 ==========
plant_id = ""  // 植物唯一标识符
current_level = 0  // 当前等级


// ---- 缓时动画补偿 opt-in（2026-09-19）----
// 声明「本对象的 timer 只用于算 image_index，不参与寿命/伤害/状态转移」，
// 于是缓时期间 slowmo_gate() 可以在非逻辑帧单独推进它，让动画比 1/12 的玩法更流畅。
// ⚠️ 新增这个标志前必须先逐行确认 timer 没有兼任玩法用途（见 scripts/slowmo_gate/slowmo_gate.gml 文件头）。
slowmo_anim_timer = true

// 受伤 VM 挂载点用：记录上一帧血量，用于检测「本帧掉血」
pre_hp=-1
