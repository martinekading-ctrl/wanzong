class_name DiplomaticActionDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var actor_costs: Dictionary = {}
@export var target_costs: Dictionary = {}
@export var actor_costs_to_target: bool = false
@export var target_costs_to_actor: bool = false
@export var relation_delta: int = 0
@export var trust_delta: int = 0
@export var tension_delta: int = 0
@export_range(0.0, 1.0, 0.01) var base_acceptance: float = 0.5
@export var minimum_relation: int = -100
@export var maximum_relation: int = 100
@export_range(0, 999, 1) var cooldown_days: int = 0

