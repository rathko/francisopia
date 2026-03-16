extends SceneTree
## One-time import: converts data/words.json to data/words/word_bank.tres
## Run with: godot --headless --script tools/import_words.gd

var _has_run := false

func _initialize() -> void:
	pass

func _process(_delta: float) -> bool:
	if _has_run:
		return true
	_has_run = true

	print("=== Importing words.json to WordBank .tres ===")

	var file := FileAccess.open("res://data/words.json", FileAccess.READ)
	if not file:
		print("ERROR: Cannot open data/words.json")
		quit()
		return true

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		print("ERROR: Failed to parse JSON: " + json.get_error_message())
		quit()
		return true

	var raw_words: Array = json.data.get("words", [])
	print("Found %d words in JSON" % raw_words.size())

	var WordBankClass = load("res://scripts/data/WordBank.gd")
	var WordEntryClass = load("res://scripts/data/WordEntry.gd")

	var bank = WordBankClass.new()

	for raw in raw_words:
		var entry = WordEntryClass.new()
		entry.word = raw.get("word", "")
		entry.level = raw.get("level", 1)
		entry.area = raw.get("area", "meadow")
		entry.image = raw.get("image", "")
		var raw_phonics: Array = raw.get("phonics", [])
		var phonics := PackedStringArray()
		for p in raw_phonics:
			phonics.append(p)
		entry.phonics = phonics
		bank.words.append(entry)

	var save_err := ResourceSaver.save(bank, "res://data/words/word_bank.tres")
	if save_err != OK:
		print("ERROR: Failed to save word_bank.tres (error %d)" % save_err)
	else:
		print("SUCCESS: Saved data/words/word_bank.tres with %d words" % bank.words.size())

	quit()
	return true
