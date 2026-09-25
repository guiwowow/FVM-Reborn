function init_native_log() {
    var _local_log_file = global.native_util.get_path_in_local_appdata("\\FVM_Reborn\\native\\latest.log")
	var _error_code = native_set_native_log_file_path(_local_log_file)
	if (_error_code != 0) {
        global.native_util.show_error(_error_code, "设置日志路径失败")
	}

}

function move_files () {
    var _local_folder = global.native_util.get_path_in_local_appdata("\\FVM_Reborn")
    var _saves_old = global.native_util.get_path_in_local_appdata("\\FVM_Reborn\\美食大战老鼠_重生\\saves")
    var _saves_new = global.native_util.get_path_in_local_appdata("\\FVM_Reborn\\saves")
    var _save_folder_new_exists = native_folder_exists(_saves_new)
    var _save_folder_old_exists = native_folder_exists(_saves_old)
    if ((_save_folder_new_exists == 0) && (_save_folder_old_exists == 1)) {
        var _copy_result = native_copy_folder(_saves_old, _local_folder)
        if (_copy_result == 0) {
            show_message_async("存档已自动迁移到[" + _saves_new + "]")
        } else {
            global.native_util.show_error(_copy_result, "存档迁移失败")
        }
    }

    var _local_laboratory = global.native_util.transfer_path_to_windows(working_directory + "laboratory")
    var _local_laboratory_exists = native_folder_exists(_local_laboratory)
    if (_local_laboratory_exists == 1) {
        var _lab_copy_result = native_copy_folder(_local_laboratory, _local_folder)
        if (_lab_copy_result != 0) {
            global.native_util.show_error(_lab_copy_result, "实验室目录迁移失败")
        } else {
            var _lab_delete_result = native_delete_folder(_local_laboratory)
            if (_lab_delete_result != 0) {
                global.native_util.show_error(_lab_delete_result, "旧实验室目录删除失败")
            }
        }
    }
}

global.level = 1
global.menu_screen = true
global.map_name = "美味岛"
global.map_id = "delicious_town"
global.level_id = ""
global.level_file = {}
global.level_name = "曲奇岛"
global.level_data = {}
global.debug = 0
global.laboretory_room = false
global.game_version = "2.4.1"
global.tower_level_click = false
global.tower_cake_page = 1
Music_Init()

global.laboratory_manager = new LaboratoryManager()
global.laboratory_manager.init()
global.gui_stack = new GuiStack()
global.native_util = new NativeUtil()

init_native_log()
move_files()

// 初始化全局键位映射
global.keybind_map = ds_map_create();
// 定义所有快捷键配置
global.keybind_config = [
    {"name": "铲子", "default1": vk_tab, "tooltip": ""},
    {"name": "卡槽1", "default1": ord("1"), "tooltip": ""},
    {"name": "卡槽2", "default1": ord("2"), "tooltip": ""},
    {"name": "卡槽3", "default1": ord("3"), "tooltip": ""},
    {"name": "卡槽4", "default1": ord("4"), "tooltip": ""},
    {"name": "卡槽5", "default1": ord("5"), "tooltip": ""},
    {"name": "卡槽6", "default1": ord("6"), "tooltip": ""},
    {"name": "卡槽7", "default1": ord("7"), "tooltip": ""},
    {"name": "卡槽8", "default1": ord("8"), "tooltip": ""},
    {"name": "卡槽9", "default1": ord("9"), "tooltip": ""},
    {"name": "卡槽10", "default1": ord("0"), "tooltip": ""},
    {"name": "卡槽11", "default1": ord("Q"), "tooltip": ""},
    {"name": "卡槽12", "default1": ord("W"), "tooltip": ""},
	{"name": "卡槽13", "default1": ord("E"), "tooltip": ""},
    {"name": "卡槽14", "default1": ord("R"), "tooltip": ""},
    {"name": "卡槽15", "default1": ord("T"), "tooltip": ""},
    {"name": "卡槽16", "default1": ord("Y"), "tooltip": ""},
    {"name": "卡槽17", "default1": ord("A"), "tooltip": ""},
    {"name": "卡槽18", "default1": ord("S"), "tooltip": ""},
	{"name": "卡槽19", "default1": ord("D"), "tooltip": ""},
    {"name": "卡槽20", "default1": ord("F"), "tooltip": ""},
    {"name": "卡槽21", "default1": ord("G"), "tooltip": ""}
];
//window_set_caption("FVM:Reborn")
// 初始化全局设置（如果不存在配置文件）
if (!file_exists("config.ini")) {
    ini_open("config.ini");
    ini_write_bool("settings", "screen_shake", true);
    ini_write_bool("settings", "screen_flash", true);
	ini_write_bool("settings", "fullscreen", false);
	ini_write_real("settings", "music_volume", 0.7);
	ini_write_real("settings", "sound_volume", 0.7);
	ini_write_bool("settings", "quick_placement", false);
	ini_write_bool("settings", "replace_placement", false);
	ini_write_bool("settings", "card_hpbar", false);
	ini_write_bool("settings", "enemy_hpbar", false);
	ini_write_bool("settings", "tex_fliter", true);
	ini_write_real("settings", "difficulty", 1)
	ini_write_bool("settings", "borderless_window", true);
	ini_write_real("settings", "save_slot", 0)
	ini_write_bool("settings", "lose_focus_pause", true)
	ini_open("config.ini");
    for (var i = 0; i < array_length(global.keybind_config); i++) {
        var kb = global.keybind_config[i];
        ini_write_real("keybinds", kb.name, kb.default1);
    }
    ini_close();
}
// 初始化全局音量变量
global.music_volume_before_mute = 0.7;
global.sound_volume_before_mute = 0.7;

