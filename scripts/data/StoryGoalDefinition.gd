class_name StoryGoalDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var order: int = 0
@export var conditions: Array[Dictionary] = []
@export var rewards: Dictionary = {}

