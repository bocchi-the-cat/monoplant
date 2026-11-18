class_name Palette
extends RefCounted
## One cohesive low-poly palette. Every surface colour in the game comes from here,
## which is what keeps procedural geometry from looking like a graybox.

const COLORS := {
	# --- structure ---
	"asphalt": Color("33353a"),
	"asphalt_light": Color("3c3f45"),
	"concrete": Color("8a877e"),
	"sidewalk": Color("9b978c"),
	"curb": Color("b9b4a7"),
	"brick": Color("8f5d4c"),
	"brick_dark": Color("6f4538"),
	"brick_pale": Color("a8796a"),
	"stucco": Color("cfc5ae"),
	"stucco_warm": Color("d8c39a"),
	"stucco_green": Color("a9b39a"),
	"trim": Color("3a3a38"),
	"roof": Color("4c4a45"),
	"wood": Color("8a6a44"),
	"wood_dark": Color("5c452d"),
	"wood_pale": Color("b08b5e"),
	"metal": Color("9aa0a3"),
	"metal_dark": Color("5b6064"),
	"glass": Color(0.64, 0.82, 0.86, 0.16),
	"glass_dark": Color(0.3, 0.45, 0.5, 0.55),
	"wall_inner": Color("d9d2c2"),
	"wall_green": Color("b9c9b1"),
	"floor_tile": Color("8f8a7d"),
	"floor_wood": Color("a08050"),

	# --- nature ---
	"grass": Color("6c8a4e"),
	"grass_dark": Color("566f3f"),
	"grass_pale": Color("7f9c5e"),
	"leaf": Color("3f7a45"),
	"leaf_light": Color("5d9c52"),
	"leaf_dark": Color("2f5c36"),
	"stem": Color("4b6b3a"),
	"trunk": Color("6b5138"),
	"soil": Color("4a3626"),
	"soil_dry": Color("72573c"),
	"soil_wet": Color("33241a"),
	"pot": Color("b4674a"),
	"pot_dark": Color("8d4e39"),

	# --- flowers ---
	"flower_white": Color("f2efe6"),
	"flower_yellow": Color("f2c53d"),
	"flower_orange": Color("e8842c"),
	"flower_orange_deep": Color("b85a16"),
	"flower_pink": Color("e8789f"),
	"flower_pink_deep": Color("c05278"),
	"flower_purple": Color("9a6fc4"),
	"flower_red": Color("c93f47"),
	"flower_red_deep": Color("91262e"),
	"flower_brown": Color("6b4a2a"),
	"seed_packet": Color("b99a6c"),
	"can_metal": Color("7fa8b8"),
	"box_cardboard": Color("b98d5c"),

	# --- lighting / ui ---
	"grow_light": Color("ffd9c4"),
	"lamp_warm": Color("ffe6b8"),
	"neon_pink": Color("ff6fae"),
	"neon_teal": Color("5fd8c4"),
	"ui_panel": Color("1d2024"),
	"ui_panel_light": Color("2b2f34"),
	"ui_text": Color("f0ece2"),
	"ui_dim": Color("a9a49a"),
	"ui_accent": Color("e8a33d"),
	"ui_good": Color("79c27c"),
	"ui_bad": Color("d96060"),
	"sky_top": Color("6f9bc4"),
	"sky_horizon": Color("d8c7ae"),
	"fog": Color("b9b6a8"),
}

static var _mats: Dictionary = {}


static func color(key: String) -> Color:
	return COLORS.get(key, Color.MAGENTA)


static func flat(c: Color, roughness := 0.9, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	m.metallic = metallic
	return m


## Shared, cached opaque material for a palette key.
static func mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color(key)
	m.roughness = 0.92 if key != "metal" else 0.45
	m.metallic = 0.25 if key == "metal" else 0.0
	if key == "neon_pink" or key == "neon_teal":
		m.emission_enabled = true
		m.emission = color(key)
		m.emission_energy_multiplier = 2.2
	_mats[key] = m
	return m


static func glass() -> StandardMaterial3D:
	if _mats.has("__glass"):
		return _mats["__glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = color("glass")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = true
	m.rim = 0.35
	_mats["__glass"] = m
	return m


static func glow(key: String, energy := 2.0) -> StandardMaterial3D:
	var ck := "__glow_%s_%s" % [key, energy]
	if _mats.has(ck):
		return _mats[ck]
	var m := StandardMaterial3D.new()
	m.albedo_color = color(key)
	m.emission_enabled = true
	m.emission = color(key)
	m.emission_energy_multiplier = energy
	m.roughness = 0.6
	_mats[ck] = m
	return m


## Subtle procedural grain for big surfaces. Cheap to generate, hides the "flat box" look.
static func textured(key: String, noise_scale := 6.0, strength := 0.16) -> StandardMaterial3D:
	var ck := "__tex_%s_%s_%s" % [key, noise_scale, strength]
	if _mats.has(ck):
		return _mats[ck]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035 * noise_scale
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.generate_mipmaps = true

	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = color(key)
	m.roughness = 0.95
	m.uv1_scale = Vector3(3, 3, 3)
	m.uv1_triplanar = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# Slight darkening of the low end so grain reads as material, not haze.
	m.vertex_color_use_as_albedo = false
	_mats[ck] = m
	return m


static func sky_material() -> ProceduralSkyMaterial:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = color("sky_top")
	sky.sky_horizon_color = color("sky_horizon")
	sky.ground_horizon_color = color("sky_horizon")
	sky.ground_bottom_color = Color("4b4a44")
	sky.sun_angle_max = 18.0
	sky.sun_curve = 0.12
	return sky
