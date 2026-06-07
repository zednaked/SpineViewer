extends Control

# ── Config ─────────────────────────────────────────────────────────────────
const USER_DIR     := "user://spine/"
const DEMO_DIR     := "res://assets/spine/demo/"
const BAR_H        := 64
const DEFAULT_SCALE := 1.0

# ── State ───────────────────────────────────────────────────────────────────
var spine_node: Node
var looping    := true
var view_scale := DEFAULT_SCALE
var drag_on    := false
var drag_start := Vector2.ZERO
var node_start := Vector2.ZERO

# ── UI refs ─────────────────────────────────────────────────────────────────
var hint_lbl:   Label
var load_btn:   Button
var status_lbl: Label
var anim_btn:   OptionButton
var play_btn:   Button
var pause_btn:  Button
var stop_btn:   Button
var loop_btn:   Button
var speed_sld:  HSlider
var speed_lbl:  Label
var reset_btn:  Button


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()

	if OS.has_feature("web"):
		_set_status("Selecione os arquivos Spine para começar")
	else:
		# Editor/desktop: tenta carregar demo se existir
		var demo := _find_spine(DEMO_DIR)
		if not demo.is_empty():
			_load_spine(demo.skel, demo.atlas)
		else:
			_set_status("Modo desktop — coloque arquivos em assets/spine/demo/ ou use o browser")


# ── Build UI ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0e1018")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	hint_lbl = Label.new()
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	hint_lbl.text = "Clique em \"Carregar Spine\" e selecione:\n.spine-json (ou .skel)  +  .atlas  +  .png"
	hint_lbl.add_theme_color_override("font_color", Color("#3a4060"))
	hint_lbl.add_theme_font_size_override("font_size", 20)
	hint_lbl.set_anchors_and_offsets_preset(PRESET_CENTER)
	hint_lbl.offset_bottom = -BAR_H / 2
	add_child(hint_lbl)

	# ── Bottom bar ──────────────────────────────────────────────────────────
	var bar := Panel.new()
	bar.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bar.offset_top = -BAR_H
	var sb := StyleBoxFlat.new()
	sb.bg_color        = Color("#13182a")
	sb.border_width_top = 1
	sb.border_color     = Color("#1e2a45")
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hbox.offset_left  = 14
	hbox.offset_right = -14
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(hbox)

	# Load button — only visible on web
	load_btn = _btn("📂 Carregar Spine", hbox, _open_file_picker)
	load_btn.custom_minimum_size = Vector2(160, 36)
	load_btn.visible = OS.has_feature("web")

	if OS.has_feature("web"):
		_sep(hbox)

	anim_btn = OptionButton.new()
	anim_btn.custom_minimum_size = Vector2(200, 0)
	anim_btn.size_flags_vertical = SIZE_SHRINK_CENTER
	anim_btn.disabled = true
	anim_btn.item_selected.connect(_on_anim_selected)
	hbox.add_child(anim_btn)

	_sep(hbox)

	play_btn  = _btn("▶",  hbox, _on_play)
	pause_btn = _btn("⏸", hbox, _on_pause)
	stop_btn  = _btn("⏹", hbox, _on_stop)

	_sep(hbox)

	loop_btn = _btn("🔁", hbox, _on_loop)

	_sep(hbox)

	var vlbl := Label.new()
	vlbl.text = "Vel."
	vlbl.add_theme_font_size_override("font_size", 12)
	vlbl.add_theme_color_override("font_color", Color("#505870"))
	vlbl.size_flags_vertical = SIZE_SHRINK_CENTER
	hbox.add_child(vlbl)

	speed_sld = HSlider.new()
	speed_sld.min_value   = 0.1
	speed_sld.max_value   = 3.0
	speed_sld.step        = 0.1
	speed_sld.value       = 1.0
	speed_sld.custom_minimum_size = Vector2(110, 0)
	speed_sld.size_flags_vertical = SIZE_SHRINK_CENTER
	speed_sld.value_changed.connect(_on_speed)
	hbox.add_child(speed_sld)

	speed_lbl = Label.new()
	speed_lbl.text = "1.0×"
	speed_lbl.custom_minimum_size = Vector2(40, 0)
	speed_lbl.add_theme_font_size_override("font_size", 12)
	speed_lbl.add_theme_color_override("font_color", Color("#505870"))
	speed_lbl.size_flags_vertical = SIZE_SHRINK_CENTER
	hbox.add_child(speed_lbl)

	_sep(hbox)

	reset_btn = _btn("⟳ Reset", hbox, _reset_view)
	reset_btn.custom_minimum_size = Vector2(90, 36)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	status_lbl = Label.new()
	status_lbl.text = ""
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color("#353d58"))
	status_lbl.size_flags_vertical = SIZE_SHRINK_CENTER
	hbox.add_child(status_lbl)

	_set_controls(false)


