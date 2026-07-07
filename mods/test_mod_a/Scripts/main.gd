
extends RefCounted

var initialized: bool = false
var run_started: bool = false
var invoked_func: String = ""

func on_initialize(_context) -> void:
	initialized = true

func on_run_started(_context) -> void:
	run_started = true

func on_invoke(function_name: String, _parameters) -> Variant:
	invoked_func = function_name
	return GnosisFunctionResult.ok()
	