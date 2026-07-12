class_name RecipeDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_enum("alchemy", "forging", "array") var craft_type: String = "alchemy"
@export var ingredients: Dictionary = {}
@export var outputs: Dictionary = {}
@export var required_building_id: String = ""
@export var required_building_level: int = 1
@export var required_disciple_tags: Array[String] = []
@export var duration_days: int = 1
@export var base_success_rate: float = 1.0

