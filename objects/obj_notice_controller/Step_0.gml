// 面包屑：进入/离开后台各记一笔 —— 用来把"闪退"和"用户切走 / 清后台 / 关游戏"区分开
// （启动检查只看文件**最后一条**标记：末尾是 [后台]/[结束]/OK end 就不算闪退）
vm_trace_pause_check()
// update_notices() 已挪到 draw_notices() 入口（见 show_notice.gml 注释）
update_error_dialog()
// 过渡推进（上游 PR#93 补的宿主；我方 obj_touch_control/Step_0.gml 另有一处，
// room_transition_step() 自带 `if (_tr.frame == current_time) return` 同帧守卫 ⇒ 重复调用无副作用）
room_transition_step()
