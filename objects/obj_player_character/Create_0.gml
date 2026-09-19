hp = 600
max_hp = hp
grid_row = -1
grid_col = -1
is_placed = false
timer = 0
attack_anim = 6
flash_speed = 6
flash_value = 0
state = CARD_STATE.IDLE
depth_value = 0
depth_offset = 0
plant_type = "normal"
feature_type = "normal"
target_card = "none"
plant_id = "player"
can_shovel_remove = false
invincible = false
hurt_time = 0
cycle = 78
attack_timer = 0
image_xscale = 1.6
image_yscale = 1.6
image_speed = 0
depth = -5000

if card_equipped_attire_id("player")!= -1{
	sprite_index = get_attire_info(card_equipped_attire_id("player")).spr
}

awake_buff_timer = 0

// ---- 缓时动画补偿 opt-in（2026-09-19）----
// 声明「本对象的 timer 只用于算 image_index，不参与寿命/伤害/状态转移」，
// 于是缓时期间 slowmo_gate() 可以在非逻辑帧单独推进它，让动画比 1/12 的玩法更流畅。
// 本对象的 timer 只出现在 Step_0.gml 的 line 9/10/24（`if timer < flash_speed-1 { timer++ } … timer = 0`）
// —— 纯精灵步进，已逐行核实无玩法用途。
// ⚠️ 注意：本对象 Create 里**没有** event_inherited，不会从 obj_card_parent 继承这个标志，
//    所以必须在这里显式写一遍。
slowmo_anim_timer = true
