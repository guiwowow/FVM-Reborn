// =====================================================================
// 全局报错接管：把 GameMaker 原生报错框换成我们自己的弹窗
// =====================================================================
// 用户要求：好看些、能直接复制报错内容、**且信息不能比原生窗少**。
//
// 可行性已在 runtime 里验证：
//   · libyoyo.so 确实导出 exception_unhandled_handler
//   · 原生窗的字符串组装片段是 "…not set before reading it." + "stacktrace" + "at %s"，
//     说明异常结构体里带 longMessage / message / script / line / stacktrace 五个字段。
//   这里把五个**全部**取出拼进弹窗，所以内容与原生窗等价，不是简化版。
//
// 复制通道：show_error_dialog 的 [导出错误报告] 会把 global.error_dialog.full
//   （正文 + 版本 + 平台 + 时间）整份放进剪贴板 —— 屏幕上只显示前 900 字，但复制到的是全文。
//
// return true = 已处理 → 不再弹原生灰窗。
// 任何一步取不到信息都会退化，最差情况显示 string(_e)，绝不吞错、绝不少信息。
//
// 注：这段是**脚本顶层代码**，游戏启动时执行一次，早于所有房间的 Create，
//     所以能接住 obj_game_init 阶段的崩溃（那正是之前踩到的那次）。
// =====================================================================
try {
    exception_unhandled_handler(function(_e) {
        try {
            var _txt = "";
            if is_struct(_e) {
                // ① 主消息：优先 longMessage（原生窗显示的就是它），退到 message
                if (variable_struct_exists(_e, "longMessage")) _txt = string(_e[$ "longMessage"]);
                if (string_length(_txt) <= 0 && variable_struct_exists(_e, "message")) {
                    _txt = string(_e[$ "message"]);
                }
                // ② 出错的脚本名与行号（原生窗 "at gml_Script_xxx" / "(line N)" 那两行）
                if (variable_struct_exists(_e, "script") && string(_e[$ "script"]) != "") {
                    _txt += "\nat " + string(_e[$ "script"]);
                }
                if (variable_struct_exists(_e, "line")) {
                    _txt += " (line " + string(_e[$ "line"]) + ")";
                }
                // ③ 调用栈（原生窗底部那串 gml_Script_xxx / gml_Object_xxx）
                if (variable_struct_exists(_e, "stacktrace")) {
                    var _st = _e[$ "stacktrace"];
                    var _s = "";
                    if (is_array(_st)) {
                        for (var _i = 0; _i < array_length(_st); _i++) {
                            var _fr = _st[_i];
                            if (is_struct(_fr)) {
                                _s += "\n  " + string(_fr[$ "script"]) + " (line " + string(_fr[$ "line"]) + ")";
                            } else {
                                _s += "\n  " + string(_fr);
                            }
                        }
                    } else if (!is_undefined(_st)) {
                        _s = string(_st);
                    }
                    if (string_length(_s) > 0) {
                        _txt += "\n\n调用栈：" + _s;
                    }
                }
            }
            if (string_length(_txt) <= 0) {
                _txt = string(_e);      // 结构体形态不符 → 至少把原样倒出来
            }

            // 同时落一份文件：弹窗只能截图，文件能整份取出（多次报错追加）
            try {
                var _f = file_text_open_append("error_log.txt");
                if (_f >= 0) {
                    file_text_write_string(_f, _txt);
                    file_text_writeln(_f);
                    file_text_close(_f);
                }
            } catch (_e_file) {
                // 写文件失败不影响弹窗
            }

            show_error_dialog("游戏出错", _txt);
            return true;
        } catch (_e_inner) {
            return false;   // 拼装失败 → 交回原生窗，至少不吞错
        }
    });
} catch (_e_install) {
    // 该 runtime 没有 exception_unhandled_handler → 维持原生弹窗，不报错
}

