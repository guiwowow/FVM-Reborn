/// Room Start —— 面包屑记一条"进了哪个房间"。
///
/// 这是"进图就崩"最关键的线索：崩溃后追踪文件末尾最后一条 `[room=xxx]`
/// 就是断点所在房间（例如停在 room_battle ⇒ 崩在战斗房创建/首帧；
/// 停在 room_laboratory ⇒ 崩在进图前的脚本加载）。
///
/// 用 `_vm_trace_booted` 守卫：开机武装（vm_trace_boot）之前**绝不碰文件**。
/// 否则若 Room Start 早于 obj_game_init 的 Create，
/// vm_trace_arm 会走 vm_trace_begin 把上次崩溃的证据截断掉。
if (variable_global_exists("_vm_trace_booted") && global._vm_trace_booted) {
    vm_trace_arm("room=" + room_get_name(room), false);
}
