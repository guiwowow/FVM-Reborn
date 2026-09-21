// 2 倍速：维持 application_surface 分辨率（切房间/切倍速后自动纠正；尺寸没变时零开销）
speed_up_surface_fit();

// 2 倍速：每帧把实例变量对齐到全局真值。
// 为什么需要：speed_up_probe_tick 会在**面板被锁回 60Hz 时异步撤回** 2x（只改
// global.speed_up_active），而按钮/HUD 读的是 _battle.speed_up（Draw_0.gml:44）。
// 不同步的话会出现「HUD 显示加速:开，实际只有 60 帧」。放在 slowmo_gate() 之前，
// 保证被缓时门控 exit 的帧也会纠正。
speed_up = global.speed_up_active;

// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
if global.is_paused{
	exit
}


if global.lose_focus_pause{
	if !window_has_focus() && !global.is_paused{
		global.is_paused = true
	}
}

battle_time ++

// obj_controller STEP 事件
if global.debug{
	if keyboard_check_pressed(ord("M")){
		var grid_pos = get_grid_position_from_world(mouse_x,mouse_y)
		var inst = instance_create_depth(grid_pos.x,grid_pos.y+38,0,obj_sawblade_mouse)
		inst.grid_row = grid_pos.row
		inst.grid_col = grid_pos.col
		inst.frozen_timer = 0000
	}
	if keyboard_check_pressed(ord("N")){
		var enemy_row = irandom_range(0,global.grid_rows-1)
		var enemy_pos = get_world_position_from_grid(10,enemy_row)
		instance_create_depth(enemy_pos.x-80,enemy_pos.y+33,-200,obj_blonde_mary)
		boss_count++
		//var grid_pos = get_grid_position_from_world(mouse_x,mouse_y)
		//var inst = instance_create_depth(grid_pos.x,grid_pos.y+38,0,obj_mario_mouse)
		//inst.grid_row = grid_pos.row
		//inst.grid_col = grid_pos.col
		//inst.frozen_timer = 0000
	}
	if keyboard_check_pressed(ord("L")){
		var grid_pos = get_grid_position_from_world(mouse_x,mouse_y)
		var inst = instance_create_depth(grid_pos.x,grid_pos.y+38,0,obj_war_god_soldier)
		inst.grid_row = grid_pos.row
		inst.grid_col = grid_pos.col
		inst.frozen_timer = 0000
	}
	if keyboard_check_pressed(ord("K")){
		var grid_pos = get_grid_position_from_world(mouse_x,mouse_y)
		var inst = instance_create_depth(grid_pos.x,grid_pos.y+38,0,obj_war_god_summon)
		inst.grid_row = grid_pos.row
		inst.grid_col = grid_pos.col
		inst.frozen_timer = 0000
	}
	if keyboard_check_pressed(ord("B")){
		var grid_pos = get_grid_position_from_world(mouse_x,mouse_y)
		var inst = instance_create_depth(grid_pos.x,grid_pos.y+38,0,obj_conch_mouse)
		inst.grid_row = grid_pos.row
		inst.grid_col = grid_pos.col
		inst.frozen_timer = 0000
	}
	if keyboard_check_pressed(ord("J")){
		global.is_paused = true
		global.game_over = true
		var inst = instance_create_depth(room_width/2,room_height/2,-3001,obj_game_over)
		inst.sprite_index = spr_win
		audio_play_sound(snd_win,0,0)
	}

	if keyboard_check_pressed(ord("R")){
		var grid_pos = get_grid_position_from_world(mouse_x, mouse_y);
		if (grid_pos.col >= 0 && grid_pos.col < global.grid_cols && 
	        grid_pos.row >= 0 && grid_pos.row < global.grid_rows) {
    
		    var new_plant = instance_create_depth(grid_pos.x, grid_pos.y, 0,obj_small_fire);
			var depth_value = calculate_plant_depth(grid_pos.col, grid_pos.row, new_plant.plant_type);
			card_created(new_plant, grid_pos.col, grid_pos.row);
			new_plant.depth = depth_value
			new_plant.flame_produce = 15000
			new_plant.ice_timer = 600
			instance_create_depth(grid_pos.x,grid_pos.y,-2,obj_place_effect)        
			audio_play_sound(snd_place1,0,0)
		}
	}

	if keyboard_check_pressed(ord("A")){
		var grid_pos = get_grid_position_from_world(mouse_x, mouse_y);
		if (grid_pos.col >= 0 && grid_pos.col < global.grid_cols && 
	        grid_pos.row >= 0 && grid_pos.row < global.grid_rows) {
    
		    var new_plant = instance_create_depth(grid_pos.x, grid_pos.y, 0,obj_xiao_long_bao);
			var depth_value = calculate_plant_depth(grid_pos.col, grid_pos.row, new_plant.plant_type);
			card_created(new_plant, grid_pos.col, grid_pos.row);
			new_plant.depth = depth_value
			new_plant.atk = 90
			new_plant.ice_timer = 600
			new_plant.frozen_timer = 240
			instance_create_depth(grid_pos.x,grid_pos.y,-2,obj_place_effect)        
			audio_play_sound(snd_place1,0,0)
		}
	}
}

