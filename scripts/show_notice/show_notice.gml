/// @function show_notice(notice_text,life)
/// @description 在屏幕上显示通知
/// @param {string} notice_text 通知文本
/// @param {real} life 通知存在的时间
function show_notice(notice_text, life) {
    // 创建通知数据结构
    var notice = {
        text: notice_text,
        life: life,
        total_life: life,
        frames: 0,
        alpha: 0,
        scale: 1.2,
        pos_x: room_width / 2,
        pos_y: room_height / 3,
        target_y: camera_get_view_y(view_camera[0]) + camera_get_view_height(view_camera[0]) / 3
    };
    
    // 如果没有全局通知列表，则创建一个
    if (!variable_global_exists("notice_list")) {
        global.notice_list = [];
    }
    
    // 将新通知添加到列表
    array_push(global.notice_list, notice);
}

// 在某个控制对象的步事件中更新所有通知
function update_notices() {
    if (!variable_global_exists("notice_list")) return;
    
    var camera_x = camera_get_view_x(view_camera[0]);
    var camera_y = camera_get_view_y(view_camera[0]);
    var camera_w = camera_get_view_width(view_camera[0]);
    var camera_h = camera_get_view_height(view_camera[0]);
    
    for (var i = array_length(global.notice_list) - 1; i >= 0; i--) {
        var notice = global.notice_list[i];
        notice.frames++;
        
        // 更新位置以确保通知保持在屏幕中心偏上
        notice.pos_x = room_width / 2;
        //notice.target_y = camera_y + camera_h / 3;
        //notice.pos_y = notice.target_y;
        
        // 前20帧：淡入和缩放效果
        if (notice.frames <= 10) {
            notice.alpha = notice.frames / 10;
            notice.scale = 2.2 - (0.2 * (notice.frames / 10));
        }
        // 生命周期结束前的阶段
        else if (notice.frames > notice.life) {
            // 向上移动并淡出
            notice.pos_y -= 2;
            notice.alpha = 1 - ((notice.frames - notice.life) / 20);
            
            // 当完全透明时移除通知
            if (notice.alpha <= 0) {
                array_delete(global.notice_list, i, 1);
                continue;
            }
        }
        
        global.notice_list[i] = notice;
    }
}

// 在绘制事件中绘制所有通知
function draw_notices() {
    if (!variable_global_exists("notice_list")) return;
    
    for (var i = 0; i < array_length(global.notice_list); i++) {
        var notice = global.notice_list[i];
        
        // 设置字体和颜色
        var text = notice.text;
        var pos_x = notice.pos_x;
        var pos_y = notice.pos_y;
        var alpha = notice.alpha;
        var scale = notice.scale;
        
		draw_set_font(font_yuan);
		
        // 计算文本尺寸
        var text_width = string_width(text) * scale;
        var text_height = string_height(text) * scale;
        
        // 绘制半透明黑色背景框
        var padding = 5 * scale;
        draw_set_alpha(0.7 * alpha);
        draw_set_color(c_black);
        draw_roundrect(
            pos_x - text_width/2 - padding,
            pos_y - text_height*scale + padding,
            pos_x + text_width/2 + padding,
            pos_y - text_height + padding*2,
            false // 不绘制轮廓
        );
        
        // 绘制白色描边
        draw_set_alpha(alpha);
        draw_set_color(c_white);
        //draw_set_line_width(2 * scale);
        draw_roundrect(
            pos_x - text_width/2 - padding,
            pos_y - text_height*scale + padding,
            pos_x + text_width/2 + padding,
            pos_y - text_height + padding*2,
            true // 绘制轮廓
        );
        
        // 绘制绿色文本
        draw_set_color(make_color_rgb(0, 255, 0)); // 绿色
        draw_set_font(font_yuan);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_alpha(alpha);
        draw_text_ext_transformed(
            pos_x, pos_y-3, text,90,1920,scale,scale,0
        );
        
        // 重置绘制设置
        draw_set_alpha(1);
        draw_set_color(c_white);
        //draw_set_line_width(1);
    }
}


