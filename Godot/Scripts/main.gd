extends Control

# Intercepts ResourceLoader for PNG/WebP/JPG in user:// and returns ImageTexture.
# spine-godot's C++ atlas loader does Ref<Texture2D>(res) which silently fails
# when ResourceLoader returns Image for a raw PNG; this loader returns the correct type.
class _UserImageLoader:
	extends ResourceFormatLoader
	# No type annotations — avoids StringName/String mismatch in GDVirtual dispatch.
	func _get_recognized_extensions():
		return PackedStringArray(["png", "webp", "jpg", "jpeg"])
	func _get_resource_type(path):
		return "ImageTexture"
	func _handles_type(type_name):
		return true  # filter by path inside _load instead
	func _load(path, _orig, _threads, _cache):
		var p := str(path)
		if not p.begins_with("user://"):
			return ERR_UNAVAILABLE
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			return ERR_CANT_OPEN
		var bytes := f.get_buffer(f.get_length())
		f.close()
		var img := Image.new()
		var err: int
		if p.ends_with(".png"):
			err = img.load_png_from_buffer(bytes)
		elif p.ends_with(".webp"):
			err = img.load_webp_from_buffer(bytes)
		elif p.ends_with(".jpg") or p.ends_with(".jpeg"):
			err = img.load_jpg_from_buffer(bytes)
		else:
			return ERR_FILE_UNRECOGNIZED
		if err != OK:
			return err
		return ImageTexture.create_from_image(img)


# ── Config ─────────────────────────────────────────────────────────────────
const USER_DIR     := "user://spine/"
const DEMO_DIR     := "res://assets/spine/demo/"
const BAR_H        := 64
const DEFAULT_SCALE := 1.0

# ── State ───────────────────────────────────────────────────────────────────
var _user_img_loader: ResourceFormatLoader  # keep ref alive
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
	_user_img_loader = _UserImageLoader.new()
	ResourceLoader.add_resource_format_loader(_user_img_loader, true)

	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	set_process(false)

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
	load_btn = _btn("Carregar Spine", hbox, _open_file_picker)
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

	play_btn  = _btn("play",  hbox, _on_play)
	pause_btn = _btn("pausa", hbox, _on_pause)
	stop_btn  = _btn("para", hbox, _on_stop)

	_sep(hbox)

	loop_btn = _btn("loop", hbox, _on_loop)

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

	reset_btn = _btn("Reset", hbox, _reset_view)
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
	load_btn.disabled = true
	_set_status("Aguardando seleção...")
	JavaScriptBridge.eval("""
		(function() {
			window._spineReady = false;
			window._spineFiles = null;
			window._spineCancelled = false;

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
			input.accept = '.spine-json,.json,.skel,.atlas,.png,.webp';

			var filesChosen = false;

			input.addEventListener('cancel', function() {
				// Delay to let onchange fire first — GTK portal fires cancel even
				// after a successful selection, so only cancel if no files were picked.
				setTimeout(function() {
					if (!filesChosen) window._spineCancelled = true;
				}, 200);
			});

			input.onchange = function(e) {
				filesChosen = true;
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
					reader.onerror = function() {
						if (!window._spineReady) window._spineCancelled = true;
					};
					reader.readAsArrayBuffer(f);
				});
			};
			input.click();
		})();
	""")
	set_process(true)


func _process(_dt: float) -> void:
	if JavaScriptBridge.eval("window._spineCancelled === true"):
		JavaScriptBridge.eval("window._spineCancelled = false;")
		set_process(false)
		load_btn.disabled = false
		_set_status("Selecione os arquivos Spine para começar")
		return
	if not JavaScriptBridge.eval("window._spineReady === true"):
		return
	set_process(false)

	var json_str := str(JavaScriptBridge.eval("JSON.stringify(window._spineFiles)"))
	JavaScriptBridge.eval("window._spineFiles = null; window._spineReady = false;")

	var files = JSON.parse_string(json_str)
	if files is Dictionary:
		_handle_web_files(files)
	else:
		load_btn.disabled = false
		_set_status("Erro ao ler os arquivos")


