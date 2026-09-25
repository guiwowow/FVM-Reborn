// =====================================================================
// 崩溃面包屑追踪
// =====================================================================
// 用途：地图脚本（VM）进图时若发生**原生崩溃**（SIGSEGV / OOM）或**被强杀**，
//       GML 层连 try/catch 都拿不到机会，报错弹窗也弹不出来
//       （已实测：三界花园(百鬼夜行版本) 进图直接闪退，报错都弹不了）。
//
// 办法：**开机第一帧就把追踪文件武装起来**，之后每次房间切换、进图各阶段、
//       战斗里程碑都往里追加标记（每行即时落盘、崩溃前写的一定在盘上）。
//       只有**玩家主动确认退出**才写 "OK end" 销账。下次启动检查：
//         · 有 "OK end"  → 上次是正常退出，删掉文件，安静
//         · 没有         → 上次是崩溃/被强杀/非正常退出，把末尾内容弹出来
//
// 2026-09-21 重做（治"该弹不弹"，三处结构性缺陷）：
//   ① 旧版只在 StageDetail/Create_0.gml 里 vm_trace_begin（**会截断文件**），
//      而进图入口不止一条（世界地图入口、obj_levelselect_button 直接
//      VM_InitRoomEntry(undefined)）。不经 StageDetail 的崩溃 → 文件压根没生成
//      → 启动检查找不到文件 → 静默 return false → 看起来就是"面包屑失效"。
//      → 现在：开机即武装；运行期一律走 vm_trace_arm()（已武装就只追加、绝不截断）。
//   ② 旧版在 obj_battle 战斗第 120 帧就 vm_trace_end()：写 OK end **并关掉开关**，
//      此后一个字都不再写 → 任何"进图 2 秒之后"的崩溃，下次启动会被当成正常而把
//      证据删掉。→ 现在那里只关"逐 CALL 明细"（帧率修复保住），OK end 只在
//      玩家确认退出时写（obj_quit_confirm / obj_menu_manager 两处 game_end 之前）。
//   ③ 旧版整个检查包在 try/catch 里、catch 直接 return false → 一旦抛异常就永久静默。
//      → 现在 catch 也会弹窗报出来；另外"上次非正常退出"报完即删，只报一次。
//
// 顺序铁律：vm_trace_check_on_launch()（检查上次）必须先于 vm_trace_boot()（武装本次）。
//   房间切换的标记用 _vm_trace_booted 守卫，保证"武装前绝不碰文件"——
//   否则 Room Start 若早于 obj_game_init 的 Create，会把上次的证据截断掉。
//
// 注意：安卓 release 包的文件在沙盒里，adb 拿不到 ——
//       所以**必须**走"下次启动弹窗"这条路，不能靠拉文件。
// =====================================================================

#macro VM_TRACE_FILE "vm_trace.txt"

// 逐 CALL 明细（帧率杀手）保留到战斗第几帧。原为 120（≈2s），
// 而实测插件关卡崩在第 121~179 帧之间 —— 明细恰好在崩点前被关掉，什么都留不下。
// 调到 600（≈10s）覆盖"进图 + 战斗开局"这段最危险的窗口；崩溃查清后可调回 120。
// 追查"后期崩溃"时可临时改成 600（帧率开销更大，幻鸡那次崩点就在 600 帧之后）。
#macro VM_TRACE_DETAIL_FRAMES 120

// 脚本顶层初始化（早于任何调用）
global._vm_trace_on = false;
global._vm_trace_detail = false;
global._vm_trace_booted = false;
global._vm_trace_paused = false;    // 当前是否处于"已切到后台"状态（见 vm_trace_pause_check）

/// @description 开始一次被追踪的操作（**会清空**上一次的追踪）
///   只在"开机第一帧"这种明确要开新账的地方用。运行期请用 vm_trace_arm()。
function vm_trace_begin(_tag) {
    global._vm_trace_on = true;
    try {
        var _f = file_text_open_write(VM_TRACE_FILE);
        if (_f >= 0) {
            file_text_write_string(_f, "[" + string(_tag) + "] 开始\n");
            file_text_close(_f);
        }
    } catch (_e) {}
}

