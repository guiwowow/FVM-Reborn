/// @function plant_created(plant_inst, col, row)
/// @description 当植物创建时调用，更新网格数据
/// @param {instance} plant_inst 植物实例
/// @param {real} col 网格列
/// @param {real} row 网格行
function card_created(plant_inst, col, row) {
    // 获取该网格的植物列表
    // VM 等级上限：地图脚本用 VM_SetCardLevelCap() 限制卡片星级，超过则压到上限。
    // 无脚本时 _VM_card_level_cap = -1 → 整段跳过。
    if (global._VM_card_level_cap >= 0) {
        var _lv = variable_instance_get(plant_inst, "current_level") ?? 0;
        if (_lv > global._VM_card_level_cap) {
            variable_instance_set(plant_inst, "current_level", global._VM_card_level_cap);
        }
    }

    // ⚠️ 2026-09-21 崩溃修复：调用方可能传越界列行（平台把卡片/幻换鸡带出画面时，
    //    obj_magic_chicken/Step_0 按平台 span 算出的 logical_col/row 会落到网格外；
    //    地图脚本也能给越界坐标），而 ds_grid_get **不做边界检查** = 原生硬崩
    //    （真机实测 exit-info reason=5 APP CRASH(NATIVE) status=11 = SIGSEGV）。
    //    按网格真实尺寸（grid_cols+64 × grid_rows+64，见 obj_battle/Create_0.gml:140-143）夹紧。
    //    注：同族的 card_destroyed.gml:14、can_place_at_position.gml:12 本来就有守卫，这里补上。
    col = clamp(col, 0, ds_grid_width(global.grid_plants) - 1);
    row = clamp(row, 0, ds_grid_height(global.grid_plants) - 1);
    var plant_list = ds_grid_get(global.grid_plants, col, row);
    
    // 添加新植物到列表
    ds_list_add(plant_list, plant_inst);
    
    // 设置植物的网格位置
    plant_inst.grid_col = col;
    plant_inst.grid_row = row;
    
    // 更新植物的深度偏移（根据层级）
    plant_inst.depth_offset = ds_list_size(plant_list) * 5;
    
    // 更新所有植物的深度偏移
	sort_plants_in_grid(col, row)

	// VM Hook：卡片创建（从联机版移植）。入队而非直接执行，
	// 由 obj_event_manager 帧尾统一 VM_FlushHooks() 触发，保证同一帧的确定时机。
	global._VM_last_created_card = plant_inst.id;
	if (buffer_exists(global._VM_CARD_CREATED)) VM_QueueHook(global._VM_CARD_CREATED, "card", plant_inst.id);
}  