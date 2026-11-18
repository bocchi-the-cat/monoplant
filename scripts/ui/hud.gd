class_name HUD
extends CanvasLayer
## All runtime UI is built in code so it stays in one place and survives art passes.
## The HUD only reads game state; it never mutates gameplay directly.

var player: Player

var root: Control
var crosshair_ring: Panel
var crosshair_dot: ColorRect
var prompt_label: Label
var money_label: Label
var sub_label: Label
var selected_label: Label
var hint_label: Label
var hotbar: HBoxContainer
var slot_widgets: Array = []
var toast_box: VBoxContainer

var info_panel: PanelContainer
var info_title: Label
var info_stage: Label
var info_time: Label
var info_water: ProgressBar
var info_water_label: Label

var modal_layer: Control
var modal_panel: PanelContainer
var modal_title: Label
var modal_body: VBoxContainer
var modal_open := false
var paused := false

var delivery_panel: PanelContainer
var delivery_rows: VBoxContainer


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_connect()
	_refresh_money(GameState.money, 0)
	_refresh_hotbar()
	_refresh_selected()
	set_process(true)


func _connect() -> void:
	EventBus.toast.connect(_toast)
	EventBus.hotbar_changed.connect(_refresh_hotbar)
	EventBus.slot_selected.connect(_on_slot_selected)
	EventBus.money_changed.connect(_refresh_money)
	EventBus.shop_requested.connect(open_shop)
	EventBus.sell_requested.connect(open_sell)
	EventBus.board_requested.connect(open_board)
	EventBus.pack_requested.connect(open_pack)
	EventBus.order_board_changed.connect(_refresh_deliveries)
	EventBus.hotbar_changed.connect(_refresh_deliveries)


# --------------------------------------------------------------------------
# Construction
# --------------------------------------------------------------------------

func _style(bg: Color, border_col := Color(0, 0, 0, 0), radius := 6, border := 0, pad := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_col
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


func _label(text: String, size := 16, color := Color.WHITE, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, action: Callable, disabled := false, min_size := Vector2(84, 30)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Palette.color("ui_text"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Palette.color("ui_dim").darkened(0.15))
	b.add_theme_stylebox_override("normal", _style(Color(0.14, 0.16, 0.17), Palette.color("ui_accent").darkened(0.35), 5, 1, 6))
	b.add_theme_stylebox_override("hover", _style(Color(0.24, 0.2, 0.14), Palette.color("ui_accent"), 5, 1, 6))
	b.add_theme_stylebox_override("pressed", _style(Palette.color("ui_accent").darkened(0.45), Palette.color("ui_accent"), 5, 1, 6))
	b.add_theme_stylebox_override("disabled", _style(Color(0.11, 0.12, 0.13), Color(0.24, 0.26, 0.27), 5, 1, 6))
	b.pressed.connect(action)
	return b


func _full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build() -> void:
	root = Control.new()
	root.name = "Root"
	_full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_crosshair()
	_build_money()
	_build_hotbar()
	_build_info_panel()
	_build_toasts()
	_build_modal()
	_build_delivery_tracker()

	hint_label = _label("WASD move   E interact   1-8 hotbar   G drop   Esc menu", 13, Palette.color("ui_dim"), 3)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.position = Vector2(18, -30)
	root.add_child(hint_label)


func _build_crosshair() -> void:
	var center := CenterContainer.new()
	_full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(18, 18)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(holder)

	crosshair_ring = Panel.new()
	crosshair_ring.size = Vector2(14, 14)
	crosshair_ring.position = Vector2(2, 2)
	crosshair_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style := _style(Color(0, 0, 0, 0), Color(1, 1, 1, 0.45), 7, 1, 0)
	crosshair_ring.add_theme_stylebox_override("panel", ring_style)
	crosshair_ring.visible = false
	holder.add_child(crosshair_ring)

	var backing := ColorRect.new()
	backing.color = Color(0, 0, 0, 0.55)
	backing.size = Vector2(6, 6)
	backing.position = Vector2(6, 6)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(backing)

	crosshair_dot = ColorRect.new()
	crosshair_dot.color = Color(1, 1, 1, 0.95)
	crosshair_dot.size = Vector2(4, 4)
	crosshair_dot.position = Vector2(7, 7)
	crosshair_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(crosshair_dot)

	prompt_label = _label("", 19, Color.WHITE, 5)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prompt_label.offset_left = -320
	prompt_label.offset_right = 320
	prompt_label.offset_top = 40
	prompt_label.offset_bottom = 72
	prompt_label.anchor_top = 0.5
	prompt_label.anchor_bottom = 0.5
	root.add_child(prompt_label)


func _build_money() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.09, 0.82), Palette.color("ui_panel_light"), 7, 1, 12))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -214
	panel.offset_right = -16
	panel.offset_top = 16
	panel.offset_bottom = 96
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	money_label = _label("$0", 30, Palette.color("ui_good"))
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(money_label)

	sub_label = _label("Earned $0", 12, Palette.color("ui_dim"))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(sub_label)


