image_xscale = 1.8
image_yscale = 1.8

target_card_id = ""
info_got = false
card_attire_id_list = []
selected_attire_id = ""
selected_attire_index = -1 // 当前选择的时装索引

//target_current_level = 9
//target_current_shape = 0
//target_current_skill = 0

// ── 时装切换动画状态 + 内容绘制函数（2026-10-07 修闪退）────────────────
// 上游 PR#93 把本对象的 Draw/Step 换成「窗口内左右滑动」版，但：
//   ① card_attire_content_draw() 全树只有调用、没有定义（旧版是 Draw 里内联画的）
//   ② sw_* 只在 objects/obj_edit_menu/Create_0.gml（**另一个对象**）里初始化过
// ⇒ 打开带时装的卡片子菜单会 "Variable obj_card_attire_menu.sw_shown not set
//   before reading it" / "card_attire_content_draw not set"。这里一次补齐。
sw_shown  = -2;              // -2 = 首帧静默同步（Step 会对齐到 selected_attire_index）
sw_from   = -1;
sw_t      = -1;              // -1 = 不在滑动中
sw_frames = 18;              // 滑动时长（帧）
sw_dir    = 1;
sw_pending_dir = 0;          // 箭头按钮按下时写入本次方向，Step 消费后清零
sw_surf   = -1;
sw_win_l  = x - 90;          // 裁剪窗口（世界坐标，绕本实例居中）
sw_win_t  = y - 80;
sw_win_w  = 180;
sw_win_h  = 180;

// 画「某一档时装」的全部内容；_dx/_dy 为滑动偏移（旧版 Draw 的内联绘制 + 偏移）
function card_attire_content_draw(_index, _dx, _dy){
    if _index != -1{
        var _id = card_attire_id_list[_index]
        var _d  = get_attire_info(_id)
        draw_sprite_ext(spr_slot, 0, x + _dx, y - 10 + _dy, 0.32, 0.32, 0, c_white, 1)
        draw_sprite(_d.icon, 0, x + _dx, y + 10 + _dy)
        draw_set_halign(fa_center)
        draw_set_valign(fa_middle)
        draw_text(x + _dx, y + 70 + _dy, _d.name)
    }
    else{
        draw_set_halign(fa_center)
        draw_set_valign(fa_middle)
        draw_text(x + _dx, y + 70 + _dy, "无")
    }
}