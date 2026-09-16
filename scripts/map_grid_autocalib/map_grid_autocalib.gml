/// ============================================================================
/// 十字辅助线「运行时自动标定」—— 让新增地图（含运行时加载的下载地图）零人工介入
///
/// 背景：原先每来一张新地图，都要在 PC 上跑离线脚本 pvz/gen_calibration.py 扫一遍源 PNG，
///       再把结果手写进 scripts/map_grid_calibration 的表里；上游一更新就得重来一遍。
///
/// 本脚本把离线算法（check_calibration.py 的 fit_png）1:1 移植到运行时：
///     贴图 → surface → buffer → 亮度图 → 行/列边缘投影 → 格点穷举拟合 → {ox,oy,cw,ch}
///
/// 真机验证（平板 23013RK75C，release APK，ASTC 6x6 -medium，即装机后贴图的真实状态）：
///     7 张地图逐条比对人工表 → OK=6 MISMATCH=1 FAILED=0，且两次启动结果一致。
///     唯一 MISMATCH 是 cocoa_island_daytime:0（自动 694.0 / 表 680.6）——
///     该条本就是人工手调值，表优先命中，属预期行为而非缺陷。
///     「贴图 → surface → buffer → 亮度」链路实测健康：
///       · buffer_get_surface 在 4 / 512 / 1024 / 2048 / 2005x1080 全部正确回读
///       · 地图贴图确实画进了 surface（扫描区 2250/2250 采样点非零）
///       · 同帧回读与跨帧回读结果一致（不存在 surface flush 时机问题）
///
/// ⚠️ 调用时机（这是真机调通的关键）：本脚本的扫描含 surface 操作，**必须在
///     obj_battle/Create_0 及之后**调用。曾在 obj_game_init/Create_0（游戏最早期）
///     无条件自检，真机上 7/7 SCAN-FAILED —— 那时 GPU/纹理页尚未就绪。
///     移到 obj_battle/Create_0 后立即 6/7 通过。不要再挪回更早的对象。
///
/// 分工（两层，表优先）：
///     map_grid_calibration 的表 = 「人工验证过」的权威层，命中即用
///                                （含 1 条手工调值 cocoa_island_daytime:0，
///                                  以及 1 条 ASTC 往返会误锁的 cumin_bridge_night:0）
///     本脚本                     = 表未覆盖时的兜底层（新地图自动算；算不出则回退逻辑网格）
///
/// 调用约定：只能在 Create / Step 等非绘制事件里做。
///     obj_battle/Create_0 启动时调 painted_grid_warm() 预热；
///     obj_battle/Draw_0 每帧只走 autocalib_peek()（纯查缓存），绝不在 Draw 里扫描。
/// ============================================================================

/// @function autocalib_cache()
/// @description 自动标定结果缓存（键 = "精灵名:帧"；值 = {ox,oy,cw,ch} 或 -1 表示扫描失败）
/// @returns {Id.DsMap}
function autocalib_cache() {
    static _c = undefined;
    if (_c == undefined) {
        _c = ds_map_create();
    }
    return _c;
}

/// @function autocalib_key(spr, frame_index)
/// @description 缓存键
/// @returns {String}
function autocalib_key(spr, frame_index) {
    return sprite_get_name(spr) + ":" + string(frame_index);
}