/// @description 确保追踪已武装，并追加一条标记（**绝不截断已有追踪**）
/// @param {String} _tag     标记文本
/// @param {Bool}   _detail  是否同时打开"逐 CALL 明细"（默认关；开了写盘很凶，会掉帧）
function vm_trace_arm(_tag, _detail) {
    if (!variable_global_exists("_vm_trace_on") || !global._vm_trace_on) {
        vm_trace_begin(_tag);
    } else {
        vm_trace("[" + string(_tag) + "]");
    }
    if (_detail) global._vm_trace_detail = true;
}

/// @description 开机武装本次会话（在 vm_trace_check_on_launch() **之后**调用）
function vm_trace_boot() {
    vm_trace_begin("boot");
    global._vm_trace_booted = true;
}

/// @description 写一条进度标记（即时落盘）
function vm_trace(_msg) {
    // ⚠️⚠️ 这个开关是**必须**的，不是优化：
    //   vm_trace 每调用一次就是一次 file open + append + close（磁盘 I/O）。
    //   而 VM_OP_CALL 每执行一个宿主函数就写一行 "CALL xxx argc=N"，
    //   地图脚本的 _VM_FRAME 是**每帧**跑的 → 全程每秒几十次写盘 → **帧率掉到 30**
    //   （2026-09-21 真机实测：进「我是老鼠」后放一只老鼠就只剩 30 帧，元凶就是这里）。
    //   所以：只有 vm_trace_begin / vm_trace_arm 武装过之后才写，未武装一律直接返回。
    if (!variable_global_exists("_vm_trace_on")) return;
    if (!global._vm_trace_on) return;
    try {
        var _f = file_text_open_append(VM_TRACE_FILE);
        if (_f >= 0) {
            file_text_write_string(_f, string(_msg) + "\n");
            file_text_close(_f);
        }
    } catch (_e) {}
}

/// @description 逐 CALL 明细开关 —— 帧率杀手，只在"进图"这段窗口开
function vm_trace_detail_set(_on) {
    global._vm_trace_detail = _on;
}

/// @description 标记"这次运行正常收尾了"；**只在玩家主动确认退出时调用**
function vm_trace_end() {
    vm_trace("OK end");                 // 先把正常结束的标记写进去
    global._vm_trace_on = false;        // 然后关掉：否则每次 CALL 都还在写盘（帧率杀手）
    global._vm_trace_detail = false;
}

/// @description 详细（逐 CALL）追踪开关判断 —— 供 VM_OP_CALL 里的逐调用记录使用
function vm_trace_detail_on() {
    if (!variable_global_exists("_vm_trace_detail")) return false;
    return global._vm_trace_detail;
}

/// @description 给出错信息打标记：把最后的几行放到最前面（最有价值）
function _vm_trace_tail(_txt, _lines_max) {
    var _arr = string_split(_txt, "\n");
    var _n = array_length(_arr);
    var _out = "";
    var _start = max(0, _n - _lines_max);
    for (var _i = _start; _i < _n; _i++) {
        if (string_length(string(_arr[_i])) > 0) {
            _out += string(_arr[_i]) + "\n";
        }
    }
    return _out;
}

/// @description 每帧调用（Step）：进入/离开后台各记一笔
///   用途：把"闪退"与"用户切走 / 清后台 / 关游戏"区分开 ——
///   清后台、划掉任务、MIUI 一键清理，**一定先经过"切到后台"**，
///   所以启动检查只要看文件**最后一条**标记是不是 [后台]/[结束]/OK end 就能判定正常离开。
///   只有"末尾还停在游戏过程中"才是真·前台闪退。
function vm_trace_pause_check() {
    if (!variable_global_exists("_vm_trace_booted") || !global._vm_trace_booted) return;
    var _p = os_is_paused();
    if (_p && !global._vm_trace_paused) {
        global._vm_trace_paused = true;
        vm_trace("[后台] 切到后台 / 被挂起");
    } else if (!_p && global._vm_trace_paused) {
        global._vm_trace_paused = false;
        vm_trace("[回前台] 回到前台");
    }
}

