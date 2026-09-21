/// 
self.state = {
    bg_scale: 0,
    offset_x: 0,
    offset_y: 0,
    /// @type {Struct.LaboratoryManager} 
    laboratory_manager: undefined,
    /// @type {Array<String>} 
    stage_ids : [],
    current_stage_id: "",
    /// @type {Asset.GMObject.StageDetail} 
    stage_detail_widget: undefined,
    /// @type {Asset.GMObject.Button} 
    close_button: undefined,
    /// @type {Asset.GMObject.GridList} 
    grid_list: undefined,
    /// @type {Asset.GMObject.SearchBox}
    search_box: undefined,
    /// @type {Asset.GMObject.OnlineMapGUI}
    online_gui: undefined,
    search_query: "",
    bottom_button_width: 210,
    bottom_button_height: 170,
    bottom_button_scale: 1,
}

function init_asset_size_and_offset() {
    var _bg_sprite_width = sprite_get_width(spr_laboratory_bg)
    var _width_scale = room_width / _bg_sprite_width
    var _bg_sprite_height = sprite_get_height(spr_laboratory_bg)
    var _height_scale = room_height / _bg_sprite_height

    self.state.bg_scale = min(_width_scale, _height_scale)

    self.state.offset_x = (room_width - _bg_sprite_width * self.state.bg_scale) / 2
    self.state.offset_y = (room_height - _bg_sprite_height * self.state.bg_scale) / 2

    var _bottom_button_width = sprite_get_width(spr_doctor_shop)
    self.state.bottom_button_scale = self.state.bottom_button_width / _bottom_button_width

}

function is_local_mode() {
    return is_undefined(self.state.online_gui) || !instance_exists(self.state.online_gui)
}

function apply_local_filter() {
    if (is_undefined(self.state.grid_list) || !instance_exists(self.state.grid_list)) {
        return
    }
    self.state.grid_list.destroy_items()
    var _query = string_lower(string_trim(self.state.search_query))
    /// @type {Array<Asset.GMObject.StageItem>}
    var _items = []
    for (var _i = 0; _i < array_length(self.state.stage_ids); _i++) {
        var _stage_id = self.state.stage_ids[_i]
        var _stage = self.state.laboratory_manager.get_stage(_stage_id)
        if (is_undefined(_stage)) {
            continue
        }
        if (_query != "") {
            var _name = string_lower(string(_stage.name))
            var _author = string_lower(string(_stage.author))
            if (string_pos(_query, _name) <= 0 && string_pos(_query, _author) <= 0) {
                continue
            }
        }
        /// @type {Asset.GMObject.StageItem}
        var _item = instance_create_layer(0, 0, "Assets", StageItem)
        _item.init(_stage)
             .set_on_click(method({stage_id: _stage_id, gui_state: self.state}, function() {
                 gui_state.current_stage_id = stage_id
             }))
             .set_should_correspond(method({gui_state: self.state}, function() {
                return gui_state.current_stage_id == "" && (is_undefined(gui_state.online_gui) || !instance_exists(gui_state.online_gui))
             }))
        _item.visible = false
        array_push(_items, _item)
    }
    self.state.grid_list.set_items(_items)
}

function refresh_custom_stages() {
    self.state.laboratory_manager.reset()
    var _result = self.state.laboratory_manager.load_all_stages()
    self.state.stage_ids = self.state.laboratory_manager.get_stage_ids()
    if (_result.is_failed()) {
        show_error_dialog("加载关卡失败", "有部分关卡加载失败，它们不会出现在列表里。\n点[导出错误报告]可复制完整原因。\n\n" + string(_result.message))
    } else if (variable_global_exists("_lab_scan_json_paths")
            && array_length(global._lab_scan_json_paths) > array_length(self.state.stage_ids)) {
        // 扫到了 json，但加载出来的关卡更少 → 中间有文件被跳过。
        // 把两边都摊出来，避免"下载成功却没显示"只能靠猜。
        var _all = ""
        for (var _li = 0; _li < array_length(global._lab_scan_json_paths); _li++) {
            _all += string(global._lab_scan_json_paths[_li]) + "\n"
        }
        show_error_dialog("部分地图没显示",
            "扫描到 " + string(array_length(global._lab_scan_json_paths)) + " 个关卡文件，"
            + "但只加载出 " + string(array_length(self.state.stage_ids)) + " 个地图。\n\n"
            + "扫描到的文件：\n" + _all)
    }
    apply_local_filter()
}

