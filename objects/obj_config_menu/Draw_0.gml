if global.menu_screen{
	draw_set_alpha(0.5);
	draw_rectangle_color(0, 0, room_width, room_height, c_black, c_black, c_black, c_black, false);
	draw_set_alpha(1);
}
draw_self()
draw_sprite(spr_option_menu_bg_2,0,x,y+75)
draw_set_font(font_yuan)
draw_set_color(c_white)
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
//draw_text_ext_transformed(x,y-345,"游戏设置",0,900,2,2,0)

switch (button_select) {
    case 2: // 画面设置
        //绘制设置标签
		//draw_set_halign(fa_left);
		//draw_set_valign(fa_middle);
		//draw_text(x - 380, y - 180, "屏幕震动");
		//draw_text(x - 380, y - 100, "闪烁效果");
		//draw_text(x - 380, y - 20, "全屏");
		//draw_text(x - 380, y + 60, "纹理过滤");
		//draw_text(x - 380, y + 140, "无边框窗口");
		//draw_set_halign(fa_left);
		//draw_set_valign(fa_top);
		draw_sprite(spr_option_menu_text,1,x-360,y+30)
	    break;
	case 3:
		//draw_set_halign(fa_left);
		//draw_set_valign(fa_middle);
		//draw_text(x - 380, y - 180, "卡片血条");
		//draw_text(x - 380, y - 100, "敌人血条");
		//draw_text(x - 380, y - 20, "难度");
		//draw_text(x - 380, y + 60, "失去焦点时暂停");
		//draw_set_halign(fa_left);
		//draw_set_valign(fa_top);
		draw_sprite(spr_option_menu_text,2,x-120,y+60)
		// 难度等级名：平时静态绘制；切换时旧名向一侧滑出、新名从另一侧滑入，超出卡片内边距的部分裁掉
		if (diff_anim_t < 0) {
			draw_sprite_ext(spr_option_menu_difficulty, global.difficulty, x+15, y+102, 0.2, 0.2, 0, c_white, 1)
		} else {
			var _sc    = 0.2;                                                   // 与静态绘制一致的缩放
			var _sw    = sprite_get_width(spr_option_menu_difficulty);           // 原始像素宽
			var _sh    = sprite_get_height(spr_option_menu_difficulty);          // 原始像素高
			var _ox    = sprite_get_xoffset(spr_option_menu_difficulty) * _sc;   // 原点换算到屏幕
			var _oy    = sprite_get_yoffset(spr_option_menu_difficulty) * _sc;
			var _win   = _sw * _sc + diff_anim_pad * 2;      // 裁剪窗口宽 = 等级名 + 两侧内边距
			var _left0 = x + 15 - _ox;                       // 静止时等级名的视觉左边界
			var _w1    = _left0 - diff_anim_pad;             // 窗口左边界（右边界 = _w1 + _win）
			var _top   = y + 102 - _oy;
			var _p     = diff_anim_t / diff_anim_frames;
			var _e     = 1 - (1 - _p) * (1 - _p) * (1 - _p); // 非线性缓动：ease-out（起步快、收尾慢）
			var _shift = _win * _e;
			var _dxf   = -diff_anim_dir * _shift;            // 旧名的位移
			var _dxt   =  diff_anim_dir * (_win - _shift);   // 新名的位移（dir=1 时自右侧进）
			// 旧名
			var _lft = x + 15 + _dxf - _ox;
			var _vl  = max(_w1, _lft);
			var _vr  = min(_w1 + _win, _lft + _sw * _sc);
			if (_vr > _vl) {
				draw_sprite_part_ext(spr_option_menu_difficulty, diff_anim_from,
					(_vl - _lft) / _sc, 0, (_vr - _vl) / _sc, _sh, _vl, _top, _sc, _sc, c_white, 1);
			}
			// 新名
			_lft = x + 15 + _dxt - _ox;
			_vl  = max(_w1, _lft);
			_vr  = min(_w1 + _win, _lft + _sw * _sc);
			if (_vr > _vl) {
				draw_sprite_part_ext(spr_option_menu_difficulty, diff_shown,
					(_vl - _lft) / _sc, 0, (_vr - _vl) / _sc, _sh, _vl, _top, _sc, _sc, c_white, 1);
			}
		}
		break
    
    // 可以添加其他设置页面
	case 0:
		// 入场动画：音量条从 0 涨到记忆值（只影响显示，不改实际音量）
		var _ease = 1;
		if (global.vol_intro_p >= 0) {
			var _ip = global.vol_intro_p;
			_ease = 1 - (1 - _ip) * (1 - _ip) * (1 - _ip);
		}
		var _mv = global.music_volume * _ease;
		var _sv = global.sound_volume * _ease;
		// 绘制音频设置标签
		draw_set_halign(fa_left);
		draw_set_valign(fa_top);
		draw_set_color(#9DCFEC);
		
		draw_sprite(spr_option_volume_bg,0,x,y-87)
		// 音乐标签
		//draw_text_ext_transformed(x - 430, y - 155, "音乐",0,900,1,1,0);
		draw_text_ext_transformed(x + 355, y - 148, string(round(_mv * 100)) + "%", 0, 900, 1, 1, 0);

		// 音效标签
		//draw_text_ext_transformed(x - 430, y - 75, "音效",0,900,1,1,0);
		draw_text_ext_transformed(x + 355, y - 50, string(round(_sv * 100)) + "%", 0, 900, 1, 1, 0);

		// 绘制进度条背景
		var bar_height = 20;
		var bar_min_x = x - 280;
		var bar_max_x = x + 280;

		// 音乐进度条
		draw_sprite(spr_option_volume_bar,0,x+2,y-134)
		//draw_set_color(merge_color(c_blue,c_black,0.5));
		//draw_roundrect(bar_min_x, y - 150, bar_max_x, y - 120, false);
		draw_set_color(#17314C);
		draw_roundrect(bar_max_x, y - 150, bar_min_x + (bar_max_x - bar_min_x) * _mv, y - 120, false);

		// 音效进度条
		draw_sprite(spr_option_volume_bar,0,x+2,y-37)
		//draw_set_color(merge_color(c_blue,c_black,0.5));
		//draw_roundrect(bar_min_x, y - 55, bar_max_x, y - 25, false);
		draw_set_color(#17314C);
		draw_roundrect(bar_max_x, y - 55, bar_min_x + (bar_max_x - bar_min_x) * _sv, y - 25, false);
		break;
	case 1:
		// 绘制标签
		draw_set_halign(fa_left);
		draw_set_valign(fa_middle);
		draw_set_color(#9DCFEC);
		//draw_text(x - 350, y - 170, "替换放置");
		//draw_text(x + 50, y - 170, "快速放置");
		//draw_text(x - 420, y - 115, "快捷键设置:");
		draw_sprite(spr_option_menu_text,0,x,y+65)

		// 绘制当前页数
		draw_set_halign(fa_center);
		draw_text(x-65, y + 290, string(keybind_page + 1));
		draw_text(x+65, y + 290, string(total_keybind_pages));
		break;
}

draw_set_halign(fa_left);
draw_set_valign(fa_top);