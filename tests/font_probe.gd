extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu := (load("res://ui/start_setup.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	var title: Label = menu.get_node("Panel/Title")
	var font: Font = title.get_theme_font("font")
	var chinese_ok := font != null and font.has_char("森".unicode_at(0)) and font.has_char("难".unicode_at(0))
	if not chinese_ok:
		push_error("FONT PROBE: project UI font is missing Chinese glyphs")
		quit(1)
		return
	print("FONT PROBE: bundled Chinese glyphs available")
	quit(0)
