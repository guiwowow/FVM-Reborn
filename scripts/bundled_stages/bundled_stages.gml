/// @description 把**随包内置**的实验室关卡拷进沙盒 laboratory/
///
/// 背景：内置资源放在 datafiles/bundled_stages/，随 APK 变成**只读**的
///       working_directory + "bundled_stages/…"；而关卡列表扫描的是**可写的沙盒**
///       kCustomStageFolder（= "laboratory"）。两者不是同一个地方，所以启动时要拷一次。
///
/// 只拷「沙盒里还没有的」文件 —— 玩家自己下载或改过的同名文件不会被覆盖。
/// 用 buffer_load + buffer_save 而不是 file_copy：前者读 APK 内文件是已验证路径。
///
/// 用途：在线下载暂时拿不到这几张图时，用它验证地图脚本 VM 与 mod 插件。
///
/// @returns {Real} 本次实际拷入的文件数
function install_bundled_stages() {
    var _dst = kCustomStageFolder + "/";
    if (!directory_exists(_dst)) {
        directory_create(_dst);
    }
    // 内置清单 = datafiles/bundled_stages/ 下的全部文件（改动时两边要同步）
    //
    // ⚠️ 必须全用小写：**安卓打包会把 assets 里的文件名整个转成小写**
    //（实测 datafiles/bundled_stages/I,mouse.json → APK 内 assets/bundled_stages/i,mouse.json，
    //  12 个条目逐个小写核对过；Level5_9.* → level5_9.*）。
    // 用原名写清单的话，在真机上 working_directory + "bundled_stages/I,mouse.json" 会 file_exists 失败。
    // 落进沙盒时同样保持小写，这样 <名>.json 与 <名>.bin 的配对（StageDetail 靠换扩展名找脚本）依然成立。
    var _files = [
        "i,mouse.json", "i,mouse.bin", "i,mouse.txt",
        "i,mouse_too.json", "i,mouse_too.bin", "i,mouse_too.txt",
        "level5_9.json", "level5_9.bin", "level5_9.txt",
        "cerebrawl.ogg", "graze_the_roof.ogg", "roof.png"
    ];
    var _n = 0;
    for (var i = 0; i < array_length(_files); i++) {
        var _f = _files[i];
        if (file_exists(_dst + _f)) continue;                // 沙盒里已有 → 不动
        var _src = working_directory + "bundled_stages/" + _f;
        if (!file_exists(_src)) continue;
        var _b = buffer_load(_src);
        if (_b < 0) continue;
        buffer_save(_b, _dst + _f);
        buffer_delete(_b);
        _n++;
    }
    return _n;
}

/// @description 把随包内置的 mod 内容（卡 / 武器 / 宝石 / 时装 / 敌人）拷进**沙盒** mod/ 树
///
/// 为什么要拷：内置文件在 working_directory 那棵树，而运行期扫描与下载落地都在
/// **沙盒相对树**（src_mod_dir 优先返回 "mod/<kind>/"，理由见该函数注释）。
/// 做法与 install_bundled_stages 一致：只拷沙盒里还没有的，不覆盖作者/玩家更新过的版本。
///
/// 将来的分发模型：实验室作者产出的卡/武器随地图包下发，由下载管线落进**同一棵相对树**；
/// 那时这个函数就退化为"只负责把内置模板放进去"。
///
/// @returns {Real} 本次实际拷入的文件数
function install_bundled_mods() {
    if (!directory_exists("mod/")) directory_create("mod/");
    var _files = [
        "mod/attires/mod_player_attire_demo.json", "mod/cards/combined_strip.png", "mod/cards/mod_test_flame.bin",
        "mod/cards/mod_test_flame.json", "mod/cards/mod_test_flame.txt", "mod/cards/mod_test_shooter.bin",
        "mod/cards/mod_test_shooter.json", "mod/cards/mod_test_shooter.txt", "mod/cards/mod_test_tracker.bin",
        "mod/cards/mod_test_tracker.json", "mod/cards/mod_test_tracker.txt", "mod/enemies/mod_dash_mouse.bin",
        "mod/enemies/mod_dash_mouse.json", "mod/enemies/mod_dash_mouse.txt", "mod/gems/sentry_gem.bin",
        "mod/gems/sentry_gem.json", "mod/gems/sentry_gem.txt", "mod/weapons/baozi_gun.bin",
        "mod/weapons/baozi_gun.json", "mod/weapons/baozi_gun.txt", "mod/weapons/baozi_storm.bin",
        "mod/weapons/baozi_storm.json", "mod/weapons/baozi_storm.txt", "mod/weapons/thick_cake_shield.json",
        "mod/weapons/triple_gun.bin", "mod/weapons/triple_gun.json", "mod/weapons/triple_gun.txt",
    ];
    var _n = 0;
    for (var i = 0; i < array_length(_files); i++) {
        var _f = _files[i];                  // 形如 "mod/cards/mod_test_flame.json"
        if (file_exists(_f)) continue;       // 沙盒里已有 → 不动
        var _src = working_directory + _f;
        if (!file_exists(_src)) continue;    // 包里就没有 → 跳过
        var _dir = filename_dir(_f);
        if (!directory_exists(_dir)) directory_create(_dir);
        var _b = buffer_load(_src);
        if (_b < 0) continue;
        buffer_save(_b, _f);
        buffer_delete(_b);
        _n++;
    }
    return _n;
}