// 读取配置到全局变量
ini_open("config.ini");
global.screen_shake = ini_read_bool("settings", "screen_shake", true);
global.screen_flash = ini_read_bool("settings", "screen_flash", true);
global.fullscreen = ini_read_bool("settings", "fullscreen", false);
global.music_volume = ini_read_real("settings", "music_volume", 0.7);
global.sound_volume = ini_read_real("settings", "sound_volume", 0.7);
global.quick_placement = ini_read_bool("settings", "quick_placement", false);
global.replace_placement = ini_read_bool("settings", "replace_placement", false);
global.card_hpbar = ini_read_bool("settings", "card_hpbar", false);
global.enemy_hpbar = ini_read_bool("settings", "enemy_hpbar", false);
global.tex_fliter = ini_read_bool("settings", "tex_fliter", true);
global.difficulty = ini_read_real("settings", "difficulty", 1)
global.borderless_window = ini_read_bool("settings", "borderless_window", true);
global.save_slot = ini_read_real("settings", "save_slot", 0)
global.lose_focus_pause = ini_read_bool("settings", "lose_focus_pause", true);
global.ime_block = ini_read_bool("settings", "ime_block", true); // 输入法屏蔽开关（个别输入法环境异常时可关）
// 兼容旧配置：键缺失时补写，玩家可手改 %LOCALAPPDATA%\FVM_Reborn\config.ini 关闭
if (ini_read_string("settings", "ime_block", "") == "") {
    ini_write_bool("settings", "ime_block", true);
}
for (var i = 0; i < array_length(global.keybind_config); i++) {
	    var kb = global.keybind_config[i];
	    var key_val = ini_read_real("keybinds", kb.name, kb.default1);
	    global.keybind_map[? kb.name] = key_val;
}



ini_close();
audio_group_set_gain(music,global.music_volume,0)
audio_group_set_gain(sound,global.sound_volume,0)
window_set_fullscreen(global.fullscreen)
gpu_set_tex_filter(global.tex_fliter)
window_enable_borderless_fullscreen(global.borderless_window)

// 设置初始静音状态
global.music_volume_before_mute = global.music_volume > 0 ? global.music_volume : 0.7;
global.sound_volume_before_mute = global.sound_volume > 0 ? global.sound_volume : 0.7;

show_debug_message(working_directory)

// 屏蔽输入法（IME）：游戏内全程中文候选框不弹出
if (global.ime_block && native_disable_ime != undefined) {
    native_disable_ime(window_handle());
}

// ═══ 行锁定命中扫描 ═══════════════════════════════════════════════════════════
// 三线酒架弹与水管弹只可能命中与自己同一行的敌人（原碰撞事件的守卫是
// row == other.grid_row）。引擎的成对检测不做这个筛选，要拿每颗子弹跟场上全部敌人
// 逐一比对，代价是【子弹数 × 敌人数】。这里改为每帧先把敌人按格子建一次索引，
// 再对每颗子弹只在它那一行里取候选，对候选做与原来完全相同的 instance_place
// 精确掩码判定。命中判定不变（同一个行条件、同一个 can_hit、同一套像素掩码），
// 参与判定的敌人数量从全场降到一行，代价随子弹数线性增长、与敌人数无关。
global.hu_cells = [];   // 格子桶：hu_cells[row * stride + col] = 该格的敌人 id 列表

global.hit_util = {};

