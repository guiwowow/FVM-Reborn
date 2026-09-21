
// =====================================================================
// 前层贴图槽（地图脚本 VM_SetDrawSlot_front）
// 画在火焰 UI 前面 —— 对应 obj_battle/Draw_0 里的后层槽。
// 无脚本时 64 格全是 noone → 循环空转，开销可忽略。
// =====================================================================
for (var _fi = 0; _fi < 64; _fi++) {
    var _fslot = global.map_draw_slots_front[_fi];
    if (_fslot.sprite == noone || _fslot.sprite == "" || _fslot.sprite == -1) continue;
    draw_sprite_ext(_fslot.sprite, 0, _fslot.x, _fslot.y, _fslot.image_xscale, _fslot.image_yscale, _fslot.image_angle, c_white, _fslot.alpha);
}

// =====================================================================
// 火苗指示器 + 卡槽条（从联机版移植的分支结构）
// 传送带模式：地图脚本用 VM_conveyor_belt_able(true) 开启，
//   卡槽固定 15 格，卡片由脚本供应，不走玩家卡组。
// 正常模式：按玩家卡组格数绘制。
// =====================================================================
if (global._VM_conveyor_belt) {

	draw_sprite_ext(spr_flame_indicator, 0, 350, 0, 0.9, 0.9, 0, c_white, 1)
	draw_sprite_ext(spr_slot_top,0,350+83*1.8,0,65+45*(15-1),1.8,0,c_white,1)
	if not instance_exists(obj_shovel_slot){
		instance_create_depth(350+83*1.8+80+90*(14-1),0,-980,obj_shovel_slot)
	}

}
else{

	draw_sprite_ext(spr_flame_indicator, 0, 350, 0, 0.9, 0.9, 0, c_white, 1)

	var slot_length = deck_slot_count()
	//show_debug_message("slot_length:"+string(slot_length))
	if slot_length <= 14{
		draw_sprite_ext(spr_slot_top,0,350+83*1.8,0,40+45*(slot_length-1),1.8,0,c_white,1)
		if not instance_exists(obj_shovel_slot){
			instance_create_depth(350+83*1.8+80+90*(slot_length-1),0,-980,obj_shovel_slot)
		}
	}
	else{
		draw_sprite_ext(spr_slot_top,0,350+83*1.8,0,40+45*(15-1),1.8,0,c_white,1)
		draw_sprite_ext(spr_slot_corner, 0, 350+83*1.8+80+90*(15-1), 0, 0.9, 0.9, 0, c_white, 1)
		draw_sprite_ext(spr_slot_right,0,350+83*1.8+80+90*(15-1)-1,18*1.8,0.9,59*(slot_length-14),0,c_white,1)
		if not instance_exists(obj_shovel_slot){
			instance_create_depth(350+83*1.8+80+90*(14-1)-33,118*(slot_length-14)+17,-980,obj_shovel_slot)
		}
	}
	draw_set_halign(fa_center)
	draw_set_valign(fa_middle)
	draw_set_font(font_hei)
	draw_set_color(c_black)
	draw_text(420,143,string(global.flame))
	draw_set_halign(fa_left)
	draw_set_valign(fa_top)
}
