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
		// 第 6 个开关「缓时视觉」的标签 —— 前 5 个标签烘焙在 spr_option_menu_text 图里（没有第 6 个）。
		//
		// 位置 x-359 / y+330 是实测的：
		//   精灵 1001x510、原点 (500,255)、由 draw_sprite(...,1,x-360,y+30) 画到房间
		//   → 房间x = x - 860 + 精灵x，房间y = y - 225 + 精灵y
		//   5 个烘焙标签的列中心都是精灵 x≈501 → 房间 x-359；行距 100px，标签中心 == 开关中心
		//
		// 为什么用独立精灵而不是 draw_text_transformed：
		//   font_yuan 只有 size 16，靠 1.52 倍缩放凑出来的字，补不出烘焙图的 6px 深蓝描边与立体投影，
		//   用户实测反馈「确实小了」。spr_slowmo_label 是照烘焙标签的配色/描边/挤出重做的
		//   （134x43，origin = Middle Centre，textureGroup = UI），画在这个坐标即自动对齐 —— 见手册 §23.4a。
		draw_sprite(spr_slowmo_label, 0, x - 359, y + 330);
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
		draw_sprite_ext(spr_option_menu_difficulty,global.difficulty,x+15,y+102,0.2,0.2,0,c_white,1)
		break
    
    // 可以添加其他设置页面
	case 0:
		// 绘制音频设置标签
		draw_set_halign(fa_left);
		draw_set_valign(fa_top);
		draw_set_color(#9DCFEC);
		
		draw_sprite(spr_option_volume_bg,0,x,y-87)
		// 音乐标签
		//draw_text_ext_transformed(x - 430, y - 155, "音乐",0,900,1,1,0);
		draw_text_ext_transformed(x + 355, y - 148, string(round(global.music_volume * 100)) + "%", 0, 900, 1, 1, 0);

		// 音效标签
		//draw_text_ext_transformed(x - 430, y - 75, "音效",0,900,1,1,0);
		draw_text_ext_transformed(x + 355, y - 50, string(round(global.sound_volume * 100)) + "%", 0, 900, 1, 1, 0);

		// 绘制进度条背景
		var bar_height = 20;
		var bar_min_x = x - 280;
		var bar_max_x = x + 280;

		// 音乐进度条
		draw_sprite(spr_option_volume_bar,0,x+2,y-134)
		//draw_set_color(merge_color(c_blue,c_black,0.5));
		//draw_roundrect(bar_min_x, y - 150, bar_max_x, y - 120, false);
		draw_set_color(#17314C);
		draw_roundrect(bar_max_x, y - 150, bar_min_x + (bar_max_x - bar_min_x) * global.music_volume, y - 120, false);

		// 音效进度条
		draw_sprite(spr_option_volume_bar,0,x+2,y-37)
		//draw_set_color(merge_color(c_blue,c_black,0.5));
		//draw_roundrect(bar_min_x, y - 55, bar_max_x, y - 25, false);
		draw_set_color(#17314C);
		draw_roundrect(bar_max_x, y - 55, bar_min_x + (bar_max_x - bar_min_x) * global.sound_volume, y - 25, false);
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