//计时器逻辑
if global.level_file.time_limit != 0 && time_limit == -1{
	time_limit = global.level_file.time_limit * 60
}
if time_limit > 0{
	if !timer_pause{
		time_limit --
	}
	if time_limit <= 0{
		global.is_paused = true
		global.game_over = true
		instance_create_depth(room_width/2,room_height/2,-3001,obj_game_over)
		audio_play_sound(snd_lose,0,0)
	}
}


if keyboard_check_pressed(vk_shift) || keyboard_check_pressed(vk_lshift){
	speed_up = not speed_up
	speed_up = speed_up_set(speed_up)   // 返回**实际生效值**：60Hz 面板上开 2x 会被拒绝并弹提示
}

// ---- VM 地图脚本：波次/子波事件钩子（从联机版移植）--------------------
// 与波次**推进**逻辑无关：推进在下面 _VM_wave_auto 那几块里，
// 这里只负责在检测到波次/子波编号变化时，触发脚本的 _VM_WAVE_* / _VM_SUBWAVE_* 块。
// 内置关卡没有 .bin → 所有 buffer_exists 为假 → 本段零开销。
if (global._VM_battle_start_done) {
    if (global._VM_prev_subwave != current_subwave || global._VM_prev_wave != current_wave) {
        if (buffer_exists(global._VM_SUBWAVE_END) && current_subwave != 0) VM_Execute(global.__vm, global._VM_SUBWAVE_END, "_VM_SUBWAVE_END");
        global._VM_prev_subwave = current_subwave;
        if (buffer_exists(global._VM_SUBWAVE_START)) VM_Execute(global.__vm, global._VM_SUBWAVE_START, "_VM_SUBWAVE_START");
    }
    if (global._VM_prev_wave != current_wave) {
        if (buffer_exists(global._VM_WAVE_END) && current_wave != 0) VM_Execute(global.__vm, global._VM_WAVE_END, "_VM_WAVE_END");
        global._VM_prev_wave = current_wave;
        if (buffer_exists(global._VM_WAVE_START)) VM_Execute(global.__vm, global._VM_WAVE_START, "_VM_WAVE_START");
    }
}

// _VM_wave_auto：脚本可用 VM_SetWave 关掉自动推进，完全接管波次（默认 true）。
if global._VM_wave_auto && battle_time >= (global.level_file.first_wave_delay * 60) && level_stage == "ready" {
    
    level_stage = "pre"
    audio_play_sound(snd_mouse_wave_attack, 0, 0)
    
    enemy_subwave_summon()
    
    current_subwave += 1;
}
var current_total_subwaves = 0
var wave_data = {}
if current_wave < total_wave{
	current_total_subwaves = array_length(global.level_file.waves[current_wave].subwaves)
	wave_data = global.level_file.waves[current_wave]
}
else{
	current_total_subwaves = array_length(global.level_file.waves[current_wave-1].subwaves)
	wave_data = global.level_file.waves[current_wave-1]
}