func _btn(text: String, parent: Node, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(48, 36)
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _sep(parent: Node) -> void:
	var s := VSeparator.new()
	s.add_theme_color_override("separator_color", Color("#1e2a45"))
	s.custom_minimum_size = Vector2(1, 28)
	s.size_flags_vertical = SIZE_SHRINK_CENTER
	parent.add_child(s)


# ── Web file picker ───────────────────────────────────────────────────────────

func _open_file_picker() -> void:
	_set_status("Aguardando seleção...")
	JavaScriptBridge.eval("""
		(function() {
			window._spineReady = false;
			window._spineFiles = null;

			function toBase64(buf) {
				var bytes = new Uint8Array(buf);
				var binary = '';
				var CHUNK = 8192;
				for (var i = 0; i < bytes.length; i += CHUNK) {
					binary += String.fromCharCode.apply(null, bytes.subarray(i, i + CHUNK));
				}
				return btoa(binary);
			}

			var input = document.createElement('input');
			input.type = 'file';
			input.multiple = true;
			input.accept = '.spine-json,.skel,.atlas,.png,.webp';

			input.onchange = function(e) {
				var files = Array.from(e.target.files);
				var result = {};
				var pending = files.length;
				files.forEach(function(f) {
					var reader = new FileReader();
					reader.onload = function(evt) {
						result[f.name] = toBase64(evt.target.result);
						if (--pending === 0) {
							window._spineFiles = result;
							window._spineReady = true;
						}
					};
					reader.readAsArrayBuffer(f);
				});
			};
			input.click();
		})();
	""")
	set_process(true)


func _process(_dt: float) -> void:
	if not OS.has_feature("web"):
		return
	if not bool(JavaScriptBridge.eval("window._spineReady === true")):
		return
	set_process(false)

	var json_str := str(JavaScriptBridge.eval("JSON.stringify(window._spineFiles)"))
	JavaScriptBridge.eval("window._spineFiles = null; window._spineReady = false;")

	var files = JSON.parse_string(json_str)
	if files is Dictionary:
		_handle_web_files(files)
	else:
		_set_status("Erro ao ler os arquivos")


func _handle_web_files(files: Dictionary) -> void:
	_set_status("Gravando arquivos...")

	var skel_path := ""
	var atlas_path := ""

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_DIR))

	for name in files:
		var bytes: PackedByteArray = Marshalls.base64_to_raw(files[name])
		var out := USER_DIR + name
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f:
			f.store_buffer(bytes)
			f.close()
		var lname := name.to_lower()
		if lname.ends_with(".spine-json") or lname.ends_with(".skel"):
			skel_path = out
		elif lname.ends_with(".atlas"):
			atlas_path = out

	if skel_path.is_empty() or atlas_path.is_empty():
		_set_status("❌ Selecione: .spine-json/.skel + .atlas + .png")
		return

	# Aguarda um frame para o VFS do Emscripten processar as escritas
	await get_tree().process_frame
	_load_spine(skel_path, atlas_path)


# ── Spine loading ─────────────────────────────────────────────────────────────

