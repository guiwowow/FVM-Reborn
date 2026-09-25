/// 

self.state = {
    scale: 1.9,
    left: 0,
    top: 0,
    /// @type {Struct.CustomStage} 
    custom_stage: undefined,
    height: 0,
    width: 0,
    /// @type {function} 
    on_close_clicked: undefined,
    /// @type {Asset.GMObject.Button} 
    close_button: undefined,
    /// @type {Asset.GMObject.Button} 
    start_button: undefined,

}


/// @param {Struct.CustomStage} _custom_stage 
function init(_custom_stage) {
    self.state.custom_stage = _custom_stage
    return self
}

function set_position(_left, _top) {
    self.state.left = _left
    self.state.top = _top

    if (!is_undefined(self.state.close_button)) {
        self.state.close_button.set_position(_left + self.state.width - 50, _top + 44)
    }
    if (!is_undefined(self.state.start_button)) {
        self.state.start_button.set_position(self.state.left + self.state.width - 240, self.state.top + self.state.height - 110)
    }

    return self
}

function get_width() {
    return self.state.width
}

function get_height() {
    return self.state.height
}

function destroy_widgets() {
    if (!is_undefined(self.state.close_button) && instance_exists(self.state.close_button)) {
        instance_destroy(self.state.close_button)
    }
    self.state.close_button = undefined

    if (!is_undefined(self.state.start_button) && instance_exists(self.state.start_button)) {
        instance_destroy(self.state.start_button)
    }
    self.state.start_button = undefined
}

function on_close() {
    if (!is_undefined(self.state.on_close_clicked)) {
        self.state.on_close_clicked()
    }
    destroy_widgets()
    instance_destroy()
}

function on_create_room() {
    if (is_undefined(self.state.custom_stage)) {
        return
    }
    var _parse_result = global.laboratory_manager.file_util.load_json_from_path(self.state.custom_stage.json_path)
    if (_parse_result.is_failed()) {
        throw _parse_result.get_error_stack()
    }
    var _level_data = level_entry_from_stage_metadata(self.state.custom_stage)
    global.level_data = _level_data
    global.level_id = self.state.custom_stage.id
    global.level_file = _parse_result.data

    // ---- 地图脚本 VM 初始化（2026-09-20 从联机版移植）----------------------
    // 实验室地图可以带一个**同名 .bin** —— 地图作者用 LabMapCompiler.exe 把
    // 中文脚本（_VM_WAVE_START / VM_SpawnEnemy 等）编译成字节码，随地图包分发。
    // 这里载入它交给 VM 解释器；没有 .bin 时以「无脚本」初始化，
    // 行为与移植前完全一致（内置关卡都没有 .bin）。
    // 详见 scripts/scr_command_VM/scr_command_VM.gml。
    //
    // _file_cache_json_path 是 VM 查找地图自定义贴图/音效的基准目录
    // （VM_LoadSprite 会去「与 json 同级」的目录找），必须在这里设置。
    // ---------------------------------------------------------------------
    var _json_dir = self.state.custom_stage.json_path
    global._file_cache_json_path = _json_dir
    var _bin_path = string_replace(_json_dir, ".json", ".bin");
    // ---- 兜底：按**同前缀**找脚本 ----
    // 下载时条目名被按顺序改成 "<prefix>_file_N.ext"，所以 bin 与 json 的 N 本来**不相干**。
    // 新版下载会用 pair_script_bins 把同 stem 的 bin 改成与 json 一致；
    // 但**用旧版下载的地图**没做过这一步，按 json 名直接改名就找不到脚本
    //（症状：地图能进、但脚本完全不生效）。
    // 这里按前缀（= 该地图专属，跨地图不会撞）再找一次 bin。
    if (!file_exists(_bin_path)) {
        var _de = string_last_pos("/", _json_dir);
        if (_de > 0) {
            var _folder = string_copy(_json_dir, 1, _de);
            var _fname  = string_copy(_json_dir, _de + 1, string_length(_json_dir) - _de);
            var _fi = string_last_pos("_file_", _fname);
            if (_fi > 0) {
                var _pfx = string_copy(_fname, 1, _fi - 1);
                var _bit = file_find_first(_folder + _pfx + "_file_*.bin", fa_archive | fa_readonly);
                if (_bit != "") {
                    _bin_path = _folder + _bit;
                    vm_trace("bin 兜底命中（旧版下载未配对）: " + string(_bin_path))
                }
                file_find_close();
            }
        }
    }
    // VM 随机种子：每次进房重掷，保证同一张图每局 VM_Random 序列不同
    global.__vm.rng_state = irandom(2147483646) + 1;

    // 面包屑：这一整段（尤其 buffer_load + VM_InitRoomEntry）是最可能原生崩溃的地方
        // 用 vm_trace_arm（不是 begin）：已被开机武装过就只追加、绝不截断，
    // 这样"开机 → 房间轨迹 → 进图各阶段"完整留在同一个文件里。第二参 true = 开逐 CALL 明细。
    vm_trace_arm("StageDetail.on_create_room", true)
    vm_trace("json=" + string(_json_dir))
    vm_trace("bin=" + string(_bin_path) + " 存在=" + string(file_exists(_bin_path)))
    global._vm_bin_path = _bin_path
    if (file_exists(_bin_path)) {
        var _bb = buffer_load(_bin_path);
        vm_trace("buffer=" + string(_bb) + " size=" + string(_bb >= 0 ? buffer_get_size(_bb) : -1))
        vm_trace("VM_InitRoomEntry 开始（脚本块解析+CONST_INIT+ROOM_READY）")
        VM_InitRoomEntry(_bb);
        vm_trace("VM_InitRoomEntry 返回")
    } else {
        VM_InitRoomEntry(undefined);
        vm_trace("无 bin，已按无脚本初始化")
    }
    // ⚠️ 这里**不能**写 vm_trace_end()：进图崩溃多数发生在之后的战斗房间
    //    （obj_battle/Create、BATTLE_START、首帧 VM_FRAME），
    //    过早写 OK end 会让下次启动的检查误判"上次正常"而把追踪删掉
    //    （2026-09-21 实测踩到：三界花园崩了重进没弹窗）。
    //    成功标记统一放在 obj_battle/Step_0 跑满 120 帧那处。

    global.gui_stack.to(room_ready)
    window_set_cursor(cr_arrow)
}

