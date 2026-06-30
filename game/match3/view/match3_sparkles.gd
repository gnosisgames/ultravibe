extends GPUParticles2D

## One-shot match sparkle burst (ported from templates/match3).


func _ready() -> void:
	emitting = true
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
