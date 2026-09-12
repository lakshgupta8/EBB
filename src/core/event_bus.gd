extends Node
## Global signal hub. Systems talk through here so they never need direct references.
## Naming: past tense for things that happened, imperative for requests.

# Combat
signal damage_dealt(target: Node, info: DamageInfo)
signal enemy_died(enemy: Node)
signal player_died()
signal player_health_changed(current: int, max_hp: int)

# Run flow
signal room_entered(room: Node)
signal room_cleared(room: Node)
signal run_started(seed: int)
signal run_ended(result: Dictionary)
signal tide_changed(level: float)
signal pickup_collected(kind: int, value: int)

# Meta / hub
signal pearls_changed(amount: int)
signal salt_changed(amount: int)
signal keys_changed(amount: int)

# Feedback requests (listened to by camera / juice systems)
signal request_hitstop(duration: float)
signal request_shake(strength: float)