func _build_hotbar() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -104
	holder.offset_bottom = -18
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)

	hotbar = HBoxContainer.new()
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 6)
	_full_rect(hotbar)
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(hotbar)

	for i in Inventory.SLOT_COUNT:
		hotbar.add_child(_make_slot(i))

	selected_label = _label("Empty hands", 16, Palette.color("ui_text"), 4)
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	selected_label.offset_top = -136
	selected_label.offset_bottom = -112
	root.add_child(selected_label)


func _make_slot(index: int) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(62, 70)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := PanelContainer.new()
	_full_rect(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", _style(Color(0.08, 0.09, 0.1, 0.78), Palette.color("ui_panel_light"), 6, 1, 0))
	slot.add_child(bg)

	var swatch := ColorRect.new()
	swatch.size = Vector2(30, 30)
	swatch.position = Vector2(16, 10)
	swatch.visible = false
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(swatch)

	var num := _label(str(index + 1), 11, Palette.color("ui_dim"))
	num.position = Vector2(6, 2)
	slot.add_child(num)

	var count := _label("", 15, Palette.color("ui_text"), 3)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -58
	count.offset_top = -24
	count.offset_right = -5
	count.offset_bottom = -2
	slot.add_child(count)

	slot_widgets.append({"root": slot, "bg": bg, "swatch": swatch, "count": count, "num": num})
	return slot


func _build_info_panel() -> void:
	info_panel = PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.09, 0.9), Palette.color("ui_panel_light"), 8, 1, 14))
	info_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	info_panel.offset_left = -286
	info_panel.offset_right = -18
	info_panel.offset_top = -228
	info_panel.offset_bottom = -112
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.visible = false
	root.add_child(info_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_child(box)

	info_title = _label("Daisy", 19, Palette.color("ui_text"))
	box.add_child(info_title)

	info_stage = _label("", 13, Palette.color("ui_dim"))
	box.add_child(info_stage)

	info_time = _label("", 13, Palette.color("ui_accent"))
	box.add_child(info_time)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar_row)

	info_water = ProgressBar.new()
	info_water.custom_minimum_size = Vector2(170, 9)
	info_water.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_water.show_percentage = false
	info_water.max_value = 100.0
	info_water.add_theme_stylebox_override("background", _style(Color(0.16, 0.17, 0.18), Color(0, 0, 0, 0), 4, 0, 0))
	info_water.add_theme_stylebox_override("fill", _style(Palette.color("can_metal"), Color(0, 0, 0, 0), 4, 0, 0))
	bar_row.add_child(info_water)

	info_water_label = _label("Water 100%", 12, Palette.color("ui_dim"))
	bar_row.add_child(info_water_label)


func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_box.offset_left = 0
	toast_box.offset_right = 0
	toast_box.offset_top = 18
	toast_box.offset_bottom = 240
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)


