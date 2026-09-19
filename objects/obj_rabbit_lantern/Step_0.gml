if global.is_paused{
	exit
}
// 缓时门控（2026-09-19 补 §21 遗留缺口）。
// ⚠️ 必须放在 event_inherited() **之前**：父对象 Step 里的 `exit` 只能退出父事件，
//    退不出本子事件，所以本对象自己的动画段原先在缓时下仍全速。
if (slowmo_gate()) exit;
event_inherited(); 
var current_flash_speed = flash_speed
if is_slowdown{
	current_flash_speed *= 2
}

explode_timer --

//攻击逻辑
if (explode_timer <= 0) {
	invincible = true
	if (attack_timer <= attack_anim * current_flash_speed - 1) {
	    attack_timer++;
		state = CARD_STATE.ATTACK;
	}
	if (attack_timer == attack_anim * current_flash_speed - 1){
	    event_user(1); // 发射子弹
	}
}
else{
	state = CARD_STATE.IDLE
	attack_timer = 0
}

