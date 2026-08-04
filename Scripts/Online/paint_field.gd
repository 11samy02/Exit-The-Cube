class_name PaintField
extends Node3D

## The painted floor, and the cube standing on it that keeps painting more.
##
## Two jobs that belong together because they share the same grid: watching which
## cell the local player is over and claiming it, and drawing every cell anybody
## has claimed.
##
## The drawing is one MultiMesh rather than a node per tile. A gigantic map is
## nine thousand cells, and a round can end with most of them painted — that is
## nine thousand nodes to build, cull and free, against one draw call for the lot.
## The buffer is rebuilt rather than edited because a MultiMesh has no way to
## remove one instance, and rebuilding four thousand transforms costs less than a
## frame at the rate this is allowed to happen

## Put in a group so the race panel can read the score without a path
const GROUP := &"paint_field"

## How far above the floor the paint sits. Enough to clear the surface it covers,
## little enough that it still reads as being on it rather than hovering
const PAINT_HEIGHT := 0.03

## What share of the cell one patch of paint covers. Slightly under the whole
## thing keeps a grid of dark lines between the tiles, so a painted floor still
## reads as a floor rather than as a flat sheet of colour
const PAINT_SHARE := 0.92

## Seconds between two rebuilds of the drawing. Paint arrives a few tiles at a
## time from everybody at once, and redrawing on each one would rebuild the whole
## buffer a hundred times a second for no visible gain
const REDRAW_INTERVAL := 0.15

var _mesh: MultiMeshInstance3D = null
var _grid: GridMap = null

## True while the drawing no longer matches the state behind it
var _dirty: bool = true

var _redraw_timer: float = 0.0

## The cell the local cube was last standing over, so that standing still does
## not re-claim the same tile fifteen times a second
var _last_cell: Vector2i = Vector2i(-9999, -9999)


func _ready() -> void:
	add_to_group(GROUP)
	_grid = get_parent() as GridMap
	_build_mesh()
	Online.paint_changed.connect(_on_paint_changed)


func _process(delta: float) -> void:
	if not Online.is_painting():
		return

	_claim_under_player()

	_redraw_timer -= delta
	if _dirty and _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		_dirty = false
		_redraw()


## One flat quad per painted cell, coloured per instance. Unshaded so a tile
## reads as its team's colour in a corridor the lights never reach.
##
## The size comes off the grid rather than being a number written here. A cell
## is two units across in this map and a patch built for a one unit cell covers
## a quarter of the floor it is supposed to be painting
func _build_mesh() -> void:
	var across := _grid.cell_size.x if _grid != null else 1.0

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * across * PAINT_SHARE
	quad.orientation = PlaneMesh.FACE_Y

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	quad.material = material

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = quad

	_mesh = MultiMeshInstance3D.new()
	_mesh.multimesh = multi
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


## Claims whatever the local cube is standing over. Only the cell it moved onto,
## so a player parked on one tile is not sending a claim on it every frame
func _claim_under_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or _grid == null:
		return

	var death := get_tree().get_first_node_in_group("player_death") as PlayerDeath
	if death != null and death.is_dead:
		return

	var at := _grid.local_to_map(_grid.to_local(player.global_position))
	var cell := Vector2i(at.x, at.z)

	if cell == _last_cell:
		return

	_last_cell = cell
	Online.paint_cell(cell)


## Rebuilds the whole drawing off the state. A MultiMesh cannot have an instance
## taken out of it, and a round where paint is overwritten and lost to deaths is
## nothing but instances being taken out
func _redraw() -> void:
	var claims: Dictionary = Online.paint.claims
	var multi := _mesh.multimesh
	multi.instance_count = claims.size()

	var at := 0

	for cell: Vector2i in claims:
		var claim: PaintState.Claim = claims[cell]
		multi.set_instance_transform(at, Transform3D(Basis(), _world_of(cell)))
		multi.set_instance_color(at, Online.team_color(claim.team))
		at += 1


## The top face of that floor tile.
##
## map_to_local hands back the middle of the cell, not its surface — the floor
## block is centred on that point and reaches half a cell above it. Painting at
## the point itself buries the whole thing inside the block, which is exactly as
## visible as not painting at all
func _world_of(cell: Vector2i) -> Vector3:
	var local := _grid.map_to_local(Vector3i(cell.x, 0, cell.y))
	local.y += _grid.cell_size.y * 0.5 + PAINT_HEIGHT
	return _grid.to_global(local)


func _on_paint_changed() -> void:
	_dirty = true


## Called when the cube is put back after a death, so that the tile it respawns
## on is claimed rather than being skipped for having been the last one stood on
func forget_last_cell() -> void:
	_last_cell = Vector2i(-9999, -9999)