/// @function autocalib_capture(spr, frame_index, _w, _h)
/// @description 贴图 → surface → buffer（原尺寸 1:1）
///   用 bm_one/bm_zero（源色直写）而非默认混合：默认混合得到 src_rgb * src_alpha，
///   对含半透明像素的地图（如 spr_spice_airship，扫描区 0.32% 像素 alpha<255）会整体压暗
///   并引入伪边缘；离线参考 convert('RGB') 是直接丢弃 alpha 取原始 RGB。
///   该路径已在真机（Android YYC + ASTC）实测正确回读，无需降级方案。
///   读回是否有效由调用方的投影极值判定（全零 → 投影恒 0 → 显式放弃），此处不重复检测。
/// @returns {Id.Buffer} buffer（由调用方 buffer_delete）；surface 创建失败返回 -1
function autocalib_capture(spr, frame_index, _w, _h) {
    var _surf = surface_create(_w, _h);
    if (!surface_exists(_surf)) return -1;

    surface_set_target(_surf);
    draw_clear_alpha(c_black, 0);
    draw_set_alpha(1);
    draw_set_color(c_white);
    gpu_set_blendmode_ext(bm_one, bm_zero);
    draw_sprite_ext(spr, frame_index, sprite_get_xoffset(spr), sprite_get_yoffset(spr), 1, 1, 0, c_white, 1);
    gpu_set_blendmode(bm_normal);
    surface_reset_target();

    var _buf = buffer_create(_w * _h * 4, buffer_fixed, 1);
    buffer_get_surface(_buf, _surf, 0);
    surface_free(_surf);
    return _buf;
}

/// @function autocalib_peek(spr, frame_index)
/// @description 纯查询：只看缓存，不触发扫描（可在 Draw 等绘制事件安全调用）
/// @returns {Struct} {ox, oy, cw, ch} 或 undefined
function autocalib_peek(spr, frame_index) {
    if (!sprite_exists(spr)) return undefined;
    var _c = autocalib_cache();
    var _key = autocalib_key(spr, frame_index);
    if (!ds_map_exists(_c, _key)) return undefined;
    var _v = _c[? _key];
    return (_v == -1) ? undefined : _v;
}

/// @function autocalib_grid_from_sprite(spr, frame_index)
/// @description 取自动标定结果：缓存命中直接返回；未算过则扫描一次（会创建 surface）
///   失败也写哨兵 -1，避免每次调用重复扫描
/// @returns {Struct} {ox, oy, cw, ch} 或 undefined
function autocalib_grid_from_sprite(spr, frame_index) {
    if (!sprite_exists(spr)) return undefined;
    var _c = autocalib_cache();
    var _key = autocalib_key(spr, frame_index);
    if (ds_map_exists(_c, _key)) {
        var _v = _c[? _key];
        return (_v == -1) ? undefined : _v;
    }
    var _r = autocalib_scan_sprite(spr, frame_index);
    ds_map_add(_c, _key, is_struct(_r) ? _r : -1);
    return _r;
}

/// @function autocalib_warm(spr)
/// @description 预热：为表未覆盖的贴图逐帧跑一次自动标定（在 Create/Step 里调用）
///   map_spr_index 在战斗中会在 0..3 之间切换（见 obj_battle/Step_0），故默认扫前 4 帧；
///   贴图帧数不足则按实际帧数。已在缓存里的帧不会重扫。
///   内置 63 张地图 69 帧全被人工表覆盖 → 对内置地图本函数零开销。
/// @param {Asset.GMSprite} spr 地图精灵
/// @param {Real} _max_frames 最多扫描帧数（缺省 4）
/// @returns {Real} 实际扫描的帧数
function autocalib_warm(spr, _max_frames) {
    if (!sprite_exists(spr)) return 0;
    if (_max_frames == undefined) _max_frames = 4;
    var _c = autocalib_cache();
    var _n = min(sprite_get_number(spr), _max_frames);
    var _done = 0;
    for (var _f = 0; _f < _n; _f++) {
        if (ds_map_exists(_c, autocalib_key(spr, _f))) continue;
        autocalib_grid_from_sprite(spr, _f);
        _done++;
    }
    return _done;
}

