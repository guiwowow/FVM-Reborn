// =====================================================================
// instance_create_depth / instance_destroy 钩子（VM 事件来源）
// =====================================================================
// ⚠️ 本工程只覆写**这两个**核心函数，且都带「无脚本时的快路径」。
//    不要从联机版整文件照搬 —— 联机版那份（258 行）还覆写了
//    audio_play_sound / draw_self / 11 个 draw_sprite 变体，
//    并依赖它自己的两阶段懒加载系统（_sprite_cache / _sprite_state / _pending_map /
//    sprite_manager_load_async / full_load 枚举 / _ph_empty.png 占位图）。
//    本工程没有那套系统，整文件照搬会在 obj_game_init 阶段直接崩（踩过）。
//
// instance_create_depth 覆写来源：上游 f1b884f3「修复浮空岛地图游玩卡顿问题」。
// instance_destroy 覆写是为 VM 的 _VM_ENEMY_KILLED 事件（见下），2026-09-20 新增。
// =====================================================================

global._move_instance_pre_arr = []
global._move_instance_map = ds_map_create()
global._last_platform = -1

// ---- 地图脚本 VM 依赖的全局（2026-09-21 补回）----
// ⚠️ 教训：先前重写本文件时，把联机版那一整块全局初始化一起删掉了，
//    以为"只覆写两个函数就够了"。但移植进来的 VM 代码仍然读这些全局
//    （尤其 VM_CreatePlatform 第一句就是 global._evt_log_enabled），
//    结果是「进图 → 脚本调 VM_CreatePlatform → 读不存在的全局 → 崩溃」，
//    而且崩得连报错弹窗都来不及画，只能靠面包屑定位。
//    补全局初始化时必须**按引用逐个核对**（grep "global.<名字>"），不能凭感觉删。
//
// 已核对：以下名字在本工程里只有 scr_command_VM 引用；联机版其余的
// _destroy_queue / _tanghulu_bullets / _eat_scratch / _is_in_battle /
// _server_destroy_queue / _boss_spawn_queue / _boss_client_cleanup 在
// 本工程**零引用**（那些是联机与懒加载专用的），刻意不补。
global._evt_created     = [];
global._evt_destroyed   = [];
global._evt_log_enabled = false;

#macro instance_create_depth_origfunc instance_create_depth
#macro instance_create_depth          instance_create_depth_define

#macro instance_destroy_origfunc      instance_destroy
#macro instance_destroy               instance_destroy_define


function instance_create_depth_define(_x, _y, _depth, _obj) {

	var _inst = instance_create_depth_origfunc(_x, _y, _depth, _obj);
	array_push(global._move_instance_pre_arr,_inst);
	if (_obj == obj_platform)
		global._last_platform = _inst;

	// ---- VM Hook：敌人生成（2026-09-20 从联机版移植，只取与 VM 有关的部分）----
	// 联机版同一位置还有 boss 同步拦截 / 服务端延迟广播 / 糖葫芦炮弹归并，
	// 那些都是联机或懒加载专用，未移植。
	// 内置关卡没有 .bin → buffer_exists 为假 → 零开销。
	if (_inst >= 0 && object_is_ancestor(_obj, obj_enemy_parent)) {
		global._VM_last_created_enemy = _inst;
		if (buffer_exists(global._VM_ENEMY_SPAWNED)) VM_QueueHook(global._VM_ENEMY_SPAWNED, "enemy", _inst);
	}

	return _inst;
}


/// @description instance_destroy 的包装：在真正销毁**之前**给 VM 发敌人击杀事件
///
/// 为什么必须走全局覆写、而不是写在 obj_enemy_parent 的 Destroy 事件里：
///   171 个敌人子对象中有 **53 个自己覆写了 Destroy 且没调 event_inherited()**
///   → 写在父事件里会漏掉约 93% 的敌人死亡。
///   （联机版同样是在这里统一拦的。）
///
/// 为什么要"销毁之前"：VM 的击杀事件要读死亡瞬间的属性做快照
///   （VM_BuildDeadSnap 要求实例还存在）。
///
/// 性能：内置关卡没有 .bin → 第一行 buffer_exists 为假 → 直接落到原函数，
///   每次调用只多一次 buffer_exists。
function instance_destroy_define() {

	if (buffer_exists(global._VM_ENEMY_KILLED)) {
		var _id;
		switch (argument_count) {
			case 0:  _id = id;           break;
			case 1:  _id = argument[0];  break;
			case 2:  _id = argument[0];  break;
			default: _id = id;           break;
		}
		if (instance_exists(_id) && object_is_ancestor(_id.object_index, obj_enemy_parent)) {
			global._VM_last_killed_enemy = _id;
			VM_QueueHook(global._VM_ENEMY_KILLED, "enemy_kill", _id);
		}
	}

	// YYC 严格性修复（2026-10-01）：instance_destroy 没有返回值，
	// `return <void 调用>` 在 YYC 下报 "No return value from expression"（VM 容忍）。
	// 改成先调用再退出；调用方本来也拿不到返回值，行为等价。
	switch (argument_count) {
		case 0:  instance_destroy_origfunc(); break;
		case 1:  instance_destroy_origfunc(argument[0]); break;
		case 2:  instance_destroy_origfunc(argument[0], argument[1]); break;
		default: instance_destroy_origfunc(); break;
	}
}
