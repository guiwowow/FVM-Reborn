// 面包屑：Game End 事件（游戏被正常关闭 / 系统结束进程时 GM 会走到这里）
// —— 有了这条标记，启动检查就能把"关游戏"和"前台闪退"区分开
vm_trace("[结束] Game End 事件")
save_file(global.save_slot)

global.laboratory_manager.dispose()

