class_name EventDefinition
extends Resource

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export_enum("disciple", "resource", "sect", "world") var category: String = "world"
@export var trigger: Dictionary = {}
@export var conditions: Array[Dictionary] = []
@export var options: Array[Dictionary] = []
@export var trigger_once: bool = false
