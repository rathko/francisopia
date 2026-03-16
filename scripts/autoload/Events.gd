extends Node
## Central signal bus for cross-system communication.
## Use for signals that need to be heard by distant/unrelated nodes.
## Direct signals remain on their source nodes for tightly-coupled communication.
##
## Usage:
##   Events.word_completed.emit("cat")           # Emit from anywhere
##   Events.word_completed.connect(_on_word)      # Connect from anywhere

# --- Word System ---
signal word_target_changed(word: String, hint_image: String)
signal letter_collected(letter: String, position: int)
signal word_spelled_correctly(word: String)
signal wrong_letter_rejected(letter: String)
signal letter_lost()

# --- Game Flow ---
signal area_changed(area_name: String)
signal coins_changed(new_total: int)
signal word_completed(word: String)
signal progress_reset()

# --- Quests ---
signal quest_added(quest: Dictionary)
signal quest_completed(quest_id: String)

# --- Magic Summon ---
signal summon_started(word: String, summon_type: String)
signal summon_completed(word: String, summoned_node: Node)

# --- UI ---
signal show_notification(text: String, duration: float)