func _build_modal() -> void:
	modal_layer = Control.new()
	_full_rect(modal_layer)
	modal_layer.visible = false
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.62)
	_full_rect(dim)
	modal_layer.add_child(dim)

	var center := CenterContainer.new()
	_full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.add_child(center)

	modal_panel = PanelContainer.new()
	modal_panel.custom_minimum_size = Vector2(560, 0)
	modal_panel.add_theme_stylebox_override("panel", _style(Color(0.09, 0.1, 0.11, 0.98), Palette.color("ui_accent"), 10, 2, 0))
	center.add_child(modal_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 20)
	modal_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	col.add_child(header)

	modal_title = _label("Title", 24, Palette.color("ui_text"))
	modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(modal_title)

	var close := _button("Close", _close_modal, false, Vector2(78, 32))
	header.add_child(close)

	var divider := HSeparator.new()
	col.add_child(divider)

	modal_body = VBoxContainer.new()
	modal_body.add_theme_constant_override("separation", 10)
	col.add_child(modal_body)

	modal_layer.set_meta("center", center)


func _build_delivery_tracker() -> void:
	delivery_panel = PanelContainer.new()
	delivery_panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.07, 0.08, 0.85), Palette.color("ui_accent"), 7, 1, 10))
	delivery_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	delivery_panel.offset_left = 16
	delivery_panel.offset_top = 16
	delivery_panel.offset_right = 292
	delivery_panel.offset_bottom = 120
	delivery_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delivery_panel.visible = false
	root.add_child(delivery_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delivery_panel.add_child(box)

	var title := _label("DELIVERIES", 11, Palette.color("ui_accent"))
	box.add_child(title)

	delivery_rows = VBoxContainer.new()
	delivery_rows.add_theme_constant_override("separation", 3)
	delivery_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(delivery_rows)


func _refresh_deliveries() -> void:
	if delivery_rows == null or delivery_panel == null:
		return
	if OrderSystem.active.is_empty():
		delivery_panel.visible = false
		return
	delivery_panel.visible = true
	for c in delivery_rows.get_children():
		delivery_rows.remove_child(c)
		c.queue_free()
	for o in OrderSystem.active:
		var customer_id := String(o["customer_id"])
		var flower := String(FlowerDB.get_flower(String(o["flower_id"])).get("name", "?"))
		var row := _label("%s  -  %d x %s" % [CustomerDB.display_name(customer_id), int(o["qty"]), flower], 13, Palette.color("ui_text"))
		delivery_rows.add_child(row)
		var where := _label("    " + CustomerDB.place(customer_id), 11, Palette.color("ui_dim"))
		delivery_rows.add_child(where)


# --------------------------------------------------------------------------
# Frame updates
# --------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		return

	if modal_open:
		prompt_label.text = ""
		crosshair_ring.visible = false
		return

	var focus := player.get_focus()
	var pot := focus as PlantPot
	if pot != null:
		_show_pot_info(pot)
	else:
		info_panel.visible = false

	var text := ""
	var actionable := false
	if focus != null and focus.has_method("get_prompt"):
		text = String(focus.get_prompt(player))
		actionable = bool(focus.is_actionable(player)) if focus.has_method("is_actionable") else true

	if text == "":
		prompt_label.text = ""
	else:
		prompt_label.text = ("[E]  " + text) if actionable else text
		prompt_label.add_theme_color_override("font_color", Color.WHITE if actionable else Palette.color("ui_dim"))

	crosshair_ring.visible = text != ""
	crosshair_dot.color = Palette.color("ui_accent") if (focus != null and text != "") else Color(1, 1, 1, 0.9)


func _show_pot_info(pot: PlantPot) -> void:
	var info := pot.get_info()
	info_panel.visible = true
	if bool(info.get("empty", true)):
		info_title.text = "Empty planter"
		info_title.add_theme_color_override("font_color", Palette.color("ui_dim"))
		info_stage.text = "Select a seed packet, then press E"
		info_time.text = ""
		info_water.value = 0
		info_water_label.text = "Water -"
		return

	var ready := bool(info["ready"])
	var spent := bool(info["spent"])
	info_title.text = String(info["name"])
	info_title.add_theme_color_override("font_color", Palette.color("ui_good") if ready else Palette.color("ui_text"))

	if spent:
		info_stage.text = "Harvested"
		info_time.text = "Clear the planter with E"
	elif ready:
		info_stage.text = "Bloom"
		info_time.text = "Ready to harvest"
	else:
		info_stage.text = "Stage: %s" % String(info["stage"])
		if float(info["water"]) <= 0.5:
			info_time.text = "Growth stalled - needs water"
			info_time.add_theme_color_override("font_color", Palette.color("ui_bad"))
		else:
			info_time.text = "%ds left" % int(ceil(float(info["time_left"])))
			info_time.add_theme_color_override("font_color", Palette.color("ui_accent"))

	info_water.value = float(info["water"])
	info_water_label.text = "Water %d%%" % int(round(float(info["water"])))


# --------------------------------------------------------------------------
# Hotbar / money
# --------------------------------------------------------------------------

func _refresh_hotbar() -> void:
	if slot_widgets.is_empty():
		return
	for i in Inventory.SLOT_COUNT:
		var w: Dictionary = slot_widgets[i]
		var s = Inventory.slots[i]
		var swatch: ColorRect = w["swatch"]
		var count: Label = w["count"]
		if s == null:
			swatch.visible = false
			count.text = ""
			continue
		swatch.visible = true
		swatch.color = ItemDB.swatch_color(String(s["id"]))
		if ItemDB.is_can(String(s["id"])):
			count.text = "%d/%d" % [int(s["meta"].get("charges", 0)), ItemDB.CAN_MAX_CHARGES]
		elif int(s["count"]) > 1:
			count.text = "x%d" % int(s["count"])
		else:
			count.text = ""
	_refresh_selection_styles()
	_refresh_selected()


func _on_slot_selected(_index: int) -> void:
	_refresh_selection_styles()
	_refresh_selected()


func _refresh_selection_styles() -> void:
	for i in slot_widgets.size():
		var w: Dictionary = slot_widgets[i]
		var bg: PanelContainer = w["bg"]
		var selected := i == Inventory.selected
		var bg_col := Color(0.14, 0.15, 0.16, 0.95) if selected else Color(0.08, 0.09, 0.1, 0.78)
		var border_col := Palette.color("ui_accent") if selected else Palette.color("ui_panel_light")
		bg.add_theme_stylebox_override("panel", _style(bg_col, border_col, 6, 2 if selected else 1, 0))


func _refresh_selected() -> void:
	if selected_label == null:
		return
	var s := Inventory.selected_slot()
	if s.is_empty():
		selected_label.text = "Empty hands"
		return
	var text := ItemDB.display_name(String(s["id"]))
	if ItemDB.is_can(String(s["id"])):
		text += "   %d/%d charges" % [int(s["meta"].get("charges", 0)), ItemDB.CAN_MAX_CHARGES]
	elif int(s["count"]) > 1:
		text += "   x%d" % int(s["count"])
	selected_label.text = text


func _refresh_money(amount: int, _delta: int) -> void:
	if money_label == null:
		return
	money_label.text = "$%d" % amount
	var next := GameState.next_unlock()
	if next.is_empty():
		sub_label.text = "Earned $%d  -  all varieties unlocked" % GameState.total_earned
	else:
		sub_label.text = "Earned $%d  -  next unlock $%d" % [GameState.total_earned, int(next.get("unlock_earned", 0))]


# --------------------------------------------------------------------------
# Toasts
# --------------------------------------------------------------------------

func _toast(text: String) -> void:
	if toast_box == null:
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.07, 0.08, 0.9), Palette.color("ui_accent"), 5, 0, 10))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := _label(text, 15, Palette.color("ui_text"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(l)
	toast_box.add_child(panel)

	while toast_box.get_child_count() > 4:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()

	var tween := create_tween()
	tween.tween_interval(2.8)
	tween.tween_property(panel, "modulate:a", 0.0, 0.45)
	tween.tween_callback(panel.queue_free)


# --------------------------------------------------------------------------
# Modals
# --------------------------------------------------------------------------

func _open_modal(title: String, width := 560) -> void:
	modal_open = true
	modal_layer.visible = true
	modal_title.text = title
	modal_panel.custom_minimum_size = Vector2(width, 0)
	for c in modal_body.get_children():
		modal_body.remove_child(c)
		c.queue_free()
	EventBus.ui_blocked.emit(true)


func _close_modal() -> void:
	modal_open = false
	modal_layer.visible = false
	if paused:
		get_tree().paused = false
		paused = false
	EventBus.ui_blocked.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		if modal_open:
			_close_modal()
		else:
			open_pause()
		get_viewport().set_input_as_handled()


func _add_modal_row(title: String, subtitle: String, right_text: String, button_text: String, action: Callable, disabled := false, tooltip := "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	modal_body.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	row.add_child(left)

	left.add_child(_label(title, 17, Palette.color("ui_text")))
	if subtitle != "":
		var sub := _label(subtitle, 12, Palette.color("ui_dim"))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(sub)

	if right_text != "":
		row.add_child(_label(right_text, 16, Palette.color("ui_accent")))

	var button := _button(button_text, action, disabled, Vector2(84, 32))
	button.tooltip_text = tooltip
	row.add_child(button)


func _modal_note(text: String, color := Color.WHITE) -> void:
	var l := _label(text, 13, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.add_child(l)


# --------------------------------------------------------------------------
# Shop
# --------------------------------------------------------------------------

func open_shop() -> void:
	_open_modal("Bloom Supply", 640)
	_modal_note("Seeds are charged to your cash. Sell blooms at the counter or to buyers around town.", Palette.color("ui_dim"))

	for id in FlowerDB.all_ids():
		var f := FlowerDB.get_flower(id)
		var cost := int(f["seed_cost"])
		var unlocked := GameState.is_unlocked(id)
		var sub := "Grows in %ds  -  yields %d-%d  -  sells from $%d" % [
			int(f["grow_time"]), int(f["yield_min"]), int(f["yield_max"]), int(f["base_value"]),
		]
		var disabled := not unlocked or not GameState.can_afford(cost)
		var tooltip := ""
		if not unlocked:
			tooltip = "Unlocks after earning $%d" % int(f.get("unlock_earned", 0))
			sub += "   (locked: $%d earned)" % int(f.get("unlock_earned", 0))
		_add_modal_row(
			String(f["name"]), sub, "$%d" % cost, "Buy",
			_buy_seed.bind(id), disabled, tooltip
		)

	# The $1 safety net, always affordable so a broke run can recover.
	var starter := FlowerDB.get_flower(FlowerDB.STARTER_SPECIES)
	_add_modal_row(
		"Wildflower Seeds",
		"Grows in %ds  -  sells from $%d  -  cheap filler, always in stock" % [
			int(starter["grow_time"]), int(starter["base_value"]),
		],
		"$%d" % int(starter["seed_cost"]),
		"Buy",
		_buy_seed.bind(FlowerDB.STARTER_SPECIES),
		not GameState.can_afford(int(starter["seed_cost"])),
		""
	)

	modal_body.add_child(HSeparator.new())
	_add_modal_row(
		"Watering Can",
		"Six charges. Refill free at the greenhouse tap.",
		"$%d" % ItemDB.get_item("can:watering")["value"],
		"Buy",
		_buy_can,
		not GameState.can_afford(int(ItemDB.get_item("can:watering")["value"]))
	)


func _buy_seed(id: String) -> void:
	var f := FlowerDB.get_flower(id)
	var cost := int(f["seed_cost"])
	if not GameState.is_unlocked(id):
		EventBus.notify("Locked - earn $%d first" % int(f.get("unlock_earned", 0)))
		return
	if not GameState.spend(cost):
		EventBus.notify("Not enough money")
		return
	var stack_id := FlowerDB.seed_item(id)
	var leftover := Inventory.add(stack_id, 1)
	if leftover > 0:
		GameState.add_money(cost)
		EventBus.notify("Hotbar full - purchase refunded")
		return
	EventBus.notify("Bought %s seeds" % String(f["name"]))
	open_shop()
	_refresh_money(GameState.money, 0)


func _buy_can() -> void:
	var cost := int(ItemDB.get_item("can:watering")["value"])
	if not GameState.spend(cost):
		EventBus.notify("Not enough money")
		return
	var leftover := Inventory.add("can:watering", 1, {"charges": ItemDB.CAN_MAX_CHARGES})
	if leftover > 0:
		GameState.add_money(cost)
		EventBus.notify("Hotbar full - purchase refunded")
		return
	EventBus.notify("Bought a watering can")
	open_shop()
	_refresh_money(GameState.money, 0)


# --------------------------------------------------------------------------
# Pause
# --------------------------------------------------------------------------

func open_pause() -> void:
	_open_modal("Paused", 400)
	_modal_note("Your flowers keep growing while this menu is open.", Palette.color("ui_dim"))

	modal_body.add_child(_button("Resume", _close_modal, false, Vector2(0, 38)))
	modal_body.add_child(_button("Save now", _save_now, false, Vector2(0, 38)))
	modal_body.add_child(_button("New run (deletes save)", _new_run, false, Vector2(0, 38)))
	modal_body.add_child(_button("Quit to desktop", _quit_game, false, Vector2(0, 38)))

	paused = true
	get_tree().paused = true


func _save_now() -> void:
	if SaveSystem.save_game():
		EventBus.notify("Game saved")
	else:
		EventBus.notify("Could not save")


func _new_run() -> void:
	SaveSystem.delete_save()
	paused = false
	get_tree().paused = false
	modal_open = false
	get_tree().reload_current_scene()


func _quit_game() -> void:
	SaveSystem.save_game()
	get_tree().quit()


# --------------------------------------------------------------------------
# Buyers / orders
# --------------------------------------------------------------------------

func _add_info_row(title: String, subtitle: String, right_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	modal_body.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	row.add_child(left)

	left.add_child(_label(title, 16, Palette.color("ui_text")))
	if subtitle != "":
		var sub := _label(subtitle, 12, Palette.color("ui_dim"))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(sub)

	if right_text != "":
		row.add_child(_label(right_text, 16, Palette.color("ui_accent")))


func _add_trust_bar(customer_id: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_body.add_child(row)

	row.add_child(_label("Trust", 12, Palette.color("ui_dim")))

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(260, 10)
	bar.max_value = CustomerSystem.TRUST_MAX
	bar.value = CustomerSystem.get_trust(customer_id)
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _style(Color(0.16, 0.17, 0.18), Color(0, 0, 0, 0), 4, 0, 0))
	bar.add_theme_stylebox_override("fill", _style(Palette.color("ui_good"), Color(0, 0, 0, 0), 4, 0, 0))
	row.add_child(bar)

	row.add_child(_label("%d / %d" % [CustomerSystem.get_trust(customer_id), CustomerSystem.TRUST_MAX], 12, Palette.color("ui_dim")))


func _sellable_flowers() -> Array:
	var ids := FlowerDB.all_ids()
	ids.append(FlowerDB.STARTER_SPECIES)
	return ids


func open_sell(customer_id: String) -> void:
	var c := CustomerDB.get_customer(customer_id)
	_open_modal("%s  -  %s" % [String(c.get("name", "Buyer")), String(c.get("role", ""))], 660)
	_modal_note(String(c.get("greeting", "")), Palette.color("ui_text"))
	_modal_note("Prefers %s (+30%%). Anything else sells at -20%%." % CustomerDB.preferences_text(customer_id), Palette.color("ui_dim"))
	_add_trust_bar(customer_id)
	modal_body.add_child(HSeparator.new())

	var any := false
	for flower_id in _sellable_flowers():
		var bloom := FlowerDB.bloom_item(String(flower_id))
		var qty := Inventory.count_of(bloom)
		if qty <= 0:
			continue
		any = true
		_add_sell_row(customer_id, String(flower_id), qty)

	if not any:
		_modal_note("You have no cut flowers. Harvest some blooms first.", Palette.color("ui_dim"))
	else:
		_modal_note("Prices rise as trust grows. Bring them what they like.", Palette.color("ui_dim"))


func _add_sell_row(customer_id: String, flower_id: String, qty: int) -> void:
	var f := FlowerDB.get_flower(flower_id)
	var unit := CustomerSystem.quote(flower_id, customer_id)
	var preferred := CustomerSystem.sells_preference(flower_id, customer_id)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	modal_body.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	row.add_child(left)

	left.add_child(_label("%d x %s" % [qty, String(f["name"])], 16, Palette.color("ui_text")))
	var sub_color := Palette.color("ui_good") if preferred else Palette.color("ui_dim")
	var sub_text := "Preferred (+30%)" if preferred else "Not their favourite (-20%)"
	left.add_child(_label(sub_text, 11, sub_color))

	row.add_child(_label("$%d each" % unit, 15, Palette.color("ui_accent")))

	var one := _button("Sell 1", _sell_flowers.bind(customer_id, flower_id, 1), false, Vector2(66, 30))
	row.add_child(one)

	var all := _button("All", _sell_flowers.bind(customer_id, flower_id, qty), false, Vector2(52, 30))
	row.add_child(all)


func _sell_flowers(customer_id: String, flower_id: String, count: int) -> void:
	var bloom := FlowerDB.bloom_item(flower_id)
	var available := Inventory.count_of(bloom)
	if available <= 0:
		return
	var take := mini(count, available)
	var unit := CustomerSystem.quote(flower_id, customer_id)
	var removed := Inventory.remove_item(bloom, take)
	if removed <= 0:
		return
	var total := unit * removed
	GameState.add_money(total)
	CustomerSystem.add_trust(customer_id, 2 + removed * 2)
	EventBus.sale_completed.emit(customer_id, total)
	EventBus.notify("Sold %d x %s for $%d" % [removed, String(FlowerDB.get_flower(flower_id)["name"]), total])
	open_sell(customer_id)


func open_board() -> void:
	_open_modal("Order Board", 700)
	_modal_note("Standing requests from around the block. Pack them at the bench, then deliver in person.", Palette.color("ui_dim"))

	if OrderSystem.requests.is_empty():
		_modal_note("No open requests right now.", Palette.color("ui_dim"))
	for req in OrderSystem.requests:
		var customer_id := String(req["customer_id"])
		var flower_id := String(req["flower_id"])
		var flower_name := String(FlowerDB.get_flower(flower_id).get("name", "Flowers"))
		var sub := "%s  -  prefers %s" % [CustomerDB.place(customer_id), CustomerDB.preferences_text(customer_id)]
		_add_info_row(
			"%s wants %d x %s" % [CustomerDB.display_name(customer_id), int(req["qty"]), flower_name],
			sub,
			"$%d" % int(req["reward"])
		)

	if not OrderSystem.active.is_empty():
		modal_body.add_child(HSeparator.new())
		_modal_note("In transit", Palette.color("ui_accent"))
		for o in OrderSystem.active:
			var customer_id := String(o["customer_id"])
			var flower_name := String(FlowerDB.get_flower(String(o["flower_id"])).get("name", "Flowers"))
			_add_info_row(
				"%s  -  %d x %s" % [CustomerDB.display_name(customer_id), int(o["qty"]), flower_name],
				"Deliver to: %s" % CustomerDB.place(customer_id),
				"$%d" % int(o["reward"])
			)


func open_pack() -> void:
	_open_modal("Packing Bench", 720)
	_modal_note("Packing consumes the blooms and produces one order box, which takes a hotbar slot.", Palette.color("ui_dim"))

	if OrderSystem.requests.is_empty():
		_modal_note("No open requests. Check the order board by the door.", Palette.color("ui_dim"))
		return

	for req in OrderSystem.requests:
		var flower_id := String(req["flower_id"])
		var flower_name := String(FlowerDB.get_flower(flower_id).get("name", "Flowers"))
		var qty := int(req["qty"])
		var have := Inventory.count_of(FlowerDB.bloom_item(flower_id))
		var customer_id := String(req["customer_id"])
		var can := OrderSystem.can_pack(req)
		var sub := "For %s  -  you have %d of %d" % [CustomerDB.display_name(customer_id), have, qty]
		_add_modal_row(
			"%d x %s" % [qty, flower_name],
			sub,
			"$%d" % int(req["reward"]),
			"Pack",
			_pack_order.bind(int(req["id"])),
			not can,
			"Harvest more flowers first" if not can else ""
		)


func _pack_order(order_id: int) -> void:
	if OrderSystem.pack(order_id):
		open_pack()
	else:
		EventBus.notify("Not enough flowers for that order")
