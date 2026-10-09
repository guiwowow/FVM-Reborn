global.menu_screen = true
vm_trace("[menu] Create 起")

depth = -1200

// 强制清除application_surface，避免上一房间图像残留
if surface_exists(application_surface){
	surface_set_target(application_surface);
	draw_clear_alpha(c_black, 0); // 用透明黑色清除surface，alpha值0表示完全透明
	surface_reset_target();
}

instance_create_depth(1355,820,-2,obj_startgame_button)
instance_create_depth(100,0,-2,obj_player_info_ui)

/// @type {Asset.GMObject.EventEntranceList} 
var _entrance_list = instance_create_depth(0, 0, -2, EventEntranceList)
_entrance_list.set_position(600,20)
              .set_size(900, 300)
vm_trace("[menu] EventEntranceList ok")


if not instance_exists(obj_menu_music_controller){
	var mus_inst = instance_create_depth(0,0,0,obj_menu_music_controller)
	mus_inst.menu_music = mus_town
}
if not instance_exists(obj_world_map_button){
	instance_create_depth(1670,80,0,obj_world_map_button)
}
instance_create_depth(room_width-210,room_height,-1,obj_player_menu_bg)
vm_trace("[menu] 基础 UI ok")
timer = 0

/// @description preload textures

global.laboretory_room = false

// [ASTC 定稿] GPU 纹理压缩后显存占用降至约 1/9，低端机也能扛 12 组全预取，删除高低配分档
self.texture_to_load = [
	"Default",
	"UI",
	"cards",
	"enemy_delicious",
	"enemy_volcanic",
	"bullet",
	"effects",
	"player",
	"maps",
	"enemy_tower",
	"enemy_floating",
	"pack_undersea_vortex"
]

self.texture_count = array_length(self.texture_to_load)
self.texture_loaded = 0
global.preloaded = variable_global_exists("preloaded") ? global.preloaded : false
self.display_progress = 0

// 预热（shader 编译 + 字体字形生成，分帧执行；shader 编译是进程级的，每次启动都要预热）
// 注意：不能用 struct 字面量数组（会破坏 GMA 全局 struct 编号，导致其他对象编译失败）
prewarm_active = false
prewarm_idx = 0
prewarm_total = 0
prewarm_types = []
prewarm_res = []
audio_wait_start = 0

if !global.preloaded{
	instance_create_depth(-800,-800,0,obj_update_checker_btn)
}

