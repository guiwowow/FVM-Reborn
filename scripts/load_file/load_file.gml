/// @function load_file(file_slot)
/// @desc 加载存档文件到全局变量global.save_data中
/// @param {real} file_slot 存档槽位
function load_file(file_slot) {
	var file_path = "saves/" + "save" + string(file_slot) + ".json"
    // 检查存档文件是否存在
    if (!file_exists(file_path)) {
        // 如果存档不存在，创建初始存档数据
        reset_file(file_slot)
        return true;
    }
    
    // 打开存档文件
    var file = file_text_open_read(file_path);
    if (file == -1) {
        show_debug_message("无法打开存档文件!");
        return false;
    }
    
    // 读取文件内容
    var json_string = "";
    while (!file_text_eof(file)) {
        json_string += file_text_read_string(file);
        file_text_readln(file);
    }
    file_text_close(file);
    
    // 解析JSON字符串
    // ⚠️ 所有字段访问一律用 [$ "键"] 而不是 .键：
    //    json_parse 出来的结构体用点号**赋值**会撞 GMA 的全局 struct 编号（GM1008 编译错），
    //    下面迁移链里到处是赋值，所以统一用 [$ ] 形式（手册 §4 已记过这条）。
    try {
        var _parsed = json_parse(json_string);

        // ---- 结构体检（2026-09-21）----------------------------------------
        // 存档可能被外部改坏（手改、导入半截、写入中断）。缺字段的话后面一路读下去
        // 会在**别处**炸（读 .player.level 之类），报错点离现场很远、极难查。
        // 这里统一先补：**缺什么补什么**，而不是直接弃档。
        //
        // ⚠️ 绝不能要求"字段齐全否则拒绝"：老版本存档天然缺
        //    attires(1.6+) / equipped_cookbook(1.8+) / player.crown_version(1.7+)
        //    —— 那三个正是下面版本迁移链要补的。
        // -------------------------------------------------------------------
        if (!is_struct(_parsed)) {
            show_error_dialog("存档读取失败",
                "存档文件不是有效的对象结构（顶层不是 {}）。\n已重建为新存档。\n\n文件：" + file_path)
            reset_file(file_slot)
            return true;
        }
        var _repaired = save_data_repair(_parsed);
        if (array_length(_repaired) >= 8) {
            // 缺到 8 个以上说明这根本不是一份存档（正常旧档最多缺 3 个）
            show_error_dialog("存档读取失败",
                "存档缺少大量必需字段，已重建为新存档。\n\n缺失：" + string_join_ext(", ", _repaired) + "\n文件：" + file_path)
            reset_file(file_slot)
            return true;
        }
        if (array_length(_repaired) > 0) {
            show_debug_message("存档结构已补齐：" + string_join_ext(", ", _repaired));
        }

        global.save_data = _parsed;
        show_debug_message("存档加载成功!");
		if global.save_data[$ "version"] == 1.0 || global.save_data[$ "version"] == "1.1"|| global.save_data[$ "version"] == "1.2"|| global.save_data[$ "version"] == "1.3"{
			reset_file(file_slot)
		}
		else{
			if global.save_data[$ "version"] == "1.4"{
				if array_get_index(global.save_data[$ "completed_levels"],"cocoa_island_night") != -1{
					unlock_weapon("double_water_gun")
				}
				if array_get_index(global.save_data[$ "completed_levels"],"abyss") != -1{
					unlock_card("chocolate_pult",0,0,5)
				}
				global.save_data[$ "version"] = 1.5
			}
			if global.save_data[$ "version"] == 1.5{
				global.save_data[$ "attires"] = []
				global.save_data[$ "version"] = 1.6
			}
			if global.save_data[$ "version"] == 1.6{
				global.save_data[$ "player"][$ "crown_version"] = "0.0.0"
				global.save_data[$ "version"] = 1.7
			}
			if global.save_data[$ "version"] == 1.7{
				global.save_data[$ "equipped_cookbook"] = [[],[],[]]
				global.save_data[$ "version"] = 1.8
			}
			if global.save_data.version == 1.8{
				if array_get_index(global.save_data.completed_levels,"cheese_castle") != -1{
					unlock_gem("holy_gem")
				}
				global.save_data.version = 1.9
			}
		}
        return true;
    } catch(e) {
        show_debug_message("存档解析错误: " + string(e));
        show_error_dialog("存档读取失败", "存档解析出错，已保留原文件未改动。\n\n" + string(e) + "\n文件：" + file_path)
        return false;
    }
}

