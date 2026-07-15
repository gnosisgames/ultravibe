class_name UltraEditionPolicy
extends GnosisEditionPolicy

## Mobile trial pressure for Ultravibe. Forces game over after the trial time limit
## when the player has not unlocked the full game on mobile.

const FORCE_GAME_OVER_SECONDS := 720.0

func run_pressure_at_elapsed_seconds(elapsed: float) -> Dictionary:
	if elapsed >= FORCE_GAME_OVER_SECONDS:
		return {"force_game_over": true, "reason": "trial_time_limit"}
	return {}

func paywall_message_key() -> String:
	return "ultravibe__edition__trialEnded"
