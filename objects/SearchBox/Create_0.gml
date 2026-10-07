///
self.state = {
    left: 0,
    top: 0,
    width: 420,
    height: 40,
    text: "",
    placeholder: "搜索名称或作者",
    focused: false,
    hovered: false,
    cursor_visible: true,
    cursor_timer: 0,
    /// @type {Real}
    /// get_string_async 的请求 id（安卓软键盘用；-1 = 没有进行中的对话框）
    dialog_id: -1,
    /// @type {function}
    on_change: undefined,
    /// @type {function ():Bool}
    should_correspond: function() { return true },
}

function set_position(_left, _top) {
    self.state.left = _left
    self.state.top = _top
    return self
}

function set_size(_width, _height) {
    self.state.width = _width
    self.state.height = _height
    return self
}

function set_placeholder(_text) {
    self.state.placeholder = _text
    return self
}

function set_on_change(_on_change) {
    self.state.on_change = _on_change
    return self
}

function set_should_correspond(_should_correspond) {
    if (is_undefined(_should_correspond)) {
        throw("SearchBox: should_correspond must be a function")
    }
    self.state.should_correspond = _should_correspond
    return self
}

function get_text() {
    return self.state.text
}


function emit_change() {
    if (!is_undefined(self.state.on_change)) {
        self.state.on_change(self.state.text)
    }
}

function focus() {
    if (self.state.focused) {
        return
    }
    self.state.focused = true
    keyboard_string = self.state.text
    // 软键盘（2026-09-20）：安卓没有硬件键盘，`keyboard_string` 拿不到任何输入
    // → 之前的表现是「能点进去、光标在闪，但打不出字」。
    // 改用与玩家改名模块（objects/obj_text_input）完全相同的方案：
    // get_string_async 弹**系统输入对话框**（自带软键盘），结果在 Async - Dialog 事件写回。
    // 只在"用户真的点了输入框"这一条路径上触发（focus() 由 on_step 的点击检测调用）。
    if (os_type != os_windows && self.state.dialog_id == -1) {
        var _prompt = self.state.placeholder
        if (_prompt == "") {
            _prompt = "请输入";
        }
        self.state.dialog_id = get_string_async(_prompt, self.state.text);
    }
    // 安卓分支：不并入任何 IME 屏蔽/放开调用（与既有策略一致）。
    // 上游在此调用 native_enable_ime / native_disable_ime，二者由 WindowsNative 扩展提供，
    // 而该扩展不在本工程 .yyp 内（安卓侧由 scripts/NativeUtil/NativeUtil.gml 的纯 GML 兼容层替代），
    // 直接调用会是未定义函数 → 安卓构建/运行报错。
}

function blur() {
    if (!self.state.focused) {
        return
    }
    self.state.focused = false
    // 同上：交给 obj_file_manager 统一处理。
}

function contains_point(_mx, _my) {
    return point_in_rectangle(
        _mx, _my,
        self.state.left, self.state.top,
        self.state.left + self.state.width,
        self.state.top + self.state.height)
}

function is_hovered() {
    return self.state.hovered
}

function update_hover() {
    var _was_hovered = self.state.hovered
    var _over = false
    if (visible && self.state.should_correspond()) {
        var _mx = device_mouse_x_to_gui(0)
        var _my = device_mouse_y_to_gui(0)
        _over = contains_point(_mx, _my)
    }
    self.state.hovered = _over
    if (_over) {
        window_set_cursor(cr_beam)
    } else if (_was_hovered) {
        window_set_cursor(cr_arrow)
    }
}

function on_create() {
}

function on_begin_step() {
    update_hover()
}