/// @type {function} _on_close_clicked
function set_on_close_clicked(_on_close_clicked) {
    self.state.on_close_clicked = _on_close_clicked
    return self
}

function create_widgets() {
    /// @type {Asset.GMObject.Button} 
    var _close_button = instance_create_layer(0, 0, "Float", Button)
    _close_button.set_auto_draw(false)
        .set_sprite(spr_closemenu_btn)
        .set_scale(1.9)
        .set_frames(0, 1, 2)
        .set_on_click(method(self, on_close))
    self.state.close_button = _close_button

    /// @type {Asset.GMObject.Button} 
    var start_button = instance_create_layer(0, 0, "Float", Button)
    start_button.set_auto_draw(false)
        .set_sprite(spr_create_room)
        .set_scale(2)
        .set_on_click(method(self, on_create_room))
        .set_should_correspond(method({owner: id}, function() {
            return instance_exists(owner)
        }))
    self.state.start_button = start_button
}

/// @description Events
function on_create() {
    self.state.height = sprite_get_height(spr_stage_detail) * self.state.scale
    self.state.width = sprite_get_width(spr_stage_detail) * self.state.scale
    create_widgets()
}

function on_step() {

}

function on_cleanup() {
    destroy_widgets()
}

function on_draw() {
    draw_sprite_ext(
        spr_stage_detail, 0, 
        self.state.left, self.state.top, 
        self.state.scale, self.state.scale, 
        0, c_white, 1)

    if( !is_undefined(self.state.close_button)) {
        self.state.close_button.on_draw()
    }
    if( !is_undefined(self.state.start_button)) {
        self.state.start_button.on_draw()
    }
    if (!is_undefined(self.state.custom_stage)) {
        // 标题字色：面板 spr_stage_detail (scale 1.9) 标题带实测是**浅天蓝 #7FC8F5**，
        // 安卓没有描边字体 → 白字看清度差。改用深藏蓝 #174D86。
        var _name_draw = scribble(self.state.custom_stage.name, "stage_detail_name")
            .align(fa_center, fa_center)
            .scale(1.2)
            .starting_format(os_type == os_android ? "font_hei" : "font_hei_outline_4dir_black")
        if (os_type == os_android) {
            _name_draw = _name_draw.blend(make_color_rgb(23, 77, 134), 1)
        }
        _name_draw.draw(self.state.left + (self.state.width / 2),  self.state.top + 114)

        scribble(self.state.custom_stage.id)
            .draw(self.state.left + 160, self.state.top + 170)

        scribble(self.state.custom_stage.author)
            .draw(self.state.left + 130, self.state.top + 228)
        scribble(self.state.custom_stage.description, "stage_detail_desc")
            .wrap(650, 360)
            .line_spacing("90%")
            .scale(1.0)
            .draw(self.state.left + 50, self.state.top + 300)

        draw_sprite_ext(spr_level_progress_icon, 0, 
            self.state.left + 60, self.state.top + self.state.height - 90, 
            0.7, 0.7, 
            0, c_white, 1)
        scribble("Lv." +  string(self.state.custom_stage.mouse_level))
            .draw(self.state.left + 90, self.state.top+self.state.height-108)
        
        draw_sprite_ext(spr_flame_small, 0, 
            self.state.left + 200, self.state.top + self.state.height - 90, 
            0.95, 0.95, 
            0, c_white, 1)
        scribble(string(self.state.custom_stage.initial_energy))
            .draw(self.state.left + 230, self.state.top+self.state.height-106)
        
        draw_sprite_ext(spr_level_progress_flag, 0, 
            self.state.left + 340, self.state.top + self.state.height - 80, 
            0.3, 0.3, 
            0, c_white, 1)
        scribble(string(self.state.custom_stage.total_waves))
            .draw(self.state.left + 370, self.state.top+self.state.height-106)
        
        draw_sprite_ext(spr_clock, 0, 
            self.state.left + 38, self.state.top + self.state.height - 70, 
            0.5, 0.5, 
            0, c_white, 1)
        scribble(string(self.state.custom_stage.time_limit) + "\"")
            .draw(self.state.left + 90, self.state.top+self.state.height-65)

        draw_sprite_ext(spr_first_wave_time, 0, 
            self.state.left + 178, self.state.top + self.state.height - 70, 
            0.5, 0.5, 
            0, c_white, 1)
        scribble(string(self.state.custom_stage.prepare_time) + "\"")
            .draw(self.state.left + 230, self.state.top+self.state.height-65)
      
    }
}

///
on_create()