/// @function show_notice(notice_text,life)
// ---- 通知（toast）的样式与动画参数（想改观感只动这几个数字）----
// 白底黑字 + 从屏幕顶端滑入 → 停留 → **原路滑回**消失。
// 配色与下方报错弹窗完全一致（同一套 UI 语言）。
#macro NOTICE_SLIDE_IN   12    // 滑入帧数（≈0.2s）
#macro NOTICE_SLIDE_OUT  14    // 滑回帧数（原路返回，≈0.23s）
#macro NOTICE_REST_RATIO 0.07  // 停留时面板顶边距屏幕顶部的高度比例
#macro NOTICE_PAD_X      36    // 面板左右内边距
#macro NOTICE_PAD_Y      18    // 面板上下内边距
#macro NOTICE_RADIUS     14    // 圆角半径。必须显式给值 —— draw_roundrect 的默认半径
                               // 在低分辨率下弧只有几段，圆角看着像「缺了几块」
#macro NOTICE_GAP        12    // 多条通知同时在屏时的间距

/// @description 在屏幕上显示通知（toast）
/// @param {string} notice_text 通知文本
/// @param {real} life 停留帧数（不含滑入滑出）
function show_notice(notice_text, life) {
    var notice = {
        text: notice_text,
        life: life,
        frames: 0
    };
    if (!variable_global_exists("notice_list")) {
        global.notice_list = [];
    }
    // 自愈：控制器只在 room_init 摆了 1 个实例，而本工程**所有房间的 persistent 都是 false**
    // → 换房间时它可能被销毁，于是通知只进不出（看不到老化、也看不到绘制），
    //   下次它再出现时就会「一堆不同长度的 toast 同时堆在屏幕顶端」。
    // 所以每次弹通知都确认控制器活着，不在就地补一个（depth 与 Create 一致）。
    if (!instance_exists(obj_notice_controller)) {
        instance_create_depth(0, 0, -9900, obj_notice_controller);
    }
    // 上限：最多同时 6 条，超出丢掉最旧的 —— 防止突发刷通知时无限向下堆叠
    while (array_length(global.notice_list) > 6) {
        array_delete(global.notice_list, 0, 1);
    }
    array_push(global.notice_list, notice);
}

/// @description 驱动通知生命周期（由 obj_notice_controller 的 Step 调用）
/// 位置与动画进度在 draw_notices 里按 frames 推算，这里只负责推进与回收。
function update_notices() {
    if (!variable_global_exists("notice_list")) return;
    var _span = NOTICE_SLIDE_IN + NOTICE_SLIDE_OUT;
    for (var i = array_length(global.notice_list) - 1; i >= 0; i--) {
        var notice = global.notice_list[i];
        notice.frames++;
        if (notice.frames > notice.life + _span) {
            array_delete(global.notice_list, i, 1);
            continue;
        }
        global.notice_list[i] = notice;
    }
}

/// @description 绘制所有通知（由 obj_notice_controller 的 Draw 调用）
function draw_notices() {
    if (!variable_global_exists("notice_list")) return;
    // 老化放在绘制入口而不是 Step：只要这一帧真的把通知画出来了，就一定会推进并到期回收。
    // 原先只在 obj_notice_controller/Step_0 里推 —— 一旦那个实例缺席（见 show_notice 里的说明），
    // 通知就永远停在第 0 帧（表现为「贴在屏幕顶端漏出几个像素、一直不消失」）。
    update_notices();

    draw_set_font(font_yuan);
    var _cx      = room_width * 0.5;
    var _maxw    = min(room_width * 0.62, 1120);
    var _rest    = room_height * NOTICE_REST_RATIO;
    var _stack_y = _rest;

    for (var i = 0; i < array_length(global.notice_list); i++) {
        var notice = global.notice_list[i];
        var _text  = notice.text;
        var _scale = 1.0;
        // VM 覆盖：地图脚本用 VM_ShowNotice* 指定过缩放时用脚本值（用后即清）。
        if (variable_global_exists("_VM_notice_scale") && global._VM_notice_scale != -1) {
            _scale = global._VM_notice_scale;
            global._VM_notice_scale = -1;
        }
        if (_scale <= 0) _scale = 1.0;

        // 单行测量（2026-09-21 修「文字不在框中间」）：
        // 原来用 string_height_ext(_text, 90, ...) + draw_text_ext_transformed(..., 90, ...)，
        // 那个 90 是**换行后的行距**，而 font_yuan 行高只有 27px。文本一旦被测成两行，
        // 框高就变成 ~117px，可真正画出来的只有一行且贴着框顶 → 看着就是「文字跑到框上方」。
        // 提示文案本来就是短句，改成单行测量 + 超宽自动缩放，从根上消掉这个变量。
        var _tw = string_width(_text) * _scale;
        if (_tw > _maxw) {
            _scale *= _maxw / _tw;
            _tw = _maxw;
        }
        var _th = string_height(_text) * _scale;
        var _pw = _tw + NOTICE_PAD_X * 2;
        var _ph = _th + NOTICE_PAD_Y * 2;

        // 动画进度 _t：0 = 完全在屏幕顶部之外，1 = 落位
        var _t;
        if (notice.frames <= NOTICE_SLIDE_IN) {
            _t = notice.frames / NOTICE_SLIDE_IN;          // 滑入：线性（2026-09-21 按用户要求从 ease-out 改回）
        } else if (notice.frames <= NOTICE_SLIDE_IN + notice.life) {
            _t = 1;                                        // 停留
        } else {
            _t = 1 - (notice.frames - NOTICE_SLIDE_IN - notice.life) / NOTICE_SLIDE_OUT;   // 原路滑回
        }
        _t = clamp(_t, 0, 1);
        // 完全收起（_t 到底）就整条不画：否则面板顶边算下来仍可能残留几个像素贴在屏幕顶端
        if (_t <= 0) continue;
        // 未落位时整体抬到屏幕上方：面板高 + 停留位 + 余量
        var _off = -(1 - _t) * (_ph + _rest + 80);

        var _x1 = _cx - _pw * 0.5;
        var _y1 = _stack_y + _off;
        var _x2 = _x1 + _pw;
        var _y2 = _y1 + _ph;

        // 面板：白底 + 黑色边框 + 底部阴影（2026-09-21 按用户要求改）
        // 用 draw_roundrect_ext 显式给半径：默认半径在低分辨率下弧只有几段，
        // 圆角看起来像「缺了几块」；半径变大后弧的段数随之增加，圆角才顺。
        var _rad = NOTICE_RADIUS;
        // ① 底部阴影：整体右下偏移的半透明黑圆角块，先画 → 被面板盖住上半，只在下方/右侧露出
        draw_set_alpha(0.30);
        draw_set_color(c_black);
        draw_roundrect_ext(_x1 + 3, _y1 + 5, _x2 + 3, _y2 + 5, _rad, _rad, false);
        // ② 面板本体：白底
        draw_set_alpha(1);
        draw_set_color(make_color_rgb(246, 246, 248));
        draw_roundrect_ext(_x1, _y1, _x2, _y2, _rad, _rad, false);
        // ③ 黑色边框 2px：外描一圈 + 内缩 1px 再描一圈
        draw_set_color(c_black);
        draw_roundrect_ext(_x1, _y1, _x2, _y2, _rad, _rad, true);
        draw_roundrect_ext(_x1 + 1, _y1 + 1, _x2 - 1, _y2 - 1, _rad - 1, _rad - 1, true);

        // 文字：默认黑字；地图脚本可覆盖颜色（VM_ShowNoticeColor）
        var _tc = make_color_rgb(28, 28, 38);
        if (variable_global_exists("_VM_notice_color_r") && global._VM_notice_color_r != -1) {
            _tc = make_color_rgb(
                min(max(0, global._VM_notice_color_r), 255),
                min(max(0, global._VM_notice_color_g), 255),
                min(max(0, global._VM_notice_color_b), 255));
            global._VM_notice_color_r = -1;
        }
        draw_set_color(_tc);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text_transformed(_cx, (_y1 + _y2) * 0.5, _text, _scale, _scale, 0);

        _stack_y += _ph + NOTICE_GAP;
    }

    // 复位绘制状态
    draw_set_alpha(1);
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// =====================================================================
// 报错弹窗（形态对齐 GameMaker 自带运行时报错框）
//   标题 + 正文 + 两个按钮：[确定] / [导出错误报告]（导出 = 把完整报错信息复制到剪贴板）
//   取代 show_message_async：系统弹窗在安卓上无法定制按钮，也没有"导出报错信息"。
//   由 obj_notice_controller 的 Step/Draw 驱动（update_error_dialog / draw_error_dialog）。
// =====================================================================

/// @function is_error_dialog_open()
/// @returns {Bool} 是否有报错弹窗开着（供底层交互屏蔽）
function is_error_dialog_open() {
    return variable_global_exists("error_dialog") && !is_undefined(global.error_dialog);
}

/// @function show_error_dialog(title, body)
/// @description 弹出自定义报错窗。导出的报告会附版本/平台/时间/链路诊断，便于回报。
/// @param {String} _title 标题，如「下载失败」
/// @param {String} _body  正文（换行用 \n）
function show_error_dialog(_title, _body) {
    var _full = string(_body);
    _full += "\n\n———— 报错报告 ————";
    _full += "\n标题: " + string(_title);
    if (variable_global_exists("game_version")) {
        _full += "\n版本: " + string(global.game_version);
    }
    _full += "\n平台: " + string(os_type) + "    时间: " + date_datetime_string(date_current_datetime());
    global.error_dialog = {
        title: string(_title),
        body: string(_body),
        full: _full,
        copied: 0
    };
}

/// @function error_dialog_layout()
/// @returns {Struct} 视野、面板与两个按钮的矩形（update 与 draw 共用，保证点击区与绘制一致）
function error_dialog_layout() {
    // 本工程 UI 全部使用**房间坐标**（实验室房间 enableViews=false，没有相机；
    // 参照 LaboratoryGUI 的 set_position(room_width - 170, 60) 等写法），
    // 所以这里以 room_width/room_height 为基准居中，不要用 camera_get_view_*。
    var _cx = 0;
    var _cy = 0;
    var _cw = room_width;
    var _ch = room_height;
    if (_cw <= 0) {
        _cw = display_get_width();
    }
    if (_ch <= 0) {
        _ch = display_get_height();
    }
    var _w = min(_cw * 0.74, 1120);
    var _h = min(_ch * 0.62, 640);
    var _x1 = _cx + (_cw - _w) * 0.5;
    var _y1 = _cy + (_ch - _h) * 0.5;
    var _bw = 268;
    var _bh = 66;
    var _gap = 48;
    var _by1 = _y1 + _h - _bh - 30;
    var _ok_x1 = _x1 + _w * 0.5 - _gap * 0.5 - _bw;
    var _ex_x1 = _x1 + _w * 0.5 + _gap * 0.5;
    return {
        cx: _cx, cy: _cy, cw: _cw, ch: _ch,
        x1: _x1, y1: _y1, x2: _x1 + _w, y2: _y1 + _h,
        ok_x1: _ok_x1, ok_y1: _by1, ok_x2: _ok_x1 + _bw, ok_y2: _by1 + _bh,
        ex_x1: _ex_x1, ex_y1: _by1, ex_x2: _ex_x1 + _bw, ex_y2: _by1 + _bh
    };
}

/// @function update_error_dialog()
/// @description 处理两个按钮的点击（【导出错误报告】= 复制完整报错信息到剪贴板）
function update_error_dialog() {
    if (!is_error_dialog_open()) return;
    var _d = global.error_dialog;
    if (_d.copied > 0) {
        _d.copied -= 1;
    }
    var _L = error_dialog_layout();
    var _mx = mouse_x;
    var _my = mouse_y;
    if (mouse_check_button_pressed(mb_left)) {
        if (_mx >= _L.ok_x1 && _mx <= _L.ok_x2 && _my >= _L.ok_y1 && _my <= _L.ok_y2) {
            global.error_dialog = undefined;
            return;
        }
        if (_mx >= _L.ex_x1 && _mx <= _L.ex_x2 && _my >= _L.ex_y1 && _my <= _L.ex_y2) {
            clipboard_set_text(string(_d.full));
            _d.copied = 150;
        }
    }
    global.error_dialog = _d;
}

/// @function draw_error_dialog()
function draw_error_dialog() {
    if (!is_error_dialog_open()) return;
    var _d = global.error_dialog;
    var _L = error_dialog_layout();
    // 遮罩（铺满整个视野）
    draw_set_alpha(0.55);
    draw_set_color(c_black);
    draw_rectangle(_L.cx, _L.cy, _L.cx + _L.cw, _L.cy + _L.ch, false);
    draw_set_alpha(1);
    // 面板
    draw_set_color(make_color_rgb(246, 246, 248));
    draw_roundrect(_L.x1, _L.y1, _L.x2, _L.y2, false);
    draw_set_color(make_color_rgb(120, 120, 130));
    draw_roundrect(_L.x1, _L.y1, _L.x2, _L.y2, true);
    // 标题 + 分隔线
    draw_set_font(font_yuan);
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_color(make_color_rgb(28, 28, 38));
    draw_text_transformed(_L.x1 + 34, _L.y1 + 48, string(_d.title), 1.5, 1.5, 0);
    draw_set_color(make_color_rgb(180, 180, 190));
    draw_line(_L.x1 + 30, _L.y1 + 86, _L.x2 - 30, _L.y1 + 86);
    // 正文（显示用；过长只截断显示，导出仍是全文）
    // 正文：先按字数截断，再按**可用高度**截断
    //   —— draw_text_ext 的第 5 参只管换行宽度，**不做裁剪**。
    //     原来的 900 字按 34px 行距约 22 行 ≈ 750px，而面板可用高度只有约 400px
    //     → 长报错直接画到窗口外面（真机实测）。所以必须自己算高度并截。
    var _maxw  = (_L.x2 - _L.x1) - 68;
    var _avail = (_L.ok_y1 - 24) - (_L.y1 + 106);      // 从正文顶到按钮上方
    if (_avail < 40) _avail = 40;
    var _show = string(_d.body);
    if (string_length(_show) > 900) _show = string_copy(_show, 1, 900);
    if (string_height_ext(_show, 34, _maxw) > _avail) {
        var _n = string_length(_show);
        while (_n > 20 && string_height_ext(string_copy(_show, 1, _n), 34, _maxw) > _avail) {
            _n -= 20;
        }
        _show = string_copy(_show, 1, _n) + "\n…（内容过长，点[导出错误报告]可复制完整信息）";
    }
    draw_set_color(make_color_rgb(40, 40, 50));
    draw_set_valign(fa_top);
    draw_text_ext(_L.x1 + 34, _L.y1 + 106, _show, 34, _maxw);
    // 两个按钮
    var _mx = mouse_x;
    var _my = mouse_y;
    var _over_ok = (_mx >= _L.ok_x1 && _mx <= _L.ok_x2 && _my >= _L.ok_y1 && _my <= _L.ok_y2);
    var _over_ex = (_mx >= _L.ex_x1 && _mx <= _L.ex_x2 && _my >= _L.ex_y1 && _my <= _L.ex_y2);
    draw_set_color(_over_ok ? make_color_rgb(96, 152, 224) : make_color_rgb(76, 128, 200));
    draw_roundrect(_L.ok_x1, _L.ok_y1, _L.ok_x2, _L.ok_y2, false);
    draw_set_color(_over_ex ? make_color_rgb(96, 170, 110) : make_color_rgb(70, 148, 86));
    draw_roundrect(_L.ex_x1, _L.ex_y1, _L.ex_x2, _L.ex_y2, false);
    draw_set_color(c_white);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text_transformed((_L.ok_x1 + _L.ok_x2) * 0.5, (_L.ok_y1 + _L.ok_y2) * 0.5, "确定", 1.15, 1.15, 0);
    draw_text_transformed((_L.ex_x1 + _L.ex_x2) * 0.5, (_L.ex_y1 + _L.ex_y2) * 0.5, "导出错误报告", 1.15, 1.15, 0);
    if (_d.copied > 0) {
        draw_set_color(make_color_rgb(28, 28, 38));
        draw_set_valign(fa_bottom);
        draw_text_transformed((_L.ex_x1 + _L.ex_x2) * 0.5, _L.ex_y1 - 10, "报错信息已复制到剪贴板", 1.0, 1.0, 0);
    }
    // 复位绘制状态
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1);
    draw_set_color(c_white);
}