/// @function save_data_repair(_d)
/// @desc 存档结构体检：缺必需字段就补默认值（**不弃档**），返回被补过的字段名数组。
///
/// 「必需」= 除版本迁移链负责补的那三个（attires / equipped_cookbook / player.crown_version）以外的
/// 全部顶层字段。那三个**故意不在这里补** —— 补了会让下面的迁移链判断不出老版本。
///
/// @param {Struct} _d json_parse 出来的存档结构体（原地修改）
/// @returns {Array<String>} 被补过的字段名
function save_data_repair(_d) {
    var _fixed = [];

    // ---- player（及其内部字段）----
    if (!is_struct(_d[$ "player"])) {
        _d[$ "player"] = { "gold": 0, "level": 1, "experience": 0, "name": "Player", "total_time": 0 };
        array_push(_fixed, "player");
    } else {
        var _p = _d[$ "player"];
        if (is_undefined(_p[$ "gold"]))       { _p[$ "gold"] = 0;        array_push(_fixed, "player.gold"); }
        if (is_undefined(_p[$ "level"]))      { _p[$ "level"] = 1;       array_push(_fixed, "player.level"); }
        if (is_undefined(_p[$ "experience"])) { _p[$ "experience"] = 0;  array_push(_fixed, "player.experience"); }
        if (is_undefined(_p[$ "name"]))       { _p[$ "name"] = "Player"; array_push(_fixed, "player.name"); }
        if (is_undefined(_p[$ "total_time"])) { _p[$ "total_time"] = 0;  array_push(_fixed, "player.total_time"); }
    }

    // ---- unlocked_items ----
    if (!is_struct(_d[$ "unlocked_items"])) {
        _d[$ "unlocked_items"] = { "max_card_level": 0, "max_skill_level": 0, "max_gem_level": 0,
                                   "max_slot": 5, "max_shape": [], "shovel": "normal",
                                   "elite_unlocked": false, "mario_mouse_killed": false, "arno_killed": false };
        array_push(_fixed, "unlocked_items");
    }

    // ---- equipped_items（含三把武器的子结构）----
    if (!is_struct(_d[$ "equipped_items"])) {
        _d[$ "equipped_items"] = {
            "main_weapon":      { "id": "long_bao_gun", "gems": [] },
            "secondary_weapon": { "id": "",             "gems": [] },
            "super_weapon":     { "id": "",             "gems": [] }
        };
        array_push(_fixed, "equipped_items");
    } else {
        var _eq = _d[$ "equipped_items"];
        var _slots = ["main_weapon", "secondary_weapon", "super_weapon"];
        for (var _si = 0; _si < array_length(_slots); _si++) {
            var _sl = _slots[_si];
            if (!is_struct(_eq[$ _sl])) {
                _eq[$ _sl] = { "id": (_si == 0) ? "long_bao_gun" : "", "gems": [] };
                array_push(_fixed, "equipped_items." + _sl);
            } else {
                if (is_undefined(_eq[$ _sl][$ "id"]))   { _eq[$ _sl][$ "id"] = (_si == 0) ? "long_bao_gun" : ""; array_push(_fixed, "equipped_items." + _sl + ".id"); }
                if (!is_array(_eq[$ _sl][$ "gems"]))    { _eq[$ _sl][$ "gems"] = []; array_push(_fixed, "equipped_items." + _sl + ".gems"); }
            }
        }
    }

    // ---- 顶层数组字段 ----
    var _arrs = ["unlocked_cards", "completed_levels", "inventory", "unlocked_weapons",
                 "unlocked_gems", "saved_decks", "tasks", "completed_tasks"];
    for (var _i = 0; _i < array_length(_arrs); _i++) {
        var _k = _arrs[_i];
        if (!is_array(_d[$ _k])) {
            _d[$ _k] = [];
            array_push(_fixed, _k);
        }
    }

    // ---- version：缺了就当最新版（不能当老版本，否则会走弃档分支）----
    if (is_undefined(_d[$ "version"])) {
        _d[$ "version"] = 1.8;
        array_push(_fixed, "version");
    }
    return _fixed;
}

function reset_file(file_slot){
	//重置到初始存档
	global.save_data = {
            "version": 1.9,
            "player": {
                "gold": 0,
                "level": 1,
                "experience": 0,
				"name":"Player",
				"total_time":0,
				"crown_version":"0.0.0"
            },
            "unlocked_cards": [
                {"id": "small_fire", "level": 0, "shape": 0,"skill":0,"max_level":0,"max_shape":0},
				{"id": "toast_bread", "level": 0, "shape": 0,"skill":0,"max_level":0,"max_shape":0},
				{"id": "xiao_long_bao", "level": 0, "shape": 0,"skill":0,"max_level":0,"max_shape":0},
				{"id": "flour_sack", "level": 0, "shape": 0,"skill":0,"max_level":0,"max_shape":0}
            ],
            "completed_levels": [],
            "inventory": [],
            "unlocked_items": {
                "max_card_level": 0,
                "max_skill_level": 0,
                "max_gem_level": 0,
				"max_slot":5,
				"max_shape":[],
				"shovel":"normal",
				"elite_unlocked":false,
				"mario_mouse_killed":false,
				"arno_killed":false
            },
            "unlocked_weapons": [
                {"id": "long_bao_gun"}
            ],
			"unlocked_gems":[],
			"equipped_items":{
				"main_weapon":{
					"id":"long_bao_gun",
					"gems":[]
				},
				"secondary_weapon":{
					"id":"",
					"gems":[]
				},
				"super_weapon":{
					"id":"",
					"gems":[]
				}
			},
			"saved_decks":[
				{"name":"卡组1","card_id":[]},
				{"name":"卡组2","card_id":[]},
				{"name":"卡组3","card_id":[]},
				{"name":"卡组4","card_id":[]},
				{"name":"卡组5","card_id":[]},
				{"name":"卡组6","card_id":[]} 
			],
			"tasks":[
				{
					"id":"main_level_0",
					"progress":[0],
					"state":"new"
				},
				{
					"id":"card_upgrade_1",
					"progress":[0],
					"state":"new"
				},
				{
					"id":"flame_save_1",
					"progress":[0,0],
					"state":"new"
				},
				{
					"id":"perfect_challenge_1",
					"progress":[0,0,0],
					"state":"new"
				},
				{
					"id":"hardcore_challenge_1",
					"progress":[0,0,0],
					"state":"new"
				}
			],
			"completed_tasks":[],
			"attires":[],
			"equipped_cookbook":[[],[],[]]
        };
	save_file(file_slot)
}