/// @function autocalib_scan_sprite(spr, frame_index)
/// @description 实际扫描：贴图 → surface → buffer → 边缘投影 → 格点拟合
///   投影窗口与离线 fit_png 逐字一致（行向 = 列 [620,1720) 上 |Δlum| 的行均值；
///   列向 = 行 [130,1040) 上 |Δlum| 的列均值）。
///   遍历范围收敛到「拟合真正会读到的下标」：行 [130,1145] × 列 [620,1765]，
///   其余下标留 0 且永不被读到 → 与全图遍历逐字节等价，但省掉约 46% 的像素读取。
///   ⚠️ 不要在 obj_game_init 等早期对象里调用（GPU/纹理页未就绪 → 全零回读）。
/// @returns {Struct} {ox, oy, cw, ch} 或 undefined
function autocalib_scan_sprite(spr, frame_index) {
    if (!sprite_exists(spr)) return undefined;
    var _w = sprite_get_width(spr);
    var _h = sprite_get_height(spr);
    // 地图贴图规格实测全部为 2005x1080；明显偏小说明不是地图贴图，直接放弃
    if (_w < 1800 || _h < 1000) return undefined;
    if (frame_index < 0 || frame_index >= sprite_get_number(spr)) return undefined;

    // ---- 1) 贴图 → surface → buffer ----
    var _buf = autocalib_capture(spr, frame_index, _w, _h);
    if (_buf == -1) return undefined;

    // ---- 2) 边缘投影（与离线 fit_png 同窗口，单次遍历同时算行向与列向）----
    // 行向 rp[y] 需要列 [620,1720)；列向 cp[x] 需要行 [130,1040)
    // 拟合最低读取下标：行 pos-1 >= 149、列 pos-1 >= 639；最高：行 pos+1 <= 1139、列 <= 1762
    var _r0 = 130, _r1 = min(1146, _h);
    var _c0 = 620, _c1 = min(1766, _w);
    var _cw0 = 620, _cw1 = min(1720, _w);   // 行向投影的列窗口
    var _rh1 = min(1040, _h);               // 列向投影的行窗口上界
    var _span = _c1 - _c0;
    var _nw = _cw1 - _cw0;
    var _nh = _rh1 - 130;

    var _rp = array_create(_h, 0);   // 行向边缘，索引 = 上侧行号
    var _cp = array_create(_w, 0);   // 列向边缘，索引 = 左侧列号
    var _row = array_create(_span, 0);
    var _prev = array_create(_span, 0);
    var _stride = _w * 4;

    for (var _y = _r0; _y < _r1; _y++) {
        var _base = _y * _stride;
        var _rowsum = 0;
        var _prev_lum = -1;
        var _acc_col = (_y < _rh1);
        for (var _i = 0; _i < _span; _i++) {
            // 亮度 = 低 3 字节之和（丢弃高字节）。依据：
            //   ① 颜色三通道对称求和，与 R/G/B 排列顺序无关
            //   ② 高字节即 alpha —— 小端 RGBA8888 的 u32 = A<<24|B<<16|G<<8|R，高字节 = A；
            //      大端 ARGB8888 的 u32 = A<<24|R<<16|G<<8|B，高字节同样是 A
            //   故本式在 RGBA / BGRA / ARGB 任一字节序下都等价于离线参考的 (R+G+B)/3，
            //   且天然排除 alpha（含半透明像素的地图如 spr_spice_airship 不会引入伪边缘）
            var _px = buffer_peek(_buf, _base + (_c0 + _i) * 4, buffer_u32);
            var _lum = ((_px & 255) + ((_px >> 8) & 255) + ((_px >> 16) & 255)) / 3;
            _row[_i] = _lum;
            if (_i > 0 && _acc_col) _cp[_c0 + _i - 1] += abs(_lum - _prev_lum);
            _prev_lum = _lum;
            if (_i >= _cw0 - _c0 && _i < _cw1 - _c0) _rowsum += abs(_lum - _prev[_i]);
        }
        _rp[_y - 1] = _rowsum / _nw;
        // 交换而非逐元素拷贝（_row 每个元素都会在下一轮被覆写）
        var _tmp = _prev; _prev = _row; _row = _tmp;
    }
    // 列向按行窗口长度取均值（与 Python 的 .mean(0) 一致）
    for (var _x = _c0; _x < _c1 - 1; _x++) _cp[_x] /= _nh;

    buffer_delete(_buf);

    // 防御：若 surface 读取失败（全黑/全零），投影会恒为 0，而穷举此时仍会返回边界解
    // （如 [640,150,94,104]）——看起来有效、实则垃圾。这里必须显式判定并放弃，
    // 否则新地图会静默拿到错误网格，比"回退逻辑网格"更糟。
    var _er = 0;
    var _ec = 0;
    for (var _i = 0; _i < _h; _i++) _er = max(_er, _rp[_i]);
    for (var _i = 0; _i < _w; _i++) _ec = max(_ec, _cp[_i]);
    if (_er <= 0 || _ec <= 0) return undefined;

    // ---- 3) 格点穷举拟合（范围/线数/步长与离线完全一致）----
    var _fr = autocalib_lattice_fit(_rp, 150, 270, 104, 124, 8, 0.5);
    var _fc = autocalib_lattice_fit(_cp, 640, 735, 94, 114, 10, 0.5);
    if (_fr.score < 0 || _fc.score < 0) return undefined;

    var _res = {
        ox: round(_fc.o * 10) / 10,
        oy: round(_fr.o * 10) / 10,
        cw: round(_fc.c * 10) / 10,
        ch: round(_fr.c * 10) / 10
    };

    // 合理性窗口（fail-safe）：棋盘视觉网格必然紧邻逻辑网格。
    // 表值实测相对逻辑网格(695/228/107/116)的偏差上限约 ox -31~+20、oy -58~+11、
    // cw -13~+6、ch -12~+8。放宽一倍留余量后作为硬门槛：超出即判定
    // 「读像素链路异常 / 贴图非标准棋盘」，放弃并回退逻辑网格。
    // 最坏情况因此不比现状差 —— 绝不会让新地图拿到看似有效实则错误的网格。
    if (abs(_res.ox - 695) > 45 || abs(_res.oy - 228) > 70
     || abs(_res.cw - 107) > 22 || abs(_res.ch - 116) > 22) {
        return undefined;
    }
    return _res;
}

