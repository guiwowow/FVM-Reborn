image_xscale = 1;
image_yscale = 1;
button_select = 0;
current_settings = noone; // 当前设置页面的控制器
setting_buttons = []; // 存储创建的设置按钮

// 创建界面按钮
closemenu_btn = instance_create_depth(x+470, y-330, depth-1, obj_closemenu_btn);
menu_btn1 = instance_create_depth(x-360, y-245, depth-1, obj_menu_select_btn);
menu_btn2 = instance_create_depth(x-120, y-245, depth-1, obj_menu_select_btn);
menu_btn3 = instance_create_depth(x+120, y-245, depth-1, obj_menu_select_btn);
menu_btn4 = instance_create_depth(x+360, y-245, depth-1, obj_menu_select_btn);

menu_btn2.button_index = 1;
menu_btn3.button_index = 2;
menu_btn4.button_index = 3;

menu_btn2.sprite_index = spr_option_select_btn_2
menu_btn3.sprite_index = spr_option_select_btn_3
menu_btn4.sprite_index = spr_option_select_btn_4

// 添加操作设置相关变量
keybind_page = 0; // 当前快捷键设置页
keybinds_per_page = 5; // 每页显示的快捷键数量
total_keybind_pages = 0; // 总页数

// 计算总页数
total_keybind_pages = ceil(array_length(global.keybind_config) / keybinds_per_page);

/// @function create_keybind_buttons()
// 创建当前页的快捷键按钮
function create_keybind_buttons(){
	var start_index = keybind_page * keybinds_per_page;
	var end_index = min(start_index + keybinds_per_page, array_length(global.keybind_config)) - 1;

	var base_y = y - 50;
	for (var i = start_index; i <= end_index; i++) {
	    var kb = global.keybind_config[i];
	    var btn = instance_create_depth(x+270, base_y + (i - start_index) * 70, depth-1, obj_key_bind_button);
	    btn.key_name = kb.name;
	    btn.default_key = kb.default1;
	    btn.current_key = global.keybind_map[? kb.name];
	    //btn.tooltip_text = kb.tooltip;
	    btn.update_text();
	    array_push(setting_buttons, btn);
	}
}

// 难度切换动画（点左右箭头时，等级名在卡片容器里滑出/滑入）
diff_shown       = global.difficulty;  // 当前应显示的那一帧（动画的"上一帧"）
diff_anim_from   = global.difficulty;  // 正在离开的那一帧
diff_anim_t      = -1;                 // -1 = 无动画；>=0 = 动画进行到第几帧
diff_anim_frames = 18;                 // 时长（帧），60fps ≈ 0.3s
diff_anim_dir    = 1;                  // 1 = 下一级（新图从右侧进）；-1 = 上一级（从左侧进）
diff_anim_pad    = 52;                 // 裁剪窗口比等级名左右各宽多少。实测定标：容器 = spr_option_menu_text 帧2 的日芒卡片（371x157，边框约 8px → 内区约 360 宽），等级名画出来 244.8 宽 → 每侧约 55，取 52 略收在边框里侧（88 会溢出到卡片外）
