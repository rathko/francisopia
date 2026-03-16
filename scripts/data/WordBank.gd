class_name WordBank
extends Resource
## Collection of WordEntry resources with query methods.

const WordEntryScript = preload("res://scripts/data/WordEntry.gd")

@export var words: Array[Resource] = []

func get_words_by_level(max_level: int) -> Array[Resource]:
	return words.filter(func(w: Resource) -> bool:
		return w.get("level") <= max_level
	)

func get_words_by_area(area: String) -> Array[Resource]:
	return words.filter(func(w: Resource) -> bool:
		return w.get("area") == area.to_lower()
	)

func get_words_by_level_and_area(max_level: int, area: String) -> Array[Resource]:
	return words.filter(func(w: Resource) -> bool:
		return w.get("level") <= max_level and w.get("area") == area.to_lower()
	)

func get_word_entry(word: String) -> Resource:
	for entry in words:
		if entry.get("word") == word:
			return entry
	return null

func size() -> int:
	return words.size()