/// @function autocalib_selftest(_sprites, _max_frames)
/// @description 自检：对给定精灵强制扫描，与人工校准表逐条对比，返回可读报告字符串
///   用途：验证「贴图 → surface → buffer → 亮度」这条链路在真机上确实与离线算法一致。
///   编译通过 ≠ 读像素正确：blend 模式、surface 字节序、alpha 处理任一有偏差都会在此暴露。
///   仅调试模式下由 obj_battle/Step_0 的 G 键调用（有一次性扫描开销）。
/// @param {Array} _sprites 精灵数组（如 [spr_abyss, spr_temple]）
/// @param {Real} _max_frames 每个精灵最多比对帧数（缺省 4）
/// @returns {String} 报告文本
function autocalib_selftest(_sprites, _max_frames) {
    if (_max_frames == undefined) _max_frames = 4;
    var _rep = "=== autocalib selftest ===";
    var _n_ok = 0;
    var _n_bad = 0;
    var _n_fail = 0;
    for (var _si = 0; _si < array_length(_sprites); _si++) {
        var _spr = _sprites[_si];
        if (!sprite_exists(_spr)) continue;
        var _nf = min(sprite_get_number(_spr), _max_frames);
        _rep += "\n-- " + sprite_get_name(_spr) + "  " + string(sprite_get_width(_spr))
              + "x" + string(sprite_get_height(_spr)) + "  frames=" + string(sprite_get_number(_spr));
        for (var _f = 0; _f < _nf; _f++) {
            var _t = painted_grid_table_get(_spr, _f);
            var _a = autocalib_scan_sprite(_spr, _f);
            if (!is_struct(_a)) {
                _n_fail++;
                _rep += "\n   f" + string(_f) + " SCAN-FAILED (surface/buffer 链路有问题)";
                continue;
            }
            if (_t == undefined) {
                _rep += "\n   f" + string(_f) + " no-table auto=[" + string(_a.ox) + "," + string(_a.oy)
                      + "," + string(_a.cw) + "," + string(_a.ch) + "]";
                continue;
            }
            var _dox = abs(_a.ox - _t.ox);
            var _doy = abs(_a.oy - _t.oy);
            var _dcw = abs(_a.cw - _t.cw);
            var _dch = abs(_a.ch - _t.ch);
            var _ok = (_dox <= 8 && _doy <= 8 && _dcw <= 5 && _dch <= 5);
            if (_ok) { _n_ok++; } else { _n_bad++; }
            _rep += "\n   f" + string(_f) + " " + (_ok ? "OK" : "MISMATCH")
                  + " auto=[" + string(_a.ox) + "," + string(_a.oy) + "," + string(_a.cw) + "," + string(_a.ch) + "]"
                  + " table=[" + string(_t.ox) + "," + string(_t.oy) + "," + string(_t.cw) + "," + string(_t.ch) + "]"
                  + " d=[" + string(round(_dox * 10) / 10) + "," + string(round(_doy * 10) / 10)
                  + "," + string(round(_dcw * 10) / 10) + "," + string(round(_dch * 10) / 10) + "]";
        }
    }
    _rep += "\n=== 汇总: OK=" + string(_n_ok) + " MISMATCH=" + string(_n_bad) + " FAILED=" + string(_n_fail) + " ===";
    return _rep;
}