function close_online_gui() {
    if (!is_undefined(self.state.online_gui) && instance_exists(self.state.online_gui)) {
        instance_destroy(self.state.online_gui)
    }
    self.state.online_gui = undefined
    if (!is_undefined(self.state.search_box) && instance_exists(self.state.search_box)) {
        self.state.search_box.visible = true
    }
    if (!is_undefined(self.state.grid_list) && instance_exists(self.state.grid_list)) {
        self.state.grid_list.visible = true
    }
    refresh_custom_stages()
}

function open_online_gui() {
    if (!is_local_mode()) {
        return
    }
    if (!is_undefined(self.state.search_box) && instance_exists(self.state.search_box)) {
        self.state.search_box.blur()
        self.state.search_box.visible = false
    }
    if (!is_undefined(self.state.grid_list) && instance_exists(self.state.grid_list)) {
        self.state.grid_list.visible = false
    }
    /// @type {Asset.GMObject.OnlineMapGUI}
    var _online = instance_create_layer(0, 0, "Float", OnlineMapGUI)
    _online.set_on_close(method({func: close_online_gui}, function() {
        func()
    }))
    self.state.online_gui = _online
}

function create_widgets() {
    /// @description Close Button
    /// @type {Asset.GMObject.Button} 
    var _close_button = instance_create_layer(0, 0, "Assets", Button)
    _close_button.set_position(room_width - 170, 60)
        .set_sprite(spr_closemenu_btn)
        .set_scale(1.9)
        .set_frames(0, 1, 2)
        .set_on_click(function() {
            global.menu_screen = true
            global.gui_stack.pop()
            window_set_cursor(cr_arrow)
        })
        .set_should_correspond(method({gui_state: self.state}, function() {
            return gui_state.current_stage_id == "" && (is_undefined(gui_state.online_gui) || !instance_exists(gui_state.online_gui))
        }))
    self.state.close_button = _close_button
        
    /// @type {Asset.GMObject.GridList} 
    var _grid_list = instance_create_layer(room_width / 2, room_height / 2, "Assets", GridList)
    _grid_list.set_viewport(159, 175, 1550, 600)
              .set_items([])
              .set_should_correspond(method({gui_state: self.state}, function() {
                  return gui_state.current_stage_id == "" && (is_undefined(gui_state.online_gui) || !instance_exists(gui_state.online_gui))
              }))
    self.state.grid_list = _grid_list

    /// @type {Asset.GMObject.SearchBox}
    var _search_box = instance_create_layer(0, 0, "Assets", SearchBox)
    _search_box.set_position(280, 108)
        .set_size(520, 42)
        .set_placeholder("搜索本地地图名称或作者")
        .set_on_change(method({gui_state: self.state, apply_fn: apply_local_filter}, function(_text) {
            gui_state.search_query = _text
            apply_fn()
        }))
        .set_should_correspond(method({gui_state: self.state}, function() {
            return gui_state.current_stage_id == "" && (is_undefined(gui_state.online_gui) || !instance_exists(gui_state.online_gui))
        }))
    self.state.search_box = _search_box

    /// @type {Asset.GMObject.Button} 
    var _reset_button = instance_create_layer(0, 0, "Assets", Button)
    _reset_button.set_sprite(spr_refresh_button)
        .set_position(159, 110)
        .set_scale(1.2)
        .set_on_click(method({func: refresh_custom_stages}, function() {
            func()
        }))
        .set_should_correspond(method({gui_state: self.state}, function() {
            return gui_state.current_stage_id == "" && (is_undefined(gui_state.online_gui) || !instance_exists(gui_state.online_gui))
        }))

    /// @description Bottom Button
    /// @type {Asset.GMObject.Button} 
    var _my_stage_button = instance_create_layer(0, 0, "Assets", Button)
    _my_stage_button.set_sprite(spr_my_stages)
        .set_scale(self.state.bottom_button_scale)
        .set_position(1180, 843)
        .set_should_correspond(method({gui_state: self.state}, function() {
            return gui_state.current_stage_id == ""
        }))
        .set_on_click(method({gui_state: self.state, close_fn: close_online_gui}, function() {
            // 在线关卡面板开着则先关掉；否则提示（Windows 端「打开本地实验室文件夹」分支已按
            // mobile-only 移除 —— 本工程只出安卓包）
            var _online_visible = !is_undefined(gui_state.online_gui) && instance_exists(gui_state.online_gui)
            if (_online_visible) {
                close_fn()
            } else {
                show_error_dialog("提示", "本地关卡已取消内置，请点[在线]从服务器下载关卡。")
            }
        }))

    /// @type {Asset.GMObject.Button}
    var _online_button = instance_create_layer(0, 0, "Assets", Button)
    _online_button.set_sprite(spr_search_team)
        .set_scale(self.state.bottom_button_scale)
        .set_position(1480, 852)
        .set_should_correspond(method({gui_state: self.state}, function() {
            return gui_state.current_stage_id == "" && (is_undefined(gui_state.online_gui) || !instance_exists(gui_state.online_gui))
        }))
        .set_on_click(method({func: open_online_gui}, function() {
            func()
        }))
}

