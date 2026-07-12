class_name SecretRealmDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var map_resource_id: int = 0
@export_range(1, 9, 1) var level: int = 1
@export_range(1, 20, 1) var total_depth: int = 1
@export_range(0.0, 1.0, 0.01) var base_risk: float = 0.2
@export var terrain: String = "secret_realm"
@export var recommended_power: int = 300

