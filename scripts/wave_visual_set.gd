## One wave's enemy ship image set (Phase 18 FR18.1 / Phase 21 FR21.2).
##
## Godot does not support nested typed collections (Array[Array[Texture2D]]),
## so each wave's images live in their own Resource. LevelConfig holds an
## Array[WaveVisualSet] index-aligned with category_sequence; each set is
## edited in the Inspector through a native Texture2D picker.
class_name WaveVisualSet
extends Resource

## Ordered Texture2D images for this wave. Spawn slot k uses
## textures[k % textures.size()] (FR18.2). Empty means "use the category
## default sprite".
@export var textures: Array[Texture2D] = []