/// @desc 按敌人【当前实际坐标】重建命中用格子。每帧一次。
///       行键取敌人自己的 grid_row —— 取候选时用的也是它，两者同源才不会漏判。
global.hit_util.build = function(){
    var _stride = global.grid_cols + 2;
    var _size   = global.grid_rows * _stride;
    if (array_length(global.hu_cells) != _size){
        global.hu_cells = array_create(_size);
        for (var _i = 0; _i < _size; _i++){ global.hu_cells[_i] = []; }
    } else {
        for (var _i = 0; _i < _size; _i++){ array_resize(global.hu_cells[_i], 0); }
    }
    with (obj_enemy_parent){
        if (hp > 0){
            var _r = clamp(grid_row, 0, global.grid_rows - 1);
            var _c = clamp(floor((x - global.grid_offset_x) / global.grid_cell_size_x), 0, _stride - 1);
            array_push(global.hu_cells[_r * _stride + _c], id);
        }
    }
};

/// @func hit_util.scan(_b, _row, _ttype)
/// @desc 返回子弹 _b 此刻会命中的敌人（实例 id），没有则 noone。
///       只走子弹的 row 那一行，列窗口 ±2 覆盖掩码跨格与坐标舍入。
global.hit_util.scan = function(_b, _row, _ttype){
    var _hit = noone;
    var _stride = global.grid_cols + 2;
    var _r = clamp(_row, 0, global.grid_rows - 1);
    with (_b){
        // 内联 get_grid_position_from_world：它每次调用都新建一个 4 字段结构体，
        // 而这里只用 col 一个整数，且是每颗子弹每帧一次。
        var _c0 = floor((x - global.grid_offset_x) / global.grid_cell_size_x);
        for (var _dc = -2; _dc <= 2 && _hit == noone; _dc++){
            var _c = _c0 + _dc;
            if (_c < 0 || _c >= _stride) continue;
            var _list = global.hu_cells[_r * _stride + _c];
            var _n = array_length(_list);
            for (var _i = 0; _i < _n; _i++){
                var _e = _list[_i];
                if (!instance_exists(_e)) continue;
                if (_e.hp <= 0) continue;
                if (_e.grid_row != _row) continue;
                if (!can_hit(_ttype, _e.target_type)) continue;
                if (instance_place(x, y, _e) != _e) continue;   // 传实例 id：只对这一个实例做精确掩码判定
                _hit = _e;
                break;
            }
        }
    }
    return _hit;
};

// 三线酒架弹：伤害 + 特效（酒架与射手座各有对应特效精灵）+ 销毁
global.hit_util.hit_winerack = function(_b, _e){
    with (_b){
        with (_e){
            if (other.burnt == 1) audio_play_sound(snd_fire_hit,0,0);
            else                  audio_play_sound(hit_sound,0,0);
            damage_amount = other.damage;
            damage_type   = other.damage_type;
            event_user(0);
        }
        if (burnt == 0){
            var inst = instance_create_depth(x, y, depth, obj_coffeecup_bullet_effect);
            inst.sprite_index = spr_triplewinerack_bullet_effect;
            if (sprite_index == spr_wine_rack_sagittarius_bullet)   inst.sprite_index = spr_wine_rack_sagittarius_bullet_effect;
            if (sprite_index == spr_wine_rack_sagittarius_bullet_1) inst.sprite_index = spr_wine_rack_sagittarius_bullet_effect_1;
        } else if (burnt == 1){
            var inst = instance_create_depth(x+25, y, depth, obj_fire_bullet_effect);
            inst.sprite_index = spr_fire_bullet_effect;
        }
        instance_destroy();
    }
};

// 水管弹：伤害 + 特效 + 销毁
global.hit_util.hit_waterpipe = function(_b, _e){
    with (_b){
        with (_e){
            if (other.burnt == 1) audio_play_sound(snd_fire_hit,0,0);
            else                  audio_play_sound(hit_sound,0,0);
            damage_amount = other.damage;
            damage_type   = other.damage_type;
            event_user(0);
        }
        if (burnt == 0){
            instance_create_depth(x, y, depth, obj_waterpipe_bullet_effect);
        } else {
            var inst = instance_create_depth(x+25, y, depth, obj_fire_bullet_effect);
            inst.sprite_index = spr_fire_bullet_effect;
        }
        instance_destroy();
    }
};

// 每帧 End Step 调一次（由 obj_battle/Step_2 触发）
global.hit_util.resolve_all = function(){
    global.hit_util.build();
    with (obj_triplewinerack_bullet){
        var _e = global.hit_util.scan(id, row, target_type);
        if (_e != noone) global.hit_util.hit_winerack(id, _e);
    }
    with (obj_waterpipe_bullet){
        var _e = global.hit_util.scan(id, row, target_type);
        if (_e != noone) global.hit_util.hit_waterpipe(id, _e);
    }
};