if wave_data.boss_wave && level_stage != "boss" && global.save_data.unlocked_items.elite_unlocked && wave_timer == 1{
	level_stage = "boss"
	var enemy_row = irandom_range(0,global.grid_rows-1)
	var enemy_pos = get_world_position_from_grid(10,enemy_row)
	global._mod_pending_enemy_id = wave_data.boss  // mod 敌人创建前写入 pending id
	var boss_inst = instance_create_depth(enemy_pos.x-80,enemy_pos.y+30,-200,global.enemy_map[? wave_data.boss]._obj)
	boss_count ++
	if is_real(global.level_file.version){
		boss_inst.hp *= wave_data.boss_1_hp_modify
		boss_inst.maxhp *= wave_data.boss_1_hp_modify
		if wave_data.boss2 != ""{
			var enemy_row_2 = irandom_range(0,global.grid_rows-1)
			var enemy_pos_2 = get_world_position_from_grid(10,enemy_row_2)
			global._mod_pending_enemy_id = wave_data.boss2  // mod 敌人创建前写入 pending id
			var boss_2_inst = instance_create_depth(enemy_pos_2.x-80,enemy_pos_2.y+30,-200,global.enemy_map[? wave_data.boss2]._obj)
			boss_2_inst.hp *= wave_data.boss_2_hp_modify
			boss_2_inst.maxhp *= wave_data.boss_2_hp_modify
			boss_count ++
		}
	}
	with obj_battle_music_controller{
		new_battle_music = global.level_data.boss_music
		event_user(0)
	}
}
if wave_timer <= 0 && level_stage == "pre" && global._VM_wave_auto{
	if(global.save_data.unlocked_items.elite_unlocked) || !global.save_data.unlocked_items.elite_unlocked && current_wave < global.level_file.elite_wave{
		if current_wave < total_wave{
			enemy_subwave_summon()
		}
		if current_subwave < current_total_subwaves-1{
			current_subwave+=1
		}
		else if current_wave < total_wave{
			current_wave += 1
			current_subwave = 0
			audio_play_sound(snd_mouse_wave_attack,0,0)
			instance_create_depth(room_width/2,room_height/2,-300,obj_huge_wave_text)
		}
	}
}
if wave_timer <= 0 && level_stage == "boss" && global._VM_wave_auto{
	enemy_subwave_summon()
	if current_subwave < current_total_subwaves-1{
		current_subwave+=1
	}
	else{
		current_subwave = 0
	}
}

// =====================================================================
// VM 地图脚本：帧循环钩子（从联机版移植，2026-09-20）
// =====================================================================
// 这些块由地图作者写进 .bin，解释器在这里按节奏触发。
// 内置关卡没有 .bin → buffer_exists 全为假 → 整段零开销。
// battle_time 是战斗内帧计数（不是游戏总帧数），定时块按它取模。
// =====================================================================
if (buffer_exists(global._VM_FRAME)) {
    if (battle_time mod 60 == 0) vm_trace("_VM_FRAME @" + string(battle_time))
    VM_Execute(global.__vm, global._VM_FRAME, "_VM_FRAME");
}
// 战斗平稳跑满 120 帧 → 记一次"未崩溃"。此后即使再崩，也能从追踪看出是在哪一段。
if (battle_time == 120) vm_trace_end()