function after_texture_load() {
    // 诊断面包屑（最多 3 条）：卡在音频等待时能看到重复的 after_texture_load
    if (!variable_global_exists("_menu_after_n")) { global._menu_after_n = 0 }
    if (global._menu_after_n < 3) { global._menu_after_n += 1; vm_trace("[menu] after_texture_load 第 " + string(global._menu_after_n) + " 次（音频 music=" + string(audio_group_is_loaded(music)) + " sound=" + string(audio_group_is_loaded(sound)) + "）") }
    // 安卓/移动端：等待音频组异步加载完成（防首次播放音频卡顿），未就绪下一帧重试
    if (os_type != os_windows) {
        if (!audio_group_is_loaded(music) || !audio_group_is_loaded(sound)) {
            return;
        }
    }
    // 启动预热：shader 驱动编译缓存 + 字体字形（避免游戏内首次使用资源卡顿）
    // 全部 12 shader + 7 字体（游戏内零卡顿）
    prewarm_types = ["shader","shader","shader","shader","shader","shader","shader","shader","shader","shader","shader","shader","font","font","font","font","font","font","font"]
    prewarm_res = [__shd_scribble, __shd_scribble_bake_effect_4dir, __shd_scribble_bake_effect_8dir, __shd_scribble_bake_effect_8dir_2px, __shd_scribble_bake_effect_no_outline, __shd_scribble_bake_outline_4dir, __shd_scribble_bake_outline_8dir, __shd_scribble_bake_outline_8dir_2px, __shd_scribble_bake_shadow, ClipRRectShader, hit_effect, hit_effect_2, font_hei, font_number, font_pixel, font_song, font_song2, font_yuan, scribble_fallback_font]
    prewarm_total = array_length(prewarm_res)
    prewarm_idx = 0
    prewarm_active = true
    // 安卓/移动端跳过 scribble 中文字体烘焙（CPU 极重且可能触发阻塞弹窗），文字回退用普通字体渲染
    // 收尾动效（黑滤镜淡出 + LOGO 下移 50px 淡出）必须在下面的安卓分支 return 之前触发，
    // 否则安卓永远走不到这一行 —— 加载界面/LOGO 会硬切消失（2026-10-09 用户报「开屏 logo 消失时没有动效」）。
    if (ui_anim_on(1)) self.outro_t = 0   // 等级 1/2 才开始收尾；等级 0 加载界面直接消失
    if (os_type == os_android) {
        // 只注册默认字体（轻量，不烘焙）：保证安卓上所有不带 starting_format 的 Scribble 文本回退到 font_hei
        scribble_font_set_default("font_hei")
        if !global.preloaded{
            global.preloaded = true;
        }
        // 上游 PR#71 在 pre_load_texture() 开头置 menu_type = 4 / world_map = 2（加载期隐藏主菜单 UI），
        // 复位却写在 after_texture_load() 末尾 —— 而安卓在上面的 return 就退出了，复位永远执行不到。
        // 后果：加载完成后 menu_type 永久停在 4，主菜单所有按钮首行判定 menu_type == 0 全部失败，
        // 表现为首次进游戏触控完全不生效（切桌面再回游戏一次才恢复）。此处补上复位。
        obj_player_info_ui.menu_type = 0
        obj_world_map_button.world_map = 0
        return;
    }
    scribble_font_set_default("font_hei")
    scribble_font_bake_outline_4dir("font_hei", "font_hei_outline_4dir_black", c_dkgray, false)
	if !global.preloaded{
		with obj_update_checker_btn{
			event_user(1)
		}
		global.preloaded = true;
	}
	obj_player_info_ui.menu_type = 0
	obj_world_map_button.world_map = 0
}

/// @description 分帧预热：离屏绘制触发 shader 编译与字体字形生成
function prewarm_step() {
    if (!prewarm_active) return;
    if (prewarm_idx >= prewarm_total) {
        prewarm_active = false;
        return;
    }
    var _surf = surface_create(2, 2)
    if (_surf != -1) {
        surface_set_target(_surf)
        if (prewarm_types[prewarm_idx] == "shader") {
            shader_set(prewarm_res[prewarm_idx])
            draw_rectangle(0, 0, 2, 2, false)
            shader_reset()
        } else {
            draw_set_font(prewarm_res[prewarm_idx])
            draw_text(0, 0, "预热")
        }
        surface_reset_target()
        surface_free(_surf)
    }
    prewarm_idx++
}

function pre_load_texture() {
    if (global.preloaded) return;
	vm_trace("[menu] prefetch " + string(self.texture_loaded) + "/" + string(self.texture_count))
	
	obj_player_info_ui.menu_type = 4
	obj_world_map_button.world_map = 2
	
    if (self.animating) {
        var _target = self.texture_loaded;
        self.display_progress = lerp(self.display_progress, _target, 0.1);

        if (abs(self.display_progress - _target) < 0.01) {
            self.display_progress = _target;
            self.animating = false;
            
            if (self.texture_loaded >= self.texture_count) {
                after_texture_load();
            }
        }
        return;
    }

    // 贴图全部预取完成但未就绪（等待音频加载）：每帧重试
    if (self.texture_loaded >= self.texture_count) {
        after_texture_load();
        return;
    }

    if (self.texture_loaded < self.texture_count) {
        texture_prefetch(self.texture_to_load[self.texture_loaded]);
        self.texture_loaded += 1;
        self.animating = true;
    }
}


