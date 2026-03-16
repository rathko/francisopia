extends Node2D
## Manages equipped weapons. Handles cycling, visibility, and persistence.
## Each weapon is a child Node2D with: equip(), unequip(), use_weapon(), is_available() -> bool

signal weapon_changed(weapon_name: String)

var _weapons: Array[Node2D] = []
var _active_index := -1  # -1 = no weapon equipped

func _ready() -> void:
	# Collect all weapon children
	for child in get_children():
		if child is Node2D and child.has_method("equip") and child.has_method("use_weapon"):
			_weapons.append(child)
			child.visible = false
	# Restore equipped weapon from save
	_restore_equipped_weapon()

func _restore_equipped_weapon() -> void:
	var saved_weapon: String = GameManager.equipped_weapon
	if saved_weapon.is_empty():
		return
	for i in _weapons.size():
		if _weapons[i].name.to_lower().contains(saved_weapon.to_lower()):
			_equip_index(i)
			return

func get_active_weapon() -> Node2D:
	if _active_index >= 0 and _active_index < _weapons.size():
		return _weapons[_active_index]
	return null

func get_active_weapon_name() -> String:
	var w := get_active_weapon()
	if w:
		return w.name
	return ""

func cycle_next() -> void:
	if _weapons.is_empty():
		return
	# Find available weapons
	var available: Array[int] = []
	for i in _weapons.size():
		if _weapons[i].has_method("is_available") and _weapons[i].is_available():
			available.append(i)
		elif not _weapons[i].has_method("is_available"):
			available.append(i)  # No gate = always available
	if available.is_empty():
		# No weapons available — unequip
		if _active_index >= 0:
			_unequip_current()
		return
	if _active_index < 0:
		# Nothing equipped — equip first available
		_equip_index(available[0])
		return
	# Find next available after current
	var current_pos := available.find(_active_index)
	if current_pos < 0:
		_equip_index(available[0])
	else:
		var next_pos := (current_pos + 1) % available.size()
		if available[next_pos] == _active_index and available.size() == 1:
			# Only one weapon — toggle off
			_unequip_current()
		else:
			_equip_index(available[next_pos])

func _equip_index(idx: int) -> void:
	if _active_index >= 0 and _active_index < _weapons.size():
		_weapons[_active_index].visible = false
		if _weapons[_active_index].has_method("unequip"):
			_weapons[_active_index].unequip()
	_active_index = idx
	_weapons[idx].visible = true
	if _weapons[idx].has_method("equip"):
		_weapons[idx].equip()
	weapon_changed.emit(_weapons[idx].name)
	# Persist
	GameManager.equipped_weapon = _weapons[idx].name.to_lower()

func _unequip_current() -> void:
	if _active_index >= 0 and _active_index < _weapons.size():
		_weapons[_active_index].visible = false
		if _weapons[_active_index].has_method("unequip"):
			_weapons[_active_index].unequip()
	_active_index = -1
	weapon_changed.emit("")
	GameManager.equipped_weapon = ""

func grant_weapon(weapon_name: String) -> void:
	## Called when a weapon is unlocked (e.g., spelling "bow")
	for i in _weapons.size():
		if _weapons[i].name.to_lower() == weapon_name.to_lower():
			if _weapons[i].has_method("unlock"):
				_weapons[i].unlock()
			# Auto-equip if nothing equipped
			if _active_index < 0:
				_equip_index(i)
			return

func has_weapon_equipped() -> bool:
	return _active_index >= 0
