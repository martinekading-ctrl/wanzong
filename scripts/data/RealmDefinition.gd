class_name RealmDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var order: int = 0
@export var cultivation_required: int = 0
@export_range(0.0, 1.0, 0.01) var breakthrough_base_rate: float = 0.0
@export var costs: Dictionary = {}
@export var stat_multipliers: Dictionary = {}
@export_range(1, 100, 1) var minimum_health: int = 60
@export_range(0, 99, 1) var failure_health_penalty: int = 10
@export_range(0.0, 1.0, 0.01) var failure_cultivation_loss_rate: float = 0.1
@export var next_realm_id: String = ""
