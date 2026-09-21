// 选卡缓时：逻辑与动画均 12 倍慢（保存/恢复各对象原本 image_speed，不干扰手动动画）
if (slowmo_gate()) exit;
if not is_placed{
	x = mouse_x
	y = mouse_y
}

// 受伤 VM 挂载点：本帧血量下降 → 触发脚本的 _VM_PLAYER_DAMAGED
if (pre_hp > hp && buffer_exists(global._VM_PLAYER_DAMAGED)) {
	global._VM_last_damaged_player = id;
	VM_Execute(global.__vm, global._VM_PLAYER_DAMAGED, "_VM_PLAYER_DAMAGED");
}
pre_hp = hp;
