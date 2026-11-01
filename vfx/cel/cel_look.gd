@tool
class_name CelLook
extends RefCounted
## Turns imported models' StandardMaterial3D into eldskald's cel shader
## (vfx/cel, MIT): albedo colour + texture carry over, leaves / grass (alpha)
## get the cut-out version, and an optional inverted-hull outline pass.
## Converted materials are cached per source material, so a forest of the
## same tree shares a handful of materials. The toon light bands come from
## the global `diffuse_curve` (vfx/cel/diffuse_curve.tres, Project Settings >
## Shader Globals, with outline_color / outline_width).

const OPAQUE: Shader = preload("res://vfx/cel/cel-shader-base.gdshader")
const CUTOUT: Shader = preload("res://vfx/cel/cel-shader-cutout.gdshader")
const OUTLINE: Shader = preload("res://vfx/cel/outline.gdshader")

static var _cache: Dictionary[String, Material] = {}
static var _outline: ShaderMaterial
static var _white: ImageTexture


## Every MeshInstance3D under `root` gets cel materials (surface overrides).
static func apply(root: Node, outline: bool) -> void:
	if root is MeshInstance3D:
		var mi: MeshInstance3D = root as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, material_for(mi.mesh.surface_get_material(s), outline))
	for child: Node in root.get_children():
		apply(child, outline)


static func material_for(source: Material, outline: bool) -> Material:
	var key: String = "%d:%s" % [source.get_instance_id() if source != null else 0, outline]
	if _cache.has(key):
		return _cache[key]
	var bm: BaseMaterial3D = source as BaseMaterial3D
	var cut: bool = bm != null and bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = CUTOUT if cut else OPAQUE
	mat.set_shader_parameter(&"color", bm.albedo_color if bm != null else Color(0.7, 0.7, 0.7))
	mat.set_shader_parameter(&"base_texture", bm.albedo_texture if bm != null and bm.albedo_texture != null else _white_texture())
	mat.set_shader_parameter(&"specular", Color(0.15, 0.15, 0.15, 0.2))
	mat.set_shader_parameter(&"fresnel", Color(0.35, 0.28, 0.2, 0.25))
	if cut:
		mat.set_shader_parameter(&"alpha_cutoff", 0.5)
	if outline and not cut:
		mat.next_pass = _outline_material()
	_cache[key] = mat
	return mat


static func _outline_material() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE
	return _outline


static func _white_texture() -> ImageTexture:
	if _white == null:
		var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white
