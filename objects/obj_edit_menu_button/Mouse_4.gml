global.audio.play(snd_button,0,0)
if btn_type == "cancel"{
	instance_destroy(obj_edit_menu)
	obj_player_info_ui.menu_type = 0
}
else if btn_type == "save"{
	with obj_edit_menu{
		event_user(0)
	}
	global.save_data[$ "player"][$ "name"] = global.player_name
	instance_destroy(obj_edit_menu)
	obj_player_info_ui.menu_type = 0
}
else if btn_type == "open_save_folder"{
	// mobile-only：Windows 端「打开存档文件夹」（native_open_folder）分支已按审计移除
	show_notice("安卓端请用 [导出存档] 备份到可访问位置", 150)
}
else if btn_type == "export_save_backup" {
	// mobile-only：Windows 端 native_start_backup 分支已按审计移除，只保留安卓导出实现
	{
		// 安卓：导出 = 存档复制到剪贴板（可粘贴到备忘录/微信保存）+ 游戏内备份兜底
		var _save_path = "saves/save" + string(global.save_slot) + ".json";
		if (!file_exists(_save_path)) {
			show_notice("暂无存档可导出", 120)
		} else {
			clipboard_set_text(json_stringify(global.save_data));
			if (!directory_exists("backups")) {
				directory_create("backups")
			}
			var _d = date_current_datetime();
			var _stamp = string(date_get_year(_d)) + string(date_get_month(_d)) + string(date_get_day(_d)) + "_" + string(date_get_hour(_d)) + string(date_get_minute(_d)) + string(date_get_second(_d));
			file_copy(_save_path, "backups/save" + string(global.save_slot) + "_" + _stamp + ".json");
			// FVM: 写分享请求（Java 桥读取后生成含内容的 txt 到下载目录并拉起系统分享面板，
			// 绕开微信/QQ 文本框字符数限制；剪贴板内容保持不变作为兜底）
			var _sf = file_text_open_write("share_request.txt");
			file_text_write_string(_sf, json_stringify(global.save_data));
			file_text_close(_sf);
			show_message_async("存档已复制到剪贴板，正在拉起系统分享…（txt 文件同时生成在下载目录）")
		}
	}
}
else if btn_type == "import_save_backup" {
	// mobile-only：Windows 端 native_restore_backup 分支已按审计移除，只保留安卓导入实现
	{
		// 安卓：导入 = 读取剪贴板存档内容（先复制存档文本再导入）
		var _txt = clipboard_get_text();
		if (_txt == "") {
			show_notice("剪贴板为空，请先复制要导入的存档内容", 150)
		} else {
			// ---- 防御兜底 ----------------------------------------------------------
			// 背景：有玩家在平板上点「导入存档」崩溃，一直未能复现。
			// 原实现只校验 is_struct + version，而游戏实际依赖 14 个顶层字段
			// （player 被引用 127 处、unlocked_items 107 处、unlocked_cards 89 处…）。
			// 只带 version 的残缺存档能通过原校验 → 写盘成功 → 之后别处读 .player.level 时炸。
			// 现在缺字段就明确拒绝，并把缺失项摊给用户（可截图反馈），不让它到别处炸。
			// 另：从备忘录/微信粘贴常带 BOM，json_parse 会直接失败 → 先剥掉。
			// ---------------------------------------------------------------------
			_txt = string_replace_all(_txt, chr(65279), "");   // 去 BOM (U+FEFF)
			if (string_length(_txt) > 2000000) {               // ~2MB，正常存档远小于此
				show_error_dialog("存档导入失败", "剪贴板内容异常（过长：" + string(string_length(_txt)) + " 字符）。\n请确认复制的是游戏 [导出存档] 产生的完整内容。")
			} else {
				var _ok = false;
				var _err = "";
				try {
					var _data = json_parse(_txt);
					if (!is_struct(_data)) {
						_err = "剪贴板内容不是存档格式（顶层不是对象）。";
					} else if (is_undefined(_data[$ "version"])) {
						_err = "缺少 version 字段，不像是游戏存档。";
					} else {
						// 必需字段（所有存档版本都有）—— 按容器类型校验，缺一个都可能后续崩溃
						var _need_struct = ["player", "unlocked_items", "equipped_items"];
						var _need_array  = ["unlocked_cards", "completed_levels", "inventory", "unlocked_weapons", "unlocked_gems", "saved_decks", "tasks", "completed_tasks"];
						var _miss = "";
						for (var _i = 0; _i < array_length(_need_struct); _i++) {
							var _f = _need_struct[_i];
							if (!is_struct(_data[$ _f])) _miss += _f + " ";
						}
						for (var _j = 0; _j < array_length(_need_array); _j++) {
							var _f = _need_array[_j];
							if (!is_array(_data[$ _f])) _miss += _f + " ";
						}
						if (_miss != "") {
							_err = "存档缺少必需字段：" + _miss + "\n请使用游戏 [导出存档] 生成的完整内容。";
						} else {
							// 老版本存档本来就没有这几个字段（load_file 的版本迁移会补），
							// 这里按同一口径先补默认值，避免迁移链读到 undefined。
							var _pl = _data[$ "player"];
							if (is_undefined(_data[$ "attires"]))              _data[$ "attires"] = [];
							if (is_undefined(_data[$ "equipped_cookbook"]))    _data[$ "equipped_cookbook"] = [[], [], []];
							if (is_undefined(_pl[$ "crown_version"]))          _pl[$ "crown_version"] = "0.0.0";
							global.save_data = _data;
							save_file(global.save_slot);
							load_file(global.save_slot);
							_ok = true;
						}
					}
				} catch(e) {
					_err = "解析失败：" + string(e);
				}
				if (_ok) {
					show_notice("存档导入成功", 120)
				} else {
					show_error_dialog("存档导入失败", _err + "\n\n复制到的内容开头：" + string_copy(_txt, 1, 60) + "…")
				}
			}
		}
	}
}

