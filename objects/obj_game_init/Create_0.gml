function init_native_log() {
    var _local_log_file = global.native_util.get_path_in_local_appdata("\\FVM_Reborn\\native\\latest.log")
	var _error_code = native_set_native_log_file_path(_local_log_file)
	if (_error_code != 0) {
        global.native_util.show_error(_error_code, "设置日志路径失败")
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
// ⚠️ 2026-09-22 测试期：临时打开调试模式（原值 0）；2026-09-24 出正式版，已关回 0。
//    打开后额外给的是：战斗里 M=鼠标处召唤锯齿、N=召唤敌人、一键召唤本关 BOSS
//    （obj_touch_control/Create_0.gml:41）、卡槽/落点调试信息、十字线校准缺失警告，
//    以及 obj_battle/Draw_0 末尾那行「2x探测」状态（验证免回弹用）。
global.debug = 0

// 局域网地图源开关（与 global.debug 同款：藏在代码里，不用就置 0，没有任何对外 UI）。
//   1 = 在线地图面板左上角出现「地图源」按钮，可填 192.168.x.x:8000，从局域网（PC 上跑
//       的 tools/lan_map_server.py）下载实验室地图；
//   0 = 该按钮不出现，且 map_api_base() 恒返回官网 kMapApiBase。
//   ⚠️ 设备上以前存过的局域网地址**不会被清除**，只是被忽略 —— 以后想用置回 1 即可。
global.lan_map_source = 0

// ---- 地图脚本 VM / mod 卡系统（从联机版移植，2026-09-20）----------------
// mod_enabled：工作目录下存在 mod_enable.txt 时才启用 Mod 卡系统。
//   安卓 release 包的工作目录玩家改不了 → 恒为 false → 整条 mod 链路零开销。
// _mod_pending_card_id：创建 mod 卡实例前传入的卡 id（src_mod 用）。
// _VM_cur_card：mod 卡 VM 块执行时的"当前实例"上下文（src_mod 用）。
// 三个都必须在 scr_command_VM / src_mod 的顶层代码跑之前就存在。
// 先把内置的 mod 内容放进沙盒（作者产出的卡/武器将来由下载管线落到同一棵树）
install_bundled_mods()
// mod 是否可用 = 相对树里到底有没有卡。不再依赖 mod_enable.txt：
//   ① 安卓上玩家没地方放那个文件（app 私有目录，非 debuggable 连 adb 都进不去）；
//   ② 按「作者产出、玩家只管玩」的分发模型，有内容就该生效，玩家不该做任何事。
// 没有任何 mod 内容时 5 个 init 会各自 no-op（目录不存在直接 return -1），零开销。
global.mod_enabled = directory_exists("mod/cards/") or directory_exists(working_directory + "mod/cards/")
global._mod_pending_card_id = ""
global._VM_cur_card = noone
global.laboretory_room = false
global.game_version = "2.4.1.1"

// 崩溃面包屑检查：上次运行若崩在半路（没写 OK end），这里把追踪内容弹出来。
// 放在启动早期即可 —— 弹窗由 room_init 里的 obj_notice_controller 在 Draw 时渲染。
// 崩溃面包屑：① 先检查上次（没销账就弹窗报出来）② 再武装本次会话。
// 顺序不能反 —— 反过来会把上次留下的证据截断掉。
vm_trace_check_on_launch()
vm_trace_boot()

// 随包内置的实验室关卡（datafiles/bundled_stages/ → 沙盒 laboratory/）
// 在线下载暂时拿不到这些图时，用它验证地图脚本 VM 与 mod 插件。
// 只拷沙盒里还没有的，不覆盖玩家自己下载/改过的同名文件。
install_bundled_stages()
global.tower_level_click = false
global.tower_cake_page = 1
Music_Init()

global.laboratory_manager = new LaboratoryManager()
global.laboratory_manager.init()
global.gui_stack = new GuiStack()
global.native_util = new NativeUtil()
global.file_dialog_pending = ""

// 锁帧 60（安卓高刷屏下 game_set_speed 可能失效，配合 obj_touch_control 的 sleep 补偿）
game_set_speed(60, gamespeed_fps)
// 上次若在 2x 状态下被杀进程，会留下 runtime 的 2x 标志文件 → 启动时清掉，
// 否则菜单房间也会被 runtime 跑成双倍步进（见 scripts/speed_up_control）
speed_up_init()   // 启动时探测面板刷新率（60Hz 设备开 2x 会被拒绝并提示）
if (file_exists("fvm_speed2x.txt")) {
    file_delete("fvm_speed2x.txt");
}
if (file_exists("fvm_2xsub.txt")) {
    file_delete("fvm_2xsub.txt");
}

// 触屏适配控制器（持久，跨房间常驻；双指取消/虚拟按键）
if (!instance_exists(obj_touch_control)) {
    instance_create_depth(0, 0, -100000, obj_touch_control)
}

init_native_log()
// 内置实验室地图已全部移除（改为从服务器在线下载，见 MapDownloadManager / OnlineMapGUI），
// 原 install_bundled_lab_stages() 及其清理助手 lab_delete_recursive_files() 已随之删除。

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
	ini_write_bool("settings", "cardslow_enabled", true)
	ini_write_bool("settings", "slowmo_overlay", true)
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
global.cardslow_enabled = ini_read_bool("settings", "cardslow_enabled", true);
global.slowmo_overlay = ini_read_bool("settings", "slowmo_overlay", true);
for (var i = 0; i < array_length(global.keybind_config); i++) {
	    var kb = global.keybind_config[i];
	    var key_val = ini_read_real("keybinds", kb.name, kb.default1);
	    global.keybind_map[? kb.name] = key_val;
}



// ── 音效播放管理器配置（PC 侧 Issue #79 同步，见 安卓同步_音频管理器.md）──
// 优先级：config.ini 里已有的值 > Music_Init.gml 里的默认值；默认值只在缺键时写入。
global.audio.enable     = ini_read_bool("settings", "audio_opt_enable", true);
global.audio.gap_ms     = ini_read_real("settings", "audio_snd_gap_ms", 20);   // 间隔地板 ms
global.audio.gap_ratio  = ini_read_real("settings", "audio_gap_ratio", 0.25);  // 间隔 = 时长×该比例
global.audio.gap_max    = ini_read_real("settings", "audio_gap_max", 400);     // 间隔上限 ms
global.audio.same_max   = ini_read_real("settings", "audio_same_max", 8);      // 同音并发上限
global.audio.duck       = ini_read_bool("settings", "audio_duck", true);       // 同音叠加增益
global.audio.jitter     = ini_read_real("settings", "audio_jitter", 0.25);     // 间隔抖动 ±比例
global.audio.density_ms = ini_read_real("settings", "audio_density_ms", 300);  // 增益密度窗口 ms
global.audio.vary_pitch = ini_read_real("settings", "audio_vary_pitch", 0.06); // 音高随机 ±比例

// 键缺失时补写默认值（只在缺键时写，绝不无条件覆盖）
if (ini_read_string("settings", "audio_snd_gap_ms", "") == "") {
    ini_write_bool("settings", "audio_opt_enable", true);
    ini_write_real("settings", "audio_snd_gap_ms", 20);
    ini_write_real("settings", "audio_same_max", 8);
    ini_write_bool("settings", "audio_duck", true);
}
if (ini_read_string("settings", "audio_gap_ratio", "") == "") {
    ini_write_real("settings", "audio_gap_ratio", 0.25);
}
if (ini_read_string("settings", "audio_gap_max", "") == "") {
    ini_write_real("settings", "audio_gap_max", 400);
}
if (ini_read_string("settings", "audio_jitter", "") == "") {
    ini_write_real("settings", "audio_jitter", 0.25);
    ini_write_real("settings", "audio_density_ms", 300);
    ini_write_real("settings", "audio_vary_pitch", 0.06);
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

