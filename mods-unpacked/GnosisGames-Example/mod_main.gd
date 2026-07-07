extends Node

const LOG_NAME := "GnosisGames-Example:Main"

func _init() -> void:
	var config := ModLoaderConfig.get_current_config("GnosisGames-Example")
	if config and config.is_valid():
		var data: Dictionary = config.data
		if bool(data.get("show_startup_message", true)):
			ModLoaderLog.info("Example mod loaded (luck boost %.0f%%)." % [float(data.get("luck_meter_boost", 0.0)) * 100.0], LOG_NAME)
	else:
		ModLoaderLog.info("GML example mod loaded.", LOG_NAME)
