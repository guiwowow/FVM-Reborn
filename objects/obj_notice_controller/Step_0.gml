// 面包屑：进入/离开后台各记一笔 —— 用来把"闪退"和"用户切走 / 清后台 / 关游戏"区分开
// （启动检查只看文件**最后一条**标记：末尾是 [后台]/[结束]/OK end 就不算闪退）
vm_trace_pause_check()
// update_notices() 已挪到 draw_notices() 入口（见 show_notice.gml 注释）
update_error_dialog()