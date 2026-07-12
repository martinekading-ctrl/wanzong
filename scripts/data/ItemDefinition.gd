class_name ItemDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum("material", "consumable", "equipment", "advanced_material") var category: String = "material"
@export var resource_key: String = ""
@export var stack_limit: int = 9999
@export var base_value: int = 1
@export var effects: Array[Dictionary] = []
@export var equipment_slot: String = ""
@export var stat_modifiers: Dictionary = {}