// ══════════════════════════════════════════════════════════════════════
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
    self.prev_text = ""; self.prev_font = -1; // 上一个内容：框变大的过程中先继续显示它
    self.showing = false;                     // 本帧有没有命中
    self.hold = 0; self.hold_frames = 3;      // 0.05s @60fps：扫过空隙不闪，也决定消失前等多久
    self.out_t = -1;                          // 消失进度（-1 = 没在消失）
    self.fit = false;
    self.box_alpha = 0.7;                     // 提示框底色的不透明度（各面板原值不同，按调用点指定）

    /// @param {Real} _dir +1 = 框在锚点右侧；-1 = 框在锚点左侧
    static set = function(_x, _y, _text, _dir, _box_alpha) {
        self.box_alpha = _box_alpha;
        self.tx = _x; self.ty = _y; self.dir = _dir;
        if (_text != self.text) {
            self.prev_text = self.text;
            self.prev_font = self.font;
            self.text = _text;
            self.font = draw_get_font();
            self.fit = false;
        }
        self.showing = true;
        self.hold = 0;
        self.out_t = -1;
        var _pf = draw_get_font();
        draw_set_font(self.font);
        var _tw = string_width(_text)  + 10;
        var _th = string_height(_text) + 10;
        draw_set_font(_pf);
        if (_tw != self.anim_tw || _th != self.anim_th) self.speed = self.speed_start;
        self.anim_tw = _tw;
        self.anim_th = _th;
    };

    static draw = function() {
        if (!self.showing) {                              // 这一帧没命中
            self.hold++;
            if (self.hold > self.hold_frames && self.out_t < 0 && self.anim_tw >= 0) {
                self.out_t = 0;                           // 宽限结束 → 缩小消失
                self.speed = self.speed_start;
            }
        }
        if (self.out_t >= 0) {
            self.speed = min(self.speed_max, self.speed + self.speed_step);
            self.anim_w -= self.anim_w * self.speed;
            self.anim_h -= self.anim_h * self.speed;
            if (self.anim_w <= 1.5 || self.anim_h <= 1.5 || self.out_t > 120) {
                self.out_t = -1; self.anim_w = 0; self.anim_h = 0;
                self.anim_tw = -1; self.anim_th = -1;
                self.text = ""; self.prev_text = ""; self.fit = false; self.speed = self.speed_start;
            }
        } else if (self.anim_tw >= 0) {
            // 尺寸过渡：放大缩小同一条路径、同一套爬升速率
            if (self.showing) {
                self.speed = min(self.speed_max, self.speed + self.speed_step);
                self.anim_w += (self.anim_tw - self.anim_w) * self.speed;
                self.anim_h += (self.anim_th - self.anim_h) * self.speed;
                if (abs(self.anim_tw - self.anim_w) < 0.5 && abs(self.anim_th - self.anim_h) < 0.5) {
                    self.anim_w = self.anim_tw; self.anim_h = self.anim_th;
                }
            }
        } else {
            self.anim_w = 0; self.anim_h = 0;
        }

        if (self.anim_tw >= 0 && self.text != "" && self.anim_w > 1) {
            var _prev_font = draw_get_font();
            draw_set_font(self.font);
            draw_set_color(c_black);
            draw_set_alpha(self.box_alpha);
            if (self.dir > 0) { draw_rectangle(self.tx - 5, self.ty - 5, self.tx - 5 + self.anim_w, self.ty - 5 + self.anim_h, false); }
            else              { draw_rectangle(self.tx + 5 - self.anim_w, self.ty - 5, self.tx + 5, self.ty - 5 + self.anim_h, false); }
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
            draw_set_color(c_white);
            if (self.out_t >= 0) {
                // 消失中：文字跟着框一起缩，锚点那一侧不动
                draw_set_alpha(1);
                var _sc = self.anim_w / max(1, string_width(self.text) + 10);
                if (self.dir > 0) draw_text_transformed(self.tx, self.ty, self.text, _sc, _sc, 0);
                else              draw_text_transformed(self.tx - string_width(self.text) * _sc, self.ty, self.text, _sc, _sc, 0);
            } else {
                if (!self.fit && self.anim_w >= string_width(self.text) + 4 && self.anim_h >= string_height(self.text) + 4) self.fit = true;
                draw_set_alpha(1);                    // 框用的是 0.7，文字要恢复不透明
                if (self.fit) {
                    if (self.dir > 0) draw_text(self.tx, self.ty, self.text);
                    else              draw_text(self.tx - string_width(self.text), self.ty, self.text);
                } else if (self.prev_text != "") {
                    var _pf2 = draw_get_font();
                    draw_set_font(self.prev_font);
                    if (self.dir > 0) draw_text(self.tx, self.ty, self.prev_text);
                    else              draw_text(self.tx - string_width(self.prev_text), self.ty, self.prev_text);
                    draw_set_font(_pf2);
                }
            }
            draw_set_font(_prev_font);
        }
        draw_set_alpha(1);
        self.showing = false;                         // 下一帧重新判定命中
    };
}

/// @function tooltip_set(_x, _y, _text, _dir)
/// @description 当前实例的提示框：记录要显示的内容并设定目标尺寸（不绘制）。
function tooltip_set(_x, _y, _text, _dir) {
    // 第 5 个参数（可选）= 框底色的不透明度；第 6 个（可选）= 槽位（同一实例的第二个 Draw 事件用 1）
    var _a    = (argument_count >= 5) ? argument[4] : 0.7;
    var _slot = (argument_count >= 6) ? argument[5] : 0;
    if (_slot == 1) {
        if (!variable_instance_exists(id, "__tooltip_b")) __tooltip_b = new Tooltip();
        __tooltip_b.set(_x, _y, _text, _dir, _a);
    } else {
        if (!variable_instance_exists(id, "__tooltip")) __tooltip = new Tooltip();
        __tooltip.set(_x, _y, _text, _dir, _a);
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