/// @function autocalib_selftest_report(_sprites, _max_frames)
/// @description 自检 + 落盘 + 弹窗，返回报告文本（供 obj_battle/Step_0 的 G 键调用）
///   真机 release 包无 logcat、不可 run-as → show_error_dialog 弹窗 + 截图是唯一取回通道，
///   故除写文件外必须弹窗。显示窗在 900 字符处截断，超长部分靠 [导出错误报告] 复制全文。
/// @returns {String} 报告文本
function autocalib_selftest_report(_sprites, _max_frames) {
    var _rep = autocalib_selftest(_sprites, _max_frames);
    show_debug_message(_rep);
    var _fh = file_text_open_write("autocalib_check.txt");
    if (_fh != -1) {
        file_text_write_string(_fh, _rep);
        file_text_close(_fh);
    }
    show_error_dialog("自动标定自检 (贴图→surface→buffer)", _rep);
    return _rep;
}

/// @function autocalib_lattice_fit(_p, _o_min, _o_max, _c_min, _c_max, _n_lines, _step)
/// @description 在投影曲线上穷举 (原点, 格距)，取「n_lines 条格线都落在边缘峰上」总分最高者
///   每条线要求 3 像素窗口都在界内，否则该候选作废（与离线 valid == n_lines 一致）
/// @returns {Struct} {o, c, score}；无可行解时 score = -1
function autocalib_lattice_fit(_p, _o_min, _o_max, _c_min, _c_max, _n_lines, _step) {
    var _plen = array_length(_p);
    var _best = -1;
    var _bo = _o_min;
    var _bc = _c_min;
    var _no = round((_o_max - _o_min) / _step);
    var _nc = round((_c_max - _c_min) / _step);
    for (var _oi = 0; _oi <= _no; _oi++) {
        var _o = _o_min + _oi * _step;
        for (var _ci = 0; _ci <= _nc; _ci++) {
            var _c = _c_min + _ci * _step;
            var _sc = 0;
            var _ok = true;
            for (var _k = 0; _k < _n_lines; _k++) {
                var _pos = round(_o + _k * _c);
                if (_pos < 2 || _pos >= _plen - 3) { _ok = false; break; }
                _sc += _p[_pos - 1] + _p[_pos] + _p[_pos + 1];
            }
            if (_ok && _sc > _best) {
                _best = _sc;
                _bo = _o;
                _bc = _c;
            }
        }
    }
    return { o: _bo, c: _bc, score: _best };
}