// ===== 临时诊断（2026-09-21）：脚本自定义资源加载与实验室目录清单 =====
// 背景：地图脚本的自定义贴图在安卓上加载不到，而 release 包的沙盒 adb 读不到
//   （SDK35 / 非 debuggable / 内部存储 Permission denied / 外部目录为空），
//   唯一取证通道是游戏自己的弹窗。进图 30 帧后弹出，此刻脚本的资源加载已全部发生。
//   用完即删。
if (battle_time == 30 && !variable_global_exists("_vm_diag_shown")) {
    global._vm_diag_shown = true
    var _d = "[脚本资源诊断]" + chr(10)
    _d += "json=" + string(global._file_cache_json_path) + chr(10)
    if (variable_global_exists("_vm_bin_path")) {
        _d += "bin=" + string(global._vm_bin_path) + " 存在=" + string(file_exists(global._vm_bin_path)) + chr(10)
    }
    _d += chr(10) + "--- 脚本请求的资源（候选路径 + exists）---" + chr(10)
    if (variable_global_exists("_vm_spr_diag")) {
        _d += string(global._vm_spr_diag)
    } else {
        _d += "(脚本没有请求任何资源)" + chr(10)
    }
    _d += chr(10) + "--- laboratory/ 目录实际文件 ---" + chr(10)
    var _n = 0
    var _f = file_find_first("laboratory/*", fa_directory | fa_archive | fa_readonly)
    while (_f != "" && _n < 60) {
        if (_f != "." && _f != "..") {
            _d += "  " + _f + chr(10)
            _n++
        }
        _f = file_find_next()
    }
    file_find_close()
    if (_n == 0) _d += "  (空)" + chr(10)
    _d += "共 " + string(_n) + " 项（最多列 60）"
    // 贴图槽状态：脚本用 VM_SetDrawSlot 写入，槽里 sprite==noone 就不画
    _d += chr(10) + chr(10) + "--- 贴图槽状态 ---" + chr(10)
    var _used = 0
    for (var _si = 0; _si < 64; _si++) {
        var _sl = global.map_draw_slots[_si]
        if (_sl.sprite != noone && _sl.sprite != -1) {
            _d += "  后层槽" + string(_si) + " spr=" + string(_sl.sprite) + " @" + string(_sl.x) + "," + string(_sl.y) + " a=" + string(_sl.alpha) + chr(10)
            _used++
        }
        var _sf = global.map_draw_slots_front[_si]
        if (_sf.sprite != noone && _sf.sprite != -1) {
            _d += "  前层槽" + string(_si) + " spr=" + string(_sf.sprite) + " @" + string(_sf.x) + "," + string(_sf.y) + " a=" + string(_sf.alpha) + chr(10)
            _used++
        }
        if (_used > 20) break
    }
    if (_used == 0) _d += "  (全部 64+64 个槽都是空的 —— 脚本没有设置任何绘制槽)" + chr(10)
    _d += "非空槽数=" + string(_used)
    show_error_dialog("脚本资源诊断", _d)
}
// 鼠标左/右键按下
if (buffer_exists(global._VM_MOUSE_LEFT) && mouse_check_button_pressed(mb_left)) {
    VM_Execute(global.__vm, global._VM_MOUSE_LEFT, "_VM_MOUSE_LEFT");
}
if (buffer_exists(global._VM_MOUSE_RIGHT) && mouse_check_button_pressed(mb_right)) {
    VM_Execute(global.__vm, global._VM_MOUSE_RIGHT, "_VM_MOUSE_RIGHT");
}
// 任意键按下（键码存 global._VM_last_key 供脚本读取）
if (buffer_exists(global._VM_KEY_PRESSED) && keyboard_check_pressed(vk_anykey)) {
    global._VM_last_key = keyboard_lastkey;
    VM_Execute(global.__vm, global._VM_KEY_PRESSED, "_VM_KEY_PRESSED");
}
// 周期定时块
if (battle_time mod 5  == 0 && buffer_exists(global._VM_TIMER_5f))  { VM_Execute(global.__vm, global._VM_TIMER_5f,  "_VM_TIMER_5f"); }
if (battle_time mod 10 == 0 && buffer_exists(global._VM_TIMER_10f)) { VM_Execute(global.__vm, global._VM_TIMER_10f, "_VM_TIMER_10f"); }
if (battle_time mod 15 == 0 && buffer_exists(global._VM_TIMER_15f)) { VM_Execute(global.__vm, global._VM_TIMER_15f, "_VM_TIMER_15f"); }
if (battle_time mod 30 == 0 && buffer_exists(global._VM_TIMER_30f)) { VM_Execute(global.__vm, global._VM_TIMER_30f, "_VM_TIMER_30f"); }
if (battle_time mod 60 == 0 && buffer_exists(global._VM_TIMER_60f)) { VM_Execute(global.__vm, global._VM_TIMER_60f, "_VM_TIMER_60f"); }

// =====================================================================
// 敌人网格统计 + BOSS 状态变化钩子（2026-09-20 从联机版移植）
// =====================================================================
// 两件事：
//   ① 每帧按网格重建 6 类敌人的**前缀和**数组（global.has_enemy_*），
//      VM 脚本的「某行有没有敌人」查询（VM_GetEnemyCount 系列）依赖它。
//      没有这段时 VM 里那些查询会走防御分支返回 0（不崩，但功能缺失）。
//   ② BOSS 状态变化时触发 _VM_BOSS_STATE_CHANGE 事件块。
// 开销：size = grid_rows × (grid_cols + 2) ≈ 千级数组，每帧 6 次遍历 + 一次 with 敌人循环。
//      比联机版多了这段，但它是 VM 查询能力的必要条件（联机版同样每帧跑）。
// =====================================================================
var _egs_size = global.grid_rows * (global.grid_cols + 2);
if (!variable_global_exists("has_enemy_normal") || array_length(global.has_enemy_normal) != _egs_size) {
	global.has_enemy_normal      = array_create(_egs_size, 0);
	global.has_enemy_obstacle    = array_create(_egs_size, 0);
	global.has_enemy_diver       = array_create(_egs_size, 0);
	global.has_enemy_air         = array_create(_egs_size, 0);
	global.has_enemy_dance       = array_create(_egs_size, 0);
	global.has_enemy_underground = array_create(_egs_size, 0);
	global.enemy_array = array_create(_egs_size);
	for (var _egs_i = 0; _egs_i < _egs_size; _egs_i++) {
		global.enemy_array[_egs_i] = [];
	}
}
if (!variable_global_exists("enemy_array_left") || array_length(global.enemy_array_left) != global.grid_rows) {
	global.enemy_array_left = array_create(global.grid_rows);
	for (var _egs_i = 0; _egs_i < global.grid_rows; _egs_i++) {
		global.enemy_array_left[_egs_i] = [];
	}
}