/// @description 启动时调用：若上次没有正常销账，就把追踪末尾弹出来
/// @returns {Bool} 是否报了（报了说明上次是非正常退出）
function vm_trace_check_on_launch() {
    var _exists = false;
    var _n = 0;
    var _ok = false;
    var _tail = "";
    try {
        _exists = file_exists(VM_TRACE_FILE);
        if (!_exists) {
            return false;                     // 没有文件 = 上次要么没跑、要么已销账
        }
        var _f = file_text_open_read(VM_TRACE_FILE);
        if (_f < 0) {
            // 文件在但打不开 —— 不能静默，报出来
            show_error_dialog("面包屑读取失败",
                "vm_trace.txt 存在但 file_text_open_read 返回 < 0。\n"
                + "（此弹窗本身也证明检查函数确实执行了）");
            return false;
        }
        var _txt = "";
        while (!file_text_eof(_f)) {
            _txt += file_text_read_string(_f) + "\n";
            file_text_readln(_f);
        }
        file_text_close(_f);

        _n = string_count("\n", _txt);
        // 判定"闪退"还是"正常离开"：**只看最后一条非空标记**
        //   · OK end / [结束] / [后台]（切走后没回来）⇒ 主动退出、清后台、被系统回收
        //     ⇒ 不算闪退，静默清账（旧版只要文件里出现过 OK end 就静默，粒度太粗）
        //   · 末尾还停在游戏过程中（[room=…] / 战斗标记 / 逐 CALL 明细）
        //     ⇒ 前台运行中突然没了 ⇒ 闪退，保留并弹窗
        var _lines = string_split(_txt, "\n");
        var _last = "";
        for (var _li = array_length(_lines) - 1; _li >= 0; _li--) {
            var _ls = string(_lines[_li]);
            if (string_length(_ls) > 0) { _last = _ls; break; }
        }
        var _is_leave = (string_pos("OK end", _last) > 0
                      || string_pos("[结束]", _last) > 0
                      || string_pos("[后台]", _last) > 0);
        // ② Android 权威判据（原生扩展 ExitInfo → ApplicationExitInfo，API 30+，本机 SDK 35）：
        //    2 SIGNALED / 4 ANR / 5 CRASH_NATIVE / 6 CRASH ⇒ 真崩溃，必须报
        //    3 LOW_MEMORY / 10 USER_REQUESTED(SwipeUpClean、force stop) / 11 / 16 PACKAGE_UPDATED
        //      / 17 / 18 / 20 ⇒ 系统或用户结束的，静默
        //    1 EXIT_SELF（game_end() 也是 1）/ 0 / -1（拿不到）⇒ 说不清，交给上面的标记判断
        //    注：清后台时（MIUI SwipeUpClean）App 拿不到任何事件，标记写不出来，
        //        只有这个原因码能分辨 —— 这就是它存在的理由。
        var _ar = exitinfo_last_reason();
        var _android_crash = (_ar == 2 || _ar == 4 || _ar == 5 || _ar == 6);
        var _android_leave = (_ar == 3 || _ar == 10 || _ar == 11 || _ar == 16
                           || _ar == 17 || _ar == 18 || _ar == 20);
        if (_android_leave || (!_android_crash && _is_leave)) {
            file_delete(VM_TRACE_FILE);        // 系统说不是崩溃 / 标记说正常离开，不算闪退
            return false;
        }
        // 走到这里 = 前台运行中突然没了（_android_crash，或原因码说不清且标记也不是离开）
        // 前台运行中没了 —— 把末尾几十行抓出来（断点就在最后一条之后）
        _tail = _vm_trace_tail(_txt, 18);
    } catch (_e) {
        // 旧版这里是 return false，异常会导致**永久静默**，现在必须报出来
        show_error_dialog("面包屑检查抛异常",
            "vm_trace_check_on_launch 内部异常：\n" + string(_e));
        return false;
    }

    // 双通道播报：toast 走 notice 系统，弹窗走 error_dialog 系统，互相独立，
    // 任何一条通道坏掉都能从"另一条有没有出现"判断出来。
    show_notice("游戏非正常退出（详见弹窗）", 600);
    show_error_dialog("游戏非正常退出",
        "游戏非正常退出（追踪已保留，共 " + string(_n) + " 行）。\n"
        + "可点 [导出错误报告] 把详细信息发给开发者。\n"
        + "系统退出原因码：" + string(_ar) + "（" + exitinfo_last_description() + "）\n\n"
        + _tail);

    // 只报一次：删掉旧账，本次会话由 vm_trace_boot() 重新武装。
    // 内容已完整存进弹窗的 [导出错误报告]（global.error_dialog.full），不会丢。
    file_delete(VM_TRACE_FILE);
    return true;
}