function on_step() {
    if (!visible) {
        exit
    }
    if (!self.state.should_correspond()) {
        if (self.state.focused) {
            blur()
        }
        exit
    }
    if (self.state.hovered) {
        window_set_cursor(cr_beam)
    }

    if (mouse_check_button_pressed(mb_left)) {
        var _mx = device_mouse_x_to_gui(0)
        var _my = device_mouse_y_to_gui(0)
        if (contains_point(_mx, _my)) {
            focus()
        } else if (self.state.focused) {
            blur()
        }
    }

    if (!self.state.focused) {
        exit
    }

    if (keyboard_check_pressed(vk_escape)) {
        blur()
        exit
    }

    var _prev = self.state.text
    if (os_type != os_windows) {
        // 安卓：文本由 Async - Dialog 事件写回，这里**绝不碰 text**。
        // 关键原因：安卓上 keyboard_string 恒为空串，照搬下面那行会把刚输入的内容每帧刷掉。
    } else if (keyboard_check(vk_control) && keyboard_check_pressed(ord("V"))) {
        self.state.text += clipboard_get_text()
        keyboard_string = self.state.text
    } else {
        self.state.text = keyboard_string
    }

    if (string_length(self.state.text) > 64) {
        self.state.text = string_copy(self.state.text, 1, 64)
        keyboard_string = self.state.text
    }

    if (self.state.text != _prev) {
        emit_change()
    }

    self.state.cursor_timer += 1
    if (self.state.cursor_timer >= 30) {
        self.state.cursor_timer = 0
        self.state.cursor_visible = !self.state.cursor_visible
    }
}

/// @description Async - Dialog 回调（安卓软键盘）。.yy 序列化：eventType=7, eventNum=63。
/// 回调键（2026 手册权威）：id=请求 id，status=true=点确定，result=用户输入（空串=无输入）。
/// ⚠️ 旧版独立的 "text" 键已移除，结果就在 result；result 不是按钮名，不能当 "OK"/"Cancel" 判。
/// 写法与 objects/obj_text_input/Other_63.gml 一致（同一个已验证的通道）。
function on_async_dialog() {
    if (self.state.dialog_id == -1) {
        return;
    }
    var _fired_id   = (is_struct(async_load) ? async_load[$ "id"]     : async_load[? "id"]);
    var _fired_stat = (is_struct(async_load) ? async_load[$ "status"] : async_load[? "status"]);
    var _fired_res  = (is_struct(async_load) ? async_load[$ "result"] : async_load[? "result"]);

    // 老运行时可能不给 id → 只认"有对话框在等"；给了 id 就必须对上，避免串台
    if (!is_undefined(_fired_id) && _fired_id != self.state.dialog_id) {
        return;
    }

    var _is_ok = is_undefined(_fired_stat) || (_fired_stat != 0 && _fired_stat != false);
    var _prev = self.state.text;
    if (_is_ok && is_string(_fired_res) && string_length(_fired_res) > 0) {
        self.state.text = string_copy(_fired_res, 1, 64);
    }
    self.state.dialog_id = -1;
    self.state.focused = false;   // 对话框收工 → 失焦，光标停闪
    if (self.state.text != _prev) {
        emit_change();
    }
}

function on_draw() {
    if (!visible) {
        exit
    }
    var _s = self.state
    draw_set_alpha(0.72)
    draw_set_color(_s.focused ? make_color_rgb(250, 246, 230) : make_color_rgb(236, 228, 208))
    draw_roundrect(_s.left, _s.top, _s.left + _s.width, _s.top + _s.height, false)
    draw_set_alpha(1)
    draw_set_color(_s.focused ? make_color_rgb(120, 82, 40) : make_color_rgb(90, 72, 48))
    draw_roundrect(_s.left, _s.top, _s.left + _s.width, _s.top + _s.height, true)

    var _label = _s.text
    // 安卓：不烘焙 scribble 格式（obj_menu_manager/Create_0.gml:84-97 在安卓提前 return，
    // 唯一创建 font_hei_outline_4dir_black 的 scribble_font_bake_outline_4dir(:99) 永远执行不到），
    // 故安卓回退到真实字体资源 font_hei；与 StageDetail/StageItem 的既有写法一致。
    var _color_name = os_type == os_android ? "font_hei" : "font_hei_outline_4dir_black"
    if (_label == "" && !_s.focused) {
        scribble(_s.placeholder)
            .align(fa_left, fa_middle)
            .starting_format(_color_name)
            .blend(c_gray, 1)
            .draw(_s.left + 12, _s.top + _s.height * 0.5)
    } else {
        if (_label != "") {
            scribble(_label)
                .align(fa_left, fa_middle)
                .starting_format(_color_name)
                .draw(_s.left + 12, _s.top + _s.height * 0.5)
        }
        if (_s.focused && _s.cursor_visible) {
            var _tw = string_width(_label)
            draw_set_color(c_black)
            draw_line(_s.left + 14 + _tw, _s.top + 8, _s.left + 14 + _tw, _s.top + _s.height - 8)
        }
    }
}

on_create()