for (var _egs_i = 0; _egs_i < _egs_size; _egs_i++) {
	global.has_enemy_normal[_egs_i]      = 0;
	global.has_enemy_obstacle[_egs_i]    = 0;
	global.has_enemy_diver[_egs_i]       = 0;
	global.has_enemy_air[_egs_i]         = 0;
	global.has_enemy_dance[_egs_i]       = 0;
	global.has_enemy_underground[_egs_i] = 0;
	array_resize(global.enemy_array[_egs_i], 0);
}
for (var _egs_i = 0; _egs_i < global.grid_rows; _egs_i++) {
	array_resize(global.enemy_array_left[_egs_i], 0);
}
var _egs_stride = global.grid_cols + 2;

with obj_enemy_parent {
	if (grid_row >= 0 && grid_row < global.grid_rows && grid_col >= 0 && grid_col < _egs_stride) {
		var _egs_idx = grid_row * _egs_stride + grid_col;
		switch (target_type) {
			case "normal":      global.has_enemy_normal[_egs_idx]      += 1; break;
			case "obstacle":    global.has_enemy_obstacle[_egs_idx]    += 1; break;
			case "diver":       global.has_enemy_diver[_egs_idx]       += 1; break;
			case "air":         global.has_enemy_air[_egs_idx]         += 1; break;
			case "dance":       global.has_enemy_dance[_egs_idx]       += 1; break;
			case "underground": global.has_enemy_underground[_egs_idx] += 1; break;
		}
		array_push(global.enemy_array[_egs_idx], id);
	}
	if (grid_row >= 0 && grid_row < global.grid_rows && grid_col < 0) {
		array_push(global.enemy_array_left[grid_row], id);
	}

	// ---- VM Hook：BOSS 状态变化 ----
	if (is_boss == false) continue;
	if (pre_state == state) continue;
	if (buffer_exists(global._VM_BOSS_STATE_CHANGE)) {
		global._VM_last_boss_state_change_id = id;
		global._VM_last_boss_old_state = pre_state;
		global._VM_last_boss_new_state = state;
		VM_Execute(global.__vm, global._VM_BOSS_STATE_CHANGE, "_VM_BOSS_STATE_CHANGE");
	}
	pre_state = state;
}

// 前缀和：让 VM 能用 O(行数) 查出「第 r 行第 c 列之前有几只某类敌人」
for (var _egs_i = 0; _egs_i < global.grid_rows; _egs_i++) {
	var _egs_base = _egs_i * _egs_stride;
	for (var _egs_j = 1; _egs_j < _egs_stride; _egs_j++) {
		global.has_enemy_normal[_egs_base + _egs_j]      += global.has_enemy_normal[_egs_base + _egs_j - 1];
		global.has_enemy_obstacle[_egs_base + _egs_j]    += global.has_enemy_obstacle[_egs_base + _egs_j - 1];
		global.has_enemy_diver[_egs_base + _egs_j]       += global.has_enemy_diver[_egs_base + _egs_j - 1];
		global.has_enemy_air[_egs_base + _egs_j]         += global.has_enemy_air[_egs_base + _egs_j - 1];
		global.has_enemy_dance[_egs_base + _egs_j]       += global.has_enemy_dance[_egs_base + _egs_j - 1];
		global.has_enemy_underground[_egs_base + _egs_j] += global.has_enemy_underground[_egs_base + _egs_j - 1];
	}
}

if global.debug{
	if keyboard_check_pressed(ord("V")){
		if level_stage == "ready"{
			battle_time = (global.level_file.first_wave_delay * 60)
		}
		if current_subwave < current_total_subwaves{
			current_subwave+=1
		}
		else if current_wave == total_wave-1{
			global.is_paused = true
			global.game_over = true
			var inst = instance_create_depth(room_width/2,room_height/2,-3001,obj_game_over)
			inst.sprite_index = spr_win
			audio_play_sound(snd_win,0,0)
		}
		else if current_wave < total_wave{
			current_wave += 1
			current_subwave = 0
		}
	}

	// 自动标定自检（G 键，仅调试模式）：强制扫描当前地图贴图，与人工校准表逐条对比，
	// 结果写 autocalib_check.txt + show_error_dialog 弹窗（真机取回文本的唯一通道）。
	// 注意：global.debug 仅在 obj_game_init/Create_0 置 0，release 包上本块不会执行。
	if keyboard_check_pressed(ord("G")){
		autocalib_selftest_report([global.level_data.level_sprite], 4);
	}
}