function on_create() {
	draw_set_halign(fa_left)
	draw_set_valign(fa_top)
    init_asset_size_and_offset()
    var _text = clipboard_get_text()
    show_debug_message("Clipboard: " + _text)

    if (!variable_global_exists("laboratory_manager") || is_undefined(global.laboratory_manager)) {
        throw("global.laboratory_manager is not defined")
    }
    
    self.state.laboratory_manager = global.laboratory_manager

    global.menu_screen = false
    window_set_cursor(cr_arrow)
    
    create_widgets()
    refresh_custom_stages()
}

function on_step() {
    if (!is_local_mode()) exit
    if (!is_undefined(self.state.stage_detail_widget)) {
        if (instance_exists(self.state.stage_detail_widget)) {
            exit
        }
        self.state.stage_detail_widget = undefined
    }
    if (self.state.current_stage_id == "") exit

    /// @type {Asset.GMObject.StageDetail} 
    var _detail_widget = instance_create_layer(0, 0, "Float", StageDetail)
    if (_detail_widget == -1) {
        throw("Failed to create stage detail widget")
    }
    _detail_widget.init(self.state.laboratory_manager.get_stage(self.state.current_stage_id))
                  .set_position((room_width - _detail_widget.get_width()) / 2, (room_height - _detail_widget.get_height()) / 2)
                  .set_on_close_clicked(method({gui_state: self.state}, function() {
                      gui_state.current_stage_id = ""
                      gui_state.stage_detail_widget = undefined
                  }))
    self.state.stage_detail_widget = _detail_widget
}

function on_draw() {
    draw_sprite_ext(
        spr_laboratory_bg, 0, 
        self.state.offset_x, self.state.offset_y, 
        self.state.bg_scale, self.state.bg_scale, 
        0, c_white, 1)
    draw_sprite_ext(
        spr_doctor_shop, 0,
        882, 852,
        self.state.bottom_button_scale, self.state.bottom_button_scale,
        0, c_white, 1
    )
}

on_create()