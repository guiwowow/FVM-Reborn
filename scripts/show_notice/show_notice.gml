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
#macro NOTICE_SCALE      1.15  // 整体放大倍数（2026-10-02 按用户要求：面板/文字/圆角/阴影一起放大）

// 停留时长（2026-09-23 按用户要求）：关卡外常驻 2s、关卡内常驻 2.5s。
// 这两个值是**下限** —— 调用方传更长（崩溃提示 600 / 倍速提示 180）时以调用方为准。
#macro NOTICE_REST_MENU   120  // 关卡外：2.0s
#macro NOTICE_REST_BATTLE 150  // 关卡内：2.5s
#macro NOTICE_INPUT_GRACE  60  // 检测到屏幕输入后 1.0s 收起（仅关卡外生效）

/// @description 在屏幕上显示通知（toast）
/// @param {string} notice_text 通知文本
/// @param {real} life 停留帧数（不含滑入滑出）
function show_notice(notice_text, life) {
    // 停留时长下限：关卡内 2.5s / 关卡外 2s（调用方传更长则听调用方的）
    if (is_undefined(life)) life = 0;
    life = max(life, instance_exists(obj_battle) ? NOTICE_REST_BATTLE : NOTICE_REST_MENU);
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
    // 同文案去重：队列里已有同一条就把**那一条**重新计时（而不是再推一条）
    //   —— 周期性触发的提示（例如每 0.8s 一次的倍速探测）若不去重，
    //     会变成「同一条通知永远停在滑入起点」，屏幕上就是一条几像素的残影。
    for (var _di = 0; _di < array_length(global.notice_list); _di++) {
        var _old_n = global.notice_list[_di];
        if (_old_n.text == notice_text) {
            _old_n.frames = 0;
            _old_n.life   = life;
            global.notice_list[_di] = _old_n;
            return;
        }
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
    // 屏幕有输入 ⇒ 这条通知 1 秒后收起；关卡内**不受输入影响**（固定 2.5s）。
    // 只在滑入完成后判定：弹出这条通知的那一下点击本身也是"输入"，
    // 不排除的话它刚出现就被判成"有输入"，2s 常驻等于没有。
    var _input = !instance_exists(obj_battle) && mouse_check_button_pressed(mb_left);
    for (var i = array_length(global.notice_list) - 1; i >= 0; i--) {
        var notice = global.notice_list[i];
        notice.frames++;
        if (_input && notice.frames > NOTICE_SLIDE_IN) {
            notice.life = min(notice.life, notice.frames + NOTICE_INPUT_GRACE);
        }
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
        _scale *= NOTICE_SCALE;   // 整体放大（VM 指定过缩放时也跟着放大 1.15 倍，保持一致）

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
        var _pw = _tw + NOTICE_PAD_X * 2 * NOTICE_SCALE;
        var _ph = _th + NOTICE_PAD_Y * 2 * NOTICE_SCALE;

        // 动画进度 _t：0 = 完全在屏幕顶部之外，1 = 落位
        // 2026-10-02 按用户要求改成非线性：滑入三次缓出（进来快、落位慢），滑回三次缓入（起步慢、离场快）。
        // 用乘法展开而不是 power()，少一次函数调用（toast 每帧都在算）。
        var _t;
        var _p;
        if (notice.frames <= NOTICE_SLIDE_IN) {
            _p = notice.frames / NOTICE_SLIDE_IN;
            var _q = 1 - _p;
            _t = 1 - _q * _q * _q;                          // ease-out cubic
        } else if (notice.frames <= NOTICE_SLIDE_IN + notice.life) {
            _t = 1;                                        // 停留
        } else {
            _p = (notice.frames - NOTICE_SLIDE_IN - notice.life) / NOTICE_SLIDE_OUT;
            _t = 1 - _p * _p * _p;                          // ease-in cubic（原路滑回）
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

        // 几何硬保证：面板在屏幕上**露出的高度**不足一个内边距就整条不画。
        //   只判 _t<=0 不够 —— 滑入/滑出的中间帧本来就会"只露几像素"，
        //   一旦 frames 因任何原因卡在那一帧，屏幕上就永远挂着一条细边。
        //   这里按最终坐标判，跟动画进度、房间高度、面板宽度全都无关。
        if (_y2 < NOTICE_PAD_Y * NOTICE_SCALE) continue;

        // 面板：白底 + 黑色边框 + 底部阴影（2026-09-21 按用户要求改）
        // 用 draw_roundrect_ext 显式给半径：默认半径在低分辨率下弧只有几段，
        // 圆角看起来像「缺了几块」；半径变大后弧的段数随之增加，圆角才顺。
        var _rad = NOTICE_RADIUS * NOTICE_SCALE;
        var _sh  = 3 * NOTICE_SCALE;
        var _sv  = 5 * NOTICE_SCALE;
        // ① 底部阴影：整体右下偏移的半透明黑圆角块，先画 → 被面板盖住上半，只在下方/右侧露出
        draw_set_alpha(0.30);
        draw_set_color(c_black);
        draw_roundrect_ext(_x1 + _sh, _y1 + _sv, _x2 + _sh, _y2 + _sv, _rad, _rad, false);
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

// 通用悬浮提示框（tooltip）：尺寸非线性过渡 + 消失宽限 + 缩小消失
// 每个实例各持一份，任何 Draw 事件里这样用：
//     if (悬停成立) tooltip_set(_x, _y, _文本, _方向);   // +1 = 框在锚点右侧；-1 = 左侧
//     tooltip_draw();                                    // 该 Draw 事件末尾调一次
// 速率与宽限参数在 Tooltip 构造函数里。
// ══════════════════════════════════════════════════════════════════════
function Tooltip() constructor {
    self.anim_w = 0; self.anim_h = 0;         // 当前显示的框尺寸
    self.anim_tw = -1; self.anim_th = -1;     // 目标尺寸（-1 = 没有内容）
    self.speed = 0.06;                        // 本段过渡的当前速率（逐帧爬升 → 起步缓慢、后段加快）
    self.speed_start = 0.06;
    self.speed_step  = 0.05;
    self.speed_max   = 0.40;
    self.text = ""; self.tx = 0; self.ty = 0; self.dir = 1; self.font = -1;
    self.showing = false;                     // 本帧有没有命中
    self.hold = 0; self.hold_frames = 3;      // 0.05s @60fps：扫过空隙不闪，也决定消失前等多久
    self.out_t = -1;                          // 消失进度（-1 = 没在消失）
    self.box_alpha = 0.7;                     // 提示框底色的不透明度（各面板原值不同，按调用点指定）
    self.fill_col = c_black;                  // 底色
    self.border_col = -1;                     // 描边色（-1 = 不描边）
    self.text_col = c_white;                  // 文字色

    /// @param {Real} _dir +1 = 框在锚点右侧；-1 = 框在锚点左侧
    static set = function(_x, _y, _text, _dir, _box_alpha, _style, _gen) {
        self.box_alpha = _box_alpha;
        self.gen = _gen;
        if (is_undefined(_style)) {
            self.fill_col = c_black; self.border_col = -1; self.text_col = c_white;
        } else {
            self.fill_col = _style.fill; self.border_col = _style.border; self.text_col = _style.text_col;
        }
        self.tx = _x; self.ty = _y; self.dir = _dir;
        if (_text != self.text) {
            self.text = _text;
            self.font = draw_get_font();
        }
        self.showing = true;
        self.hold = 0;
        self.out_t = -1;
        var _pf = draw_get_font();
        draw_set_font(self.font);
        var _lines = string_split(_text, "\n");
        var _tw = 0;
        var _th = 0;
        for (var _i = 0; _i < array_length(_lines); _i++) {
            var _ln = _lines[_i];
            if (_ln == "") _ln = " ";
            _tw = max(_tw, string_width(_ln));
            _th += string_height(_ln);
        }
        _tw = _tw + 10;
        _th = _th + 10;
        draw_set_font(_pf);
        if (_tw != self.anim_tw || _th != self.anim_th) self.speed = self.speed_start;
        self.anim_tw = _tw;
        self.anim_th = _th;
    };

    static draw = function() {
        // 同一帧只允许一个提示框：别处刚 set 过，自己立刻收掉不画
        if (!variable_global_exists("tt_gen") || self.gen != global.tt_gen) {
            self.anim_w = 0; self.anim_h = 0;
            self.anim_tw = -1; self.anim_th = -1;
            self.text = ""; self.out_t = -1; self.showing = false; self.hold = 0;
            return;
        }
        if (!ui_anim_on(2)) {                             // 动效等级 <2：瞬显瞬消（不做尺寸过渡/容器揭示/淡出）
            if (self.anim_tw >= 0) { self.anim_w = self.anim_tw; self.anim_h = self.anim_th; }
            if (!self.showing) {
                self.hold++;
                if (self.hold > self.hold_frames) {
                    self.anim_w = 0; self.anim_h = 0;
                    self.anim_tw = -1; self.anim_th = -1;
                    self.text = ""; self.out_t = -1; self.speed = self.speed_start;
                }
            }
        } else if (!self.showing) {                       // 这一帧没命中
            self.hold++;
            if (self.hold > self.hold_frames && self.out_t < 0 && self.anim_tw >= 0) {
                self.out_t = 0;                           // 宽限结束 → 缩小消失
                self.speed = self.speed_start;
            }
        }
        if (self.anim_tw >= 0) {
            if (self.showing || self.out_t >= 0) {
                // 每帧推近当前速率：放大 / 缩小 / 消失都走这一条，速率逐帧爬升（起步缓慢），
                // 没有计时器，所以不会一步到位。
                self.speed = min(self.speed_max, self.speed + self.speed_step);
                if (self.out_t >= 0) {
                    self.out_t++;
                    self.anim_w -= self.anim_w * self.speed;          // 消失：朝锚点收成 0
                    self.anim_h -= self.anim_h * self.speed;
                    if (self.anim_w <= 1.5 || self.anim_h <= 1.5 || self.out_t > 120) {
                        self.out_t = -1; self.anim_w = 0; self.anim_h = 0;
                        self.anim_tw = -1; self.anim_th = -1; self.text = ""; self.speed = self.speed_start;
                    }
                } else {
                    self.anim_w += (self.anim_tw - self.anim_w) * self.speed;
                    self.anim_h += (self.anim_th - self.anim_h) * self.speed;
                    if (abs(self.anim_tw - self.anim_w) < 0.5 && abs(self.anim_th - self.anim_h) < 0.5) {
                        self.anim_w = self.anim_tw; self.anim_h = self.anim_th;
                    }
                }
            }
        } else {
            self.anim_w = 0; self.anim_h = 0;
        }

        if (self.anim_tw >= 0 && self.text != "" && self.anim_w > 2) {
            var _prev_font = draw_get_font();
            draw_set_font(self.font);

            // 文字比容器早一步出现：揭示范围 = 容器当前尺寸 + 剩余差距的 30%（约 0.2 秒）
            var _lead = 0.30;
            var _rw = self.anim_w;
            var _rh = self.anim_h;
            if (self.out_t < 0 && self.anim_tw >= 0) {
                _rw = self.anim_w + (self.anim_tw - self.anim_w) * _lead;
                _rh = self.anim_h + (self.anim_th - self.anim_h) * _lead;
            }
            // 容器画的时候永远不小于文字（文字领着走、框贴上去），所以文字绝不会露到框外
            var _draw_w = max(self.anim_w, _rw);
            var _draw_h = max(self.anim_h, _rh);

            // 容器
            var _by1 = self.ty - 5;
            var _by2 = self.ty - 5 + _draw_h;
            var _bx1, _bx2;
            if (self.dir > 0)      { _bx1 = self.tx - 5;              _bx2 = self.tx - 5 + _draw_w; }
            else if (self.dir < 0) { _bx1 = self.tx + 5 - _draw_w;     _bx2 = self.tx + 5; }
            else                   { _bx1 = self.tx - _draw_w / 2;     _bx2 = self.tx + _draw_w / 2; }
            draw_set_halign(fa_left);            // 必须显式复位：调用者可能设成居中/中缝
            draw_set_valign(fa_top);             // （框是矩形不受影响，但逐字绘制会整体错位）
            draw_set_color(self.fill_col);
            draw_set_alpha(self.box_alpha);
            draw_rectangle(_bx1, _by1, _bx2, _by2, false);
            if (self.border_col != -1) {
                draw_set_color(self.border_col);
                draw_set_alpha(1);
                draw_rectangle(_bx1, _by1, _bx2, _by2, true);
            }

            // 文字：容器长到哪儿就显示到哪儿（容器盖住的那部分文字才画出来）
            draw_set_color(self.text_col);
            draw_set_alpha(1);
            var _lines = string_split(self.text, "\n");
            // 揭示范围按"实际画出来的框"算（不是按提前量），这样文字在结构上不可能超出容器
            var _avail_h = _draw_h - 8;
            var _block_w = max(1, self.anim_tw - 10);          // 多行文字按整块对齐（各行左端对齐）
            var _yy = self.ty;
            for (var _i = 0; _i < array_length(_lines); _i++) {
                var _ln = _lines[_i];
                var _lh = string_height(_ln);
                if (_lh < 1) _lh = string_height(" ");
                if (_yy + _lh > self.ty + _avail_h) break;          // 容器还没长到这一行 → 后面的都不画
                // 文字画在它本来该在的位置（不因为框还小就挪位），只把框已经覆盖到的字画出来。
                // 框扫到哪儿、字露到哪儿；框还没扫到的地方一个字都不画 —— 所以不可能跑到框外面。
                // 文字（整块）在框内的绝对位置，全部由框的矩形算出来，不依赖鼠标/目标尺寸：
                //   框够宽 → 整块右端贴框内右沿（保持原来的样子）
                //   框不够宽 → 整块贴住框内左沿（此时右边不足的部分不画，等框长过来）
                var _inner_l = _bx1 + 5;
                var _inner_r = _bx2 - 5;
                var _x0;
                if (self.dir > 0)      { _x0 = _inner_l; }
                else if (self.dir < 0) { _x0 = max(_inner_l, _inner_r - _block_w); }
                else                   { _x0 = max(_inner_l, _inner_l + (_inner_r - _inner_l - _block_w) / 2); }
                var _limit_l = _inner_l;
                var _limit_r = _inner_r;
                var _pen = _x0;
                for (var _k = 1; _k <= string_length(_ln); _k++) {
                    var _ch = string_char_at(_ln, _k);
                    var _cw = string_width(_ch);
                    if (_pen + _cw > _limit_r) break;                      // 超出框右沿 → 后面的字不画
                    if (_pen >= _limit_l) draw_text(_pen, _yy, _ch);       // 只画框已经盖住的那部分
                    _pen += _cw;
                }

                _yy += _lh;
            }
            draw_set_font(_prev_font);
        }
        draw_set_alpha(1);
        self.showing = false;                             // 下一帧重新判定命中
    };
}

/// @function tooltip_set(_x, _y, _text, _dir)
/// @description 当前实例的提示框：记录要显示的内容并设定目标尺寸（不绘制）。
function tooltip_set(_x, _y, _text, _dir) {
    // 第 5 个参数（可选）= 框底色的不透明度；第 6 个（可选）= 槽位（同一实例的第二个 Draw 事件用 1）
    var _a    = (argument_count >= 5) ? argument[4] : 0.7;
    var _slot = (argument_count >= 6) ? argument[5] : 0;
    var _style = (argument_count >= 7) ? argument[6] : undefined;
    // 谁最后 set，谁就是本帧唯一的提示框（别的会在自己的 draw 里立刻收掉）
    global.tt_gen = variable_global_exists("tt_gen") ? global.tt_gen + 1 : 1;
    if (_slot == 1) {
        if (!variable_instance_exists(id, "__tooltip_b")) __tooltip_b = new Tooltip();
        __tooltip_b.set(_x, _y, _text, _dir, _a, _style, global.tt_gen);
    } else {
        if (!variable_instance_exists(id, "__tooltip")) __tooltip = new Tooltip();
        __tooltip.set(_x, _y, _text, _dir, _a, _style, global.tt_gen);
    }
}

/// @function tooltip_draw()
/// @description 当前实例的提示框：推进动画并绘制。在该 Draw 事件末尾调一次。
function tooltip_draw() {
    var _slot = (argument_count >= 1) ? argument[0] : 0;
    if (_slot == 1) {
        if (variable_instance_exists(id, "__tooltip_b")) __tooltip_b.draw();
    } else {
        if (variable_instance_exists(id, "__tooltip")) __tooltip.draw();
    }
}
