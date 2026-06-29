class_name UltravibeGameInfo
extends RefCounted

## Ultravibe build identity. Bump VERSION here for releases; the platform
## suffix is appended automatically (D = desktop, A = Android, I = iOS, W = Web).

const VERSION := "0.8.0"

static func display_version() -> String:
	return "%s-%s" % [VERSION, _platform_suffix()]

static func _platform_suffix() -> String:
	match OS.get_name():
		"Android":
			return "A"
		"iOS":
			return "I"
		"Web":
			return "W"
		_:
			# Windows, macOS, Linux, and other desktop-class targets.
			return "D"
