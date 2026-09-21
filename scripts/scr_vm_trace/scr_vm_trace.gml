// =====================================================================
// 崩溃面包屑追踪
// =====================================================================
// 用途：地图脚本（VM）进图时若发生**原生崩溃**（SIGSEGV / OOM），
//       GML 层连 try/catch 都拿不到机会，我们的报错弹窗也弹不出来
//       （已实测：三界花园(百鬼夜行版本) 进图直接闪退，报错都弹不了）。
//
// 办法：在一段**可能崩溃的操作**开始前把文件重置并逐步写标记；
//       正常跑完再写一行 "OK end"。下次启动时检查：
//         · 有 "OK end"  → 上次正常，删掉文件
//         · 没有         → 上次崩在半路，把内容弹给玩家/开发者
//       文件是追加+即时关闭的，所以崩溃前写进去的一定落盘。
//
// 注意：安卓 release 包的文件在沙盒里，adb 拿不到 ——
//       所以**必须**走"下次启动弹窗"这条路，不能靠拉文件。
// =====================================================================

#macro VM_TRACE_FILE "vm_trace.txt"

// 脚本顶层初始化（早于任何调用）
global._vm_trace_on = false;
global._vm_trace_detail = false;

/// @description 开始一次被追踪的操作（会清空上一次的追踪）
function vm_trace_begin(_tag) {
    global._vm_trace_on = true;
    global._vm_trace_detail = true;
    try {
        var _f = file_text_open_write(VM_TRACE_FILE);
        if (_f >= 0) {
            file_text_write_string(_f, "[" + string(_tag) + "] 开始\n");
            file_text_close(_f);
        }
    } catch (_e) {}
}

/// @description 写一条进度标记（即时落盘）
function vm_trace(_msg) {
    // ⚠️⚠️ 这个开关是**必须**的，不是优化：
    //   vm_trace 每调用一次就是一次 file open + append + close（磁盘 I/O）。
    //   而 VM_OP_CALL 每执行一个宿主函数就写一行 "CALL xxx argc=N"，
    //   地图脚本的 _VM_FRAME 是**每帧**跑的 → 全程每秒几十次写盘 → **帧率掉到 30**
    //   （2026-09-21 真机实测：进「我是老鼠」后放一只老鼠就只剩 30 帧，元凶就是这里）。
    //   所以：只有 vm_trace_begin → vm_trace_end 这段窗口才写，窗口外一律直接返回。
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

/// @description 标记"这一段跑完了"；有此标记说明上次没崩在这段里
function vm_trace_end() {
    vm_trace("OK end");                 // 先把正常结束的标记写进去
    global._vm_trace_on = false;        // 然后**关掉**：否则每次 CALL 都还在写盘（帧率杀手）
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

/// @description 启动时调用：若上次的追踪没有正常结束，就把内容弹出来
/// @returns {Bool} 是否弹了（弹了说明上次崩过）
function vm_trace_check_on_launch() {
    try {
        if (!file_exists(VM_TRACE_FILE)) {
            return false;
        }
        var _f = file_text_open_read(VM_TRACE_FILE);
        if (_f < 0) {
            return false;
        }
        var _txt = "";
        while (!file_text_eof(_f)) {
            _txt += file_text_read_string(_f) + "\n";
            file_text_readln(_f);
        }
        file_text_close(_f);

        if (string_pos("OK end", _txt) > 0) {
            file_delete(VM_TRACE_FILE);      // 上次正常结束，清掉
            return false;
        }
        // 上次崩在半路 —— 把末尾几十行弹出来（崩溃点就在最后一条之后）
        show_error_dialog("上次运行中途崩溃",
            "崩溃点追踪（**最后一条标记之后**就是崩溃发生的位置）：\n\n"
            + _vm_trace_tail(_txt, 40)
            + "\n（本文件已保留，可点[导出错误报告]复制全文）");
        return true;
    } catch (_e) {
        return false;
    }
}
