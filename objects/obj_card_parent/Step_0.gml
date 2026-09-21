// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
// obj_plant_parent 的 Step 事件
if global.is_paused{
	exit
}
if ice_timer > 0{
	ice_timer--
	is_slowdown = true
}
else{
	is_slowdown = false
}
if frozen_timer > 0{
	frozen_timer--
	is_frozen = true
}
else{
	is_frozen = false
}
if hp <= 0{
	instance_destroy()
}

if flash_value >0{
	
	flash_value -= 10
	
}
if awake_buff_timer > 0{
	awake_buff_timer--
	if state == CARD_STATE.SLEEP{
		if awake_anim > 0{
			state = CARD_STATE.AWAKE
		}
		else{
			state = CARD_STATE.IDLE
		}
	}
}
if state == CARD_STATE.SLEEP && !instance_exists(banding_sleep_obj) && awake_anim == 0{
	banding_sleep_obj = instance_create_depth(x-15,y-20,depth-1,obj_sleep_effect)
	banding_sleep_obj.banding_card_obj = id
}
if instance_exists(banding_sleep_obj){
	banding_sleep_obj.x = x-15
	banding_sleep_obj.y = y-20
	banding_sleep_obj.depth = depth-1
}
if state != CARD_STATE.SLEEP && instance_exists(banding_sleep_obj){
	instance_destroy(banding_sleep_obj)
}

// 计算深度值
//var depth_value = -((y + depth_offset) * 10 + x);
//depth = depth_value - depth_group * 100;



var grid_pos = get_grid_position_from_world(x,y)

if !(variable_instance_exists(id, "platform_grid_lock") && platform_grid_lock) {
    grid_col = grid_pos.col
    grid_row = grid_pos.row
}

// -1 列卡片（左边缘外的传送带/召唤位）：col 是负数或超出列数时按环绕列算深度，
// 否则深度会算到屏幕外（对齐联机版 origin/main）。
if (grid_pos.col > 50) {
	depth = calculate_plant_depth(grid_pos.col - 64 - global.grid_cols, grid_pos.row, plant_type)
} else {
	depth = calculate_plant_depth(grid_pos.col, grid_pos.row, plant_type)
}

// 受伤 VM 挂载点：本帧血量下降 → 触发脚本的 _VM_CARD_DAMAGED
if (pre_hp > hp && buffer_exists(global._VM_CARD_DAMAGED)) {
	global._VM_last_damaged_card = id;
	VM_Execute(global.__vm, global._VM_CARD_DAMAGED, "_VM_CARD_DAMAGED");
}
pre_hp = hp;
if instance_exists(banding_star_obj){
banding_star_obj.depth = depth - 1
}

var water_define_pos_y = clamp(grid_col,0,global.grid_cols - 1)
var water_define_pos_x = clamp(grid_row,0,global.grid_rows - 1)

if !instance_exists(banding_water_obj) && global.grid_terrains[water_define_pos_x][water_define_pos_y].type == "water" {
	if plant_type == "lilypad" || (feature_type == "water" && plant_type == "normal"){
		banding_water_obj = instance_create_depth(x,y,depth+5,obj_in_water_effect)
		banding_water_obj.banding_card_obj = id
	}
}
if instance_exists(banding_water_obj) && global.grid_terrains[water_define_pos_x][water_define_pos_y].type != "water"{
	instance_destroy(banding_water_obj)
}

if is_frozen{
	exit
}
// 动画计时器
var current_flash_speed = flash_speed
if is_slowdown{
	current_flash_speed *= 2
}
if is_slowdown {
    cycle = origin_cycle * 2;    
}
else{
	cycle = origin_cycle
}
if timer < current_flash_speed - 1 {
    timer++;
} else {
    switch (state) {
        case CARD_STATE.IDLE:
            if image_index < idle_anim image_index++;
            else image_index = 0;
            break;
            
        case CARD_STATE.ATTACK:
            if (image_index >= (idle_anim+1) && image_index <= (idle_anim) + attack_anim) image_index++;
            else image_index = (idle_anim+1);
            break;
		
    }
    timer = 0;
}

