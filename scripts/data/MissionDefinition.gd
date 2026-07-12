class_name MissionDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum("gathering", "scouting", "escort", "hunt", "recruitment", "secret_realm") var mission_type: String = "gathering"
@export_range(1, 999, 1) var duration_days: int = 1
@export var costs: Dictionary = {}
@export var rewards: Dictionary = {}
@export_range(0.0, 1.0, 0.01) var base_success_rate: float = 0.5
@export_range(0.0, 1.0, 0.01) var difficulty: float = 0.0
@export_range(0.0, 1.0, 0.01) var risk: float = 0.0
@export_range(1, 20, 1) var min_team_size: int = 1
@export_range(1, 20, 1) var max_team_size: int = 5
@export var terrain: String = "any"
@export var result_effects: Array[Dictionary] = []
@export var discoveries: Array[Dictionary] = []
