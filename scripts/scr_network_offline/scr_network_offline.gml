// =====================================================================
// 单机替身层 —— 地图脚本 VM 从联机版移植过来，但本工程不移植联机
// =====================================================================
// 背景：VM 脚本系统的代码里有 49 处 global.network.mode 判据 + 若干
//       global.network.map_instance_id_net_id / connected_clients 引用。
//       安卓移植版没有联机层，这些引用会直接报 undefined。
//
// 方案：提供一个最小替身，让所有判据都落到「单机」分支。
//
// ★ 关键设计：mode 取 "off" —— 既不是 "client" 也不是 "server"。
//   逐处核对过 VM 代码里的三种判据，在该取值下全部落到正确分支：
//     · if (global.network.mode == "client") return ...;        → false，不提前返回（单机自己算）
//     · if (global.network.mode == "server") { 广播给客户端 }    → false，整段跳过（单机没有客户端）
//     · if (global.network.mode != "client" || real_id < 0)     → true，直接用真实实例 id
//   唯一不属于这三种的调用是 network_apply_plant_level()，已在本文件里逐行照搬。
//
// ⚠️ 将来若要接联机：删掉本文件，改从联机版搬 scr_network_commands +
//    scr_network_aux_function，届时 mode 由联机初始化赋值。
// =====================================================================

if (!variable_global_exists("network")) {
    global.network = {
        mode: "off",                              // 非 client 非 server → 联机分支自然短路
        server_socket: -1,
        connected_clients: [],
        client_able: false,
        map_instance_id_net_id: ds_map_create(),  // 实例 id → 网络 id
        map_net_id_instance_id: ds_map_create(),  // 网络 id → 实例 id
    };
}

// ---- 消息号 ----
// VM 代码里有 7 处 send_message(..., MSG_xxx, ...)，全部位于 mode == "server"
// 分支内（单机永不执行），但宏必须在**编译期**存在，否则编译报未定义标识符。
// 数值照抄联机版 scr_battle_function.gml，保持与将来对接时一致。
#macro MSG_SPAWN_ENEMY     6
#macro MSG_GAME_OVER       10
#macro MSG_SPAWN_BOSS      14
#macro MSG_EVENT_ACTIONS   20
#macro MSG_MODIFY_PROP     25
#macro MSG_REQUEST_FILE    26
#macro MSG_VM_NOTIFY       30

/// @description 用植物自己的星级/技能/形态重算属性，并按星级重建星标
/// @param _plant 植物实例
/// @param use    必须显式传 true 才生效（上游签名如此，保持原样）
///
/// 注：名字带 network 是历史遗留 —— 原设计是「用网络同步值覆盖本地存档」，
///     联机版源码里已标注「该方案可废弃 / 已废弃」。实现本身不碰任何网络状态，
///     只读 _plant 自己的 current_level / skill / shape。此处逐行照搬，
///     保证 VM 生成的植物属性与星标表现和联机版一致。
function network_apply_plant_level(_plant, use = false) {
    if (use == false) exit;
    if (_plant.object_index == obj_player_character) exit;

    // 1. 清理本地存档创建的星标
    if (variable_instance_exists(_plant, "banding_star_obj")) {
        if (instance_exists(_plant.banding_star_obj)) {
            instance_destroy(_plant.banding_star_obj);
            _plant.banding_star_obj = noone;
        }
    }

    // 2. 取该植物自身的星级/技能/形态
    var level = _plant.current_level;
    var skill = _plant.skill;
    var shape = _plant.shape;

    // 3. 重新计算属性
    var upgrade_data = get_plant_data_with_skill(_plant.plant_id, shape, level, skill);
    if (upgrade_data != undefined) {
        _plant.max_hp   = _plant.hp;
        _plant.atk      = upgrade_data[? "atk"];
        _plant.range    = upgrade_data[? "range"];
        _plant.cooldown = upgrade_data[? "cooldown"];
        _plant.cycle    = upgrade_data[? "cycle"];
        if (ds_map_exists(upgrade_data, "flame_produce")) {
            _plant.flame_produce = upgrade_data[? "flame_produce"];
        }
    }

    // 4. 按星级重建星标
    if (level >= 4) {
        var star_spr = -1;
        switch (level) {
            case 4:  star_spr = spr_star_4;  break;
            case 5:  star_spr = spr_star_5;  break;
            case 6:  star_spr = spr_star_6;  break;
            case 7:  star_spr = spr_star_7;  break;
            case 8:  star_spr = spr_star_8;  break;
            case 9:  star_spr = spr_star_9;  break;
            case 10: star_spr = spr_star_10; break;
            case 11: star_spr = spr_star_11; break;
            case 12: star_spr = spr_star_12; break;
            case 13: star_spr = spr_star_13; break;
            case 14: star_spr = spr_star_14; break;
            case 15: star_spr = spr_star_15; break;
            case 16: star_spr = spr_star_16; break;
        }
        var inst = instance_create_depth(_plant.x, _plant.y - 5, _plant.depth - 1, obj_stars);
        inst.sprite_index = star_spr;
        inst.parent_card = _plant.id;
        _plant.banding_star_obj = inst.id;
    }
}
