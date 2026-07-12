class_name BuildingDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: String = "general"
@export_range(1, 10, 1) var max_level: int = 1
@export var construction_costs: Dictionary = {}
@export_range(1, 999, 1) var construction_days: int = 1
@export_range(0, 99999, 1) var capacity: int = 0
@export var maintenance_costs: Dictionary = {}
@export var effects: Array[Dictionary] = []
@export var prerequisites: Array[String] = []
