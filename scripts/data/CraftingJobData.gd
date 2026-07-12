class_name CraftingJobData
extends RefCounted

var job_id: String = ""
var sect_id: String = ""
var recipe_id: String = ""
var disciple_id: String = ""
var status: String = "crafting"
var remaining_days: int = 1
var success_chance: float = 1.0
var seed: int = 0
var test_roll: float = -1.0
var started_date: Dictionary = {}
var completed_date: Dictionary = {}
var consumed_items: Dictionary = {}
var result: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"job_id": job_id,
		"sect_id": sect_id,
		"recipe_id": recipe_id,
		"disciple_id": disciple_id,
		"status": status,
		"remaining_days": remaining_days,
		"success_chance": success_chance,
		"seed": seed,
		"test_roll": test_roll,
		"started_date": started_date.duplicate(true),
		"completed_date": completed_date.duplicate(true),
		"consumed_items": consumed_items.duplicate(true),
		"result": result.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> CraftingJobData:
	var job := CraftingJobData.new()
	job.job_id = str(data.get("job_id", ""))
	job.sect_id = str(data.get("sect_id", ""))
	job.recipe_id = str(data.get("recipe_id", ""))
	job.disciple_id = str(data.get("disciple_id", ""))
	job.status = str(data.get("status", "crafting"))
	job.remaining_days = int(data.get("remaining_days", 1))
	job.success_chance = float(data.get("success_chance", 1.0))
	job.seed = int(data.get("seed", 0))
	job.test_roll = float(data.get("test_roll", -1.0))
	job.started_date = data.get("started_date", {}).duplicate(true)
	job.completed_date = data.get("completed_date", {}).duplicate(true)
	job.consumed_items = data.get("consumed_items", {}).duplicate(true)
	job.result = data.get("result", {}).duplicate(true)
	return job