func _find_spine(dir: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		return {}
	var skel := ""
	var atlas := ""
	for f in DirAccess.get_files_at(dir):
		var lf := f.to_lower()
		if lf.ends_with(".import"): continue
		if lf.ends_with(".spine-json") or lf.ends_with(".skel"):
			skel = dir + f
		elif lf.ends_with(".atlas"):
			atlas = dir + f
	if skel.is_empty() or atlas.is_empty():
		return {}
	return {skel = skel, atlas = atlas}


func _load_spine(skel_path: String, atlas_path: String) -> void:
	_set_status("Carregando recursos Spine...")

	var skel_res = ResourceLoader.load(skel_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if skel_res == null:
		_set_status("❌ Não foi possível carregar: " + skel_path.get_file())
		return

	var atlas_res = ResourceLoader.load(atlas_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if atlas_res == null:
		_set_status("❌ Não foi possível carregar: " + atlas_path.get_file())
		return

	var data_res = SpineSkeletonDataResource.new()
	data_res.skeleton_file_res = skel_res
	data_res.atlas_res         = atlas_res
	data_res.default_mix       = 0.15

	_setup_spine(data_res, skel_path.get_file().get_basename())


func _setup_spine(data_res, label: String) -> void:
	if spine_node != null:
		spine_node.queue_free()
		spine_node = null

	hint_lbl.hide()

	var sprite = SpineSprite.new()
	sprite.skeleton_data_res = data_res
	add_child(sprite)
	move_child(sprite, 1)
	spine_node = sprite

	_reset_view()
	await get_tree().process_frame

	_populate_animations()
	_set_controls(true)
	_set_status("✓ " + label)


func _populate_animations() -> void:
	if spine_node == null: return
	anim_btn.clear()
	var skeleton = spine_node.get_skeleton()
	if skeleton == null: return
	for anim in skeleton.get_data().get_animations():
		anim_btn.add_item(anim.get_name())
	if anim_btn.item_count > 0:
		anim_btn.select(0)
		_play_current()


# ── View ──────────────────────────────────────────────────────────────────────

func _reset_view() -> void:
	if spine_node == null: return
	view_scale = DEFAULT_SCALE
	var vp := get_viewport_rect().size
	spine_node.position = Vector2(vp.x * 0.5, (vp.y - BAR_H) * 0.72)
	spine_node.scale    = Vector2.ONE


func _set_controls(on: bool) -> void:
	anim_btn.disabled  = not on
	play_btn.disabled  = not on
	pause_btn.disabled = not on
	stop_btn.disabled  = not on
	loop_btn.disabled  = not on
	speed_sld.editable = on
	reset_btn.disabled = not on


func _set_status(msg: String) -> void:
	status_lbl.text = msg


func _play_current() -> void:
	if spine_node == null or anim_btn.selected < 0: return
	var state = spine_node.get_animation_state()
	if state == null: return
	state.set_animation(anim_btn.get_item_text(anim_btn.selected), looping, 0)
	spine_node.active = true


# ── Input — drag & scroll zoom ─────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if spine_node == null: return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				drag_on = event.pressed
				if event.pressed:
					drag_start = event.position
					node_start = spine_node.position
			MOUSE_BUTTON_WHEEL_UP:
				view_scale = clampf(view_scale * 1.1, 0.05, 20.0)
				spine_node.scale = Vector2(view_scale, view_scale)
			MOUSE_BUTTON_WHEEL_DOWN:
				view_scale = clampf(view_scale / 1.1, 0.05, 20.0)
				spine_node.scale = Vector2(view_scale, view_scale)
	elif event is InputEventMouseMotion and drag_on:
		spine_node.position = node_start + (event.position - drag_start)


# ── Button handlers ───────────────────────────────────────────────────────────

func _on_anim_selected(_idx: int) -> void:
	_play_current()

func _on_play() -> void:
	_play_current()

func _on_pause() -> void:
	if spine_node: spine_node.active = false

func _on_stop() -> void:
	if spine_node == null: return
	spine_node.active = false
	var sk = spine_node.get_skeleton()
	if sk: sk.set_to_setup_pose()
	var st = spine_node.get_animation_state()
	if st: st.clear_tracks()

func _on_loop() -> void:
	looping = not looping
	loop_btn.modulate.a = 1.0 if looping else 0.4
	_play_current()

func _on_speed(value: float) -> void:
	speed_lbl.text = "%.1f×" % value
	if spine_node:
		spine_node.time_scale = value