func _handle_web_files(files: Dictionary) -> void:
	_set_status("Gravando arquivos...")

	var skel_path := ""
	var atlas_path := ""

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_DIR))

	for name in files:
		var fname: String  = str(name)
		var bytes: PackedByteArray = Marshalls.base64_to_raw(str(files[name]))
		var lname: String = fname.to_lower()

		# load_from_file only recognises .spine-json/.spjson as JSON; .json falls
		# through to the binary parser, which produces garbage. Rename on write.
		var save_name := fname
		if lname.ends_with(".json") and not lname.ends_with(".spine-json"):
			save_name = fname.get_basename() + ".spine-json"
			lname = save_name.to_lower()

		# Patch version so spine-cpp 4.3 accepts the file.
		if lname.ends_with(".spine-json"):
			var text := bytes.get_string_from_utf8()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary and parsed.has("skeleton"):
				var info = parsed["skeleton"]
				if info is Dictionary and info.has("spine"):
					var ver: String = str(info["spine"])
					var parts := ver.split(".")
					var major := int(parts[0]) if parts.size() > 0 else 0
					var minor := int(parts[1]) if parts.size() > 1 else 0
					if not (major == 4 and minor == 3):
						bytes = text.replace('"%s"' % ver, '"4.3.00"').to_utf8_buffer()

		var out: String = USER_DIR + save_name
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f:
			f.store_buffer(bytes)
			f.close()
			if lname.ends_with(".spine-json") or lname.ends_with(".skel"):
				skel_path = out
			elif lname.ends_with(".atlas"):
				atlas_path = out


	if skel_path.is_empty() or atlas_path.is_empty():
		load_btn.disabled = false
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
		if lf.ends_with(".spine-json") or lf.ends_with(".skel") or lf.ends_with(".json"):
			skel = dir + f
		elif lf.ends_with(".atlas"):
			atlas = dir + f
	if skel.is_empty() or atlas.is_empty():
		return {}
	return {skel = skel, atlas = atlas}


func _load_spine(skel_path: String, atlas_path: String) -> void:
	_set_status("Carregando skeleton...")

	var skel_res = ClassDB.instantiate("SpineSkeletonFileResource")
	if skel_res == null:
		load_btn.disabled = false
		_set_status("SpineGodot plugin não encontrado")
		return
	skel_res.call("load_from_file", skel_path)

	var af := FileAccess.open(atlas_path, FileAccess.READ)
	if af == null:
		load_btn.disabled = false
		_set_status("Atlas: erro ao abrir arquivo")
		return
	var atlas_text := af.get_as_text()
	af.close()

	var tex_array := []
	for line in atlas_text.split("\n"):
		var s := line.strip_edges()
		if s.ends_with(".png") or s.ends_with(".webp") or s.ends_with(".jpg"):
			var tex_path := atlas_path.get_base_dir() + "/" + s
			var tex = ResourceLoader.load(tex_path)
			tex_array.append(tex)

	var atlas_res = ClassDB.instantiate("SpineAtlasResource")
	if atlas_res == null:
		load_btn.disabled = false
		_set_status("SpineGodot plugin não encontrado")
		return

	atlas_res.call("load_from_atlas_file", atlas_path, tex_array, [], [])

	var data_res = ClassDB.instantiate("SpineSkeletonDataResource")
	if data_res == null:
		load_btn.disabled = false
		_set_status("SpineGodot plugin não encontrado")
		return
	data_res.set("skeleton_file_res", skel_res)
	data_res.set("atlas_res",         atlas_res)
	data_res.set("default_mix",       0.15)

	_setup_spine(data_res, skel_path.get_file().get_basename())


func _setup_spine(data_res, label: String) -> void:
	if spine_node != null:
		spine_node.queue_free()
		spine_node = null

	hint_lbl.hide()

	var sprite = ClassDB.instantiate("SpineSprite")
	if sprite == null:
		load_btn.disabled = false
		_set_status("❌ SpineGodot plugin não encontrado")
		return
	sprite.set("skeleton_data_res", data_res)
	add_child(sprite)
	move_child(sprite, 1)
	spine_node = sprite
	spine_node.set("active", true)

	_reset_view()
	await get_tree().process_frame
	await get_tree().process_frame

	var ok := _populate_animations(label)
	_set_controls(true)
	load_btn.disabled = false
	if ok and anim_btn.item_count > 0:
		_set_status("✓ " + label + " (%d anims)" % anim_btn.item_count)


func _populate_animations(label: String = "") -> bool:
	if spine_node == null: return false
	anim_btn.clear()
	var skeleton = spine_node.get_skeleton()
	if skeleton == null:
		_set_status("Erro ao carregar skeleton — verifique versão Spine (runtime: 4.3)")
		return false
	var data = skeleton.get_data()
	if data == null:
		_set_status("❌ SkeletonData null")
		return false
	for anim in data.get_animations():
		anim_btn.add_item(anim.get_name())
	if anim_btn.item_count == 0:
		_set_status("⚠ Skeleton OK mas sem animações")
		return false
	anim_btn.select(0)
	_play_current()
	return true


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
	if spine_node == null: return
	var state = spine_node.get_animation_state()
	if state == null: return
	var entry = state.get_current(0)
	if entry != null:
		entry.set_loop(looping)
	else:
		_play_current()

func _on_speed(value: float) -> void:
	speed_lbl.text = "%.1f×" % value
	if spine_node:
		spine_node.time_scale = value