self.total_progress_bar_width = 700
self.active_bg = $fde98b
self.inactive_bg = c_white
self.active_width = 0
self.offset_x = (room_width - self.total_progress_bar_width) / 2
self.offset_y = (room_height/2 + 250)
self.animating = false
self.outro_t = -1            // 收尾动画：-1 = 无；>=0 = 播放中（加载完成后触发）
self.outro_frames = 48       // 时长（帧），60fps ≈ 0.8s
function on_draw() {
    if (self.outro_t < 0) {
        if (global.preloaded) return;
        if (!self.animating && self.texture_loaded == 0) return;
    }

    // 收尾进度 0 → 1（非线性 ease-out：起步快、收尾慢）
    var _out = 0;
    if (self.outro_t >= 0) {
        _out = clamp(self.outro_t / self.outro_frames, 0, 1);
        _out = 1 - (1 - _out) * (1 - _out) * (1 - _out);
    }
    var _fade = 1 - _out;   // 加载界面留存度（黑滤镜 / 进度条 / 文字一起淡出）

    draw_set_colour(c_black);
    draw_set_alpha(0.8 * _fade);
    draw_rectangle(0, 0, room_width, room_height, false);

    var _ratio = (self.texture_count > 0) ? (self.display_progress / self.texture_count) : 0;
    var _current_width = self.total_progress_bar_width * _ratio;

    var _x1 = self.offset_x;
    var _y1 = self.offset_y;
    var _bar_h = 20;

    draw_set_alpha(_fade);
    draw_set_color(self.inactive_bg);
    draw_rectangle(_x1 - 2, _y1 - 2, _x1 + self.total_progress_bar_width + 2, _y1 + _bar_h + 2, false);

    draw_set_color(self.active_bg);
    draw_rectangle(_x1, _y1, _x1 + _current_width, _y1 + _bar_h, false);
	// LOGO：加载完成后下移 50px 并淡出
	draw_sprite_ext(spr_game_logo,0,room_width/2,room_height/3 + 50 * _out,1,1,0,c_white,_fade)
    
	draw_set_valign(fa_left)
	draw_set_halign(fa_top)
    draw_set_color(c_white);
    draw_set_font(font_yuan);
	var _text = "加载完成！"
	var _pct = 0
	if self.texture_loaded <= array_length(self.texture_to_load)-1{
		var _group_name = self.texture_to_load[clamp(self.texture_loaded,0,array_length(self.texture_to_load)-1)]
		_text = "加载资源 " + string(self.texture_loaded) + "/" + string(self.texture_count) + " — 当前：" + _group_name
		_pct = round((self.texture_loaded / self.texture_count) * 100)
	}
	else if (os_type != os_windows && (!audio_group_is_loaded(music) || !audio_group_is_loaded(sound))){
		_text = "音频加载中…"
	}
	else if (prewarm_active){
		_text = "预热中 " + string(prewarm_idx) + "/" + string(prewarm_total)
	}
    draw_text(_x1, _y1 - 30, _text);
	// 进度条内显示百分比
	draw_set_halign(fa_center)
	draw_set_valign(fa_middle)
	draw_set_color(c_white)
	if (self.texture_loaded <= array_length(self.texture_to_load)-1) {
		draw_text(_x1 + self.total_progress_bar_width / 2, _y1 + _bar_h / 2, string(_pct) + "%")
	}
	draw_set_valign(fa_middle)
	draw_set_halign(fa_center)
	draw_set_colour(c_yellow)
	draw_text(_x1+self.total_progress_bar_width/2, _y1 - 80, "本游戏为免费开源游戏，任何付费获取方式均为诈骗\n游戏作者B站名称：Spring曙光\n手机版作者：超级飞侠");
        draw_set_alpha(1)
}


