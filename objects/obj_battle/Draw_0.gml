// 地图背景（支持地图脚本换背景：VM_SetMapBackground 改 target，这里做交叉淡入过渡）
// 移植自联机版 obj_battle/Draw_0：cur==tgt 时直接画；否则两张按 alpha 叠画并推进过渡进度。
// 无脚本时两者恒等 → 与原来的 draw_sprite 行为完全一致，零开销。
var _cur = global.map_sprite_current;
var _tgt = global.map_sprite_target;
if (_cur == _tgt) {
    draw_sprite(_cur, map_spr_index, 0, 0);
    global.map_fade_alpha = 0;
} else {
    var _a = global.map_fade_alpha;
    draw_sprite_ext(_cur, map_spr_index, 0, 0, 1, 1, 0, c_white, 1 - _a);
    draw_sprite_ext(_tgt, map_spr_index, 0, 0, 1, 1, 0, c_white, _a);
    _a += global.map_fade_step;
    if (_a >= 1) {
        global.map_sprite_current = _tgt;
        _a = 0;
    }
    global.map_fade_alpha = _a;
}

// PVZ 式放置引导线：选中卡片/铲子时高亮鼠标所在行+列（白色半透明）
// 画在 obj_battle 层（depth 50）→ 地图之上、植物之下（PVZ 同款层级）
// 列/行索引按逻辑网格取（= 植物实际落点格）；像素位置用贴图校准网格（视觉贴格，get_painted_grid）
// 未校准地图回退逻辑网格；移动平台关跟随平台移动
var _show = false;
var _psx = 0;
var _psy = 0;
var _pv = instance_find(obj_card_preview, 0);
if (instance_exists(_pv)) {
    _show = true;
    _psx = _pv.platform_shift_x;
    _psy = _pv.platform_shift_y;
} else if (instance_exists(obj_shovel_slot) && obj_shovel_slot.is_selected) {
    _show = true;
}
if (_show && !global.is_paused) {
    var _g = get_painted_grid(global.level_data.level_sprite, map_spr_index);
    var _ox = global.grid_offset_x + _psx;
    var _oy = global.grid_offset_y + _psy;
    var _cw = global.grid_cell_size_x;
    var _ch = global.grid_cell_size_y;
    if (_g != undefined) {
        _ox = _g.ox + _psx;
        _oy = _g.oy + _psy;
        _cw = _g.cw;
        _ch = _g.ch;
    }
    var _col = clamp(floor((mouse_x - (global.grid_offset_x + _psx)) / global.grid_cell_size_x), 0, global.grid_cols - 1);
    var _row = clamp(floor((mouse_y - (global.grid_offset_y + _psy)) / global.grid_cell_size_y), 0, global.grid_rows - 1);
    draw_set_alpha(0.35);
    draw_set_color(c_white);
    draw_rectangle(_ox, _oy + _row * _ch, _ox + global.grid_cols * _cw, _oy + (_row + 1) * _ch, false);
    draw_rectangle(_ox + _col * _cw, _oy, _ox + (_col + 1) * _cw, _oy + global.grid_rows * _ch, false);
    draw_set_alpha(1);
}

// 固定 64 个贴图槽（地图脚本 VM_SetDrawSlot）：画在地图层之上、HUD 之下。
// 无脚本时全部是 noone → 循环 64 次空转，开销可忽略。
for (var _si = 0; _si < 64; _si++) {
    var _slot = global.map_draw_slots[_si];
    if (_slot.sprite == noone || _slot.sprite == "" || _slot.sprite == -1) continue;
    draw_sprite_ext(_slot.sprite, 0, _slot.x, _slot.y, _slot.image_xscale, _slot.image_yscale, _slot.image_angle, c_white, _slot.alpha);
}

draw_set_valign(fa_top)
draw_set_halign(fa_left)
draw_set_color(c_white)
draw_set_font(font_yuan)
draw_text(0,0,"FPS:"+string(fps))
draw_text(0,25,"加速:"+(speed_up ? "开" : "关") + "（shift）")
draw_text(0,50,"暂停（空格）\n菜单（ESC）")

// 十字线校准缺失提示（仅调试模式）：表未收录且运行时自动标定也失败 → 十字线回退逻辑网格（偏 30~45px）
if (global.debug && variable_global_exists("painted_grid_missing") && array_length(global.painted_grid_missing) > 0) {
    var _miss = "";
    for (var _i = 0; _i < array_length(global.painted_grid_missing); _i++) {
        _miss += global.painted_grid_missing[_i] + "  ";
    }
    draw_set_color(c_red);
    // 纯 ASCII：font_yuan 只保证覆盖 32..127，⚠(U+26A0) 等符号不在字形表内会显示成方块
    draw_text(0, 90, "! GRID CALIB MISSING (run pvz/gen_calibration.py --write): " + _miss);
    draw_set_color(c_white);
}

// 2 倍速探测状态（仅调试模式 global.debug=1）：验证「免回弹」就看这一行
//   瞬时FPS = 1000000/delta_time —— 判定用的就是它，不是上面那个 1 秒平滑的 fps
//   状态 0=空闲 1=空转期 2=采样期 | 铁证=本关是否已跑出过 >=100 帧（是 ⇒ 本关内永不被撤回）
if (global.debug) {
    var _fps_now = (delta_time > 0) ? floor(1000000 / delta_time) : 0;
    var _proven  = (variable_global_exists("speed_up_proven") && global.speed_up_proven) ? "是" : "否";
    var _probe   = variable_global_exists("speed_up_probe_state") ? global.speed_up_probe_state : -1;
    var _2x      = (variable_global_exists("speed_up_active") && global.speed_up_active) ? "开" : "关";
    draw_set_color(c_yellow);
    draw_text(0, 115, "2x探测: 瞬时FPS=" + string(_fps_now) + "  状态=" + string(_probe)
                    + "  铁证=" + _proven + "  2x=" + _2x);
    draw_set_color(c_white);
}
