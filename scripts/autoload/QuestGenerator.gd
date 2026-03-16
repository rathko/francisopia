extends Node
## Generates simple reading quests for the Quest Scroll.
## Quests use 2-4 word phrases appropriate for age 5.

signal quest_added(quest: Dictionary)
signal quest_completed(quest_id: String)

var active_quests: Array[Dictionary] = []
var _quest_templates: Array[Dictionary] = []

func _ready() -> void:
	_load_templates()
	GameManager.word_completed.connect(_on_word_completed)

func _load_templates() -> void:
	_quest_templates = [
		# Spelling quests
		{"id": "spell_%s", "text": "Spell %s", "type": "spell", "area": "any"},
		# Collection quests
		{"id": "find_cat", "text": "Find cat", "type": "explore", "area": "meadow"},
		{"id": "find_fish", "text": "Find fish", "type": "explore", "area": "beach"},
		{"id": "find_owl", "text": "Find owl", "type": "explore", "area": "forest"},
		# Training quests
		{"id": "hit_targets_3", "text": "Hit 3 targets", "type": "training", "area": "training"},
		{"id": "hit_targets_5", "text": "Hit 5 targets", "type": "training", "area": "training"},
		# Exploration quests
		{"id": "visit_beach", "text": "Visit beach", "type": "explore", "area": "any"},
		{"id": "visit_forest", "text": "Visit forest", "type": "explore", "area": "any"},
		{"id": "visit_mountain", "text": "Go to mountain", "type": "explore", "area": "any"},
		# Shop quests
		{"id": "buy_hat", "text": "Buy a hat", "type": "shop", "area": "castle"},
		{"id": "visit_shop", "text": "Visit shop", "type": "explore", "area": "castle"},
		# Simple action quests
		{"id": "jump_high", "text": "Jump high", "type": "action", "area": "any"},
	]

func generate_quests_for_area(area: String, count: int = 3) -> Array[Dictionary]:
	var candidates := _quest_templates.filter(func(q: Dictionary) -> bool:
		var quest_area: String = q.get("area", "any")
		return (quest_area == area.to_lower() or quest_area == "any") and \
			   q.get("id", "") not in GameManager.quests_completed
	)
	candidates.shuffle()
	var selected: Array[Dictionary] = []
	for i in min(count, candidates.size()):
		var quest: Dictionary = candidates[i].duplicate()
		# Fill in word for spelling quests
		if quest.get("type") == "spell":
			var word := WordEngine.current_target_word
			if word.is_empty():
				word = "CAT"
			quest["id"] = quest["id"] % word
			quest["text"] = quest["text"] % word
		quest["completed"] = false
		selected.append(quest)
		active_quests.append(quest)
		quest_added.emit(quest)
	return selected

func complete_quest(quest_id: String) -> void:
	for quest in active_quests:
		if quest.get("id") == quest_id and not quest.get("completed", false):
			quest["completed"] = true
			GameManager.complete_quest(quest_id)
			quest_completed.emit(quest_id)
			break

func get_active_quests() -> Array[Dictionary]:
	return active_quests.filter(func(q: Dictionary) -> bool:
		return not q.get("completed", false)
	)

func _on_word_completed(word: String) -> void:
	var quest_id := "spell_%s" % word.to_upper()
	complete_quest(quest_id)
