@tool
extends EditorPlugin

func _enter_tree() -> void:
	# Подписываемся на событие изменения настроек проекта в редакторе
	ProjectSettings.settings_changed.connect(_sync_version)

func _exit_tree() -> void:
	if ProjectSettings.settings_changed.is_connected(_sync_version):
		ProjectSettings.settings_changed.disconnect(_sync_version)

func _sync_version() -> void:
	var version = ProjectSettings.get_setting("application/config/version", "")
	if version == "":
		return
		
	var config_path = "res://export_presets.cfg"
	if not FileAccess.file_exists(config_path):
		return
		
	# Загружаем файл конфигурации экспорта
	var config = ConfigFile.new()
	var err = config.load(config_path)
	if err != OK:
		push_error("Синхронизация версий: не удалось прочитать export_presets.cfg. Код: " + str(err))
		return
		
	var has_changes = false
	
	# Проходим по всем секциям в export_presets.cfg
	for section in config.get_sections():
		# 1. Синхронизируем версию для Android (секция вида [preset.N])
		if config.has_section_key(section, "version/name"):
			var current_val = config.get_value(section, "version/name")
			if current_val != version:
				config.set_value(section, "version/name", version)
				has_changes = true
				
		# 2. Синхронизируем версию для Windows/macOS (секция вида [preset.N.options])
		if section.ends_with(".options"):
			if config.has_section_key(section, "application/file_version"):
				var current_val = config.get_value(section, "application/file_version")
				if current_val != version:
					config.set_value(section, "application/file_version", version)
					has_changes = true
			if config.has_section_key(section, "application/product_version"):
				var current_val = config.get_value(section, "application/product_version")
				if current_val != version:
					config.set_value(section, "application/product_version", version)
					has_changes = true
					
	# Если были изменения, перезаписываем файл пресетов
	if has_changes:
		err = config.save(config_path)
		if err == OK:
			print("Синхронизация версий: файл export_presets.cfg успешно обновлен до версии " + version)
		else:
			push_error("Синхронизация версий: не удалось перезаписать export_presets.cfg. Код: " + str(err))
