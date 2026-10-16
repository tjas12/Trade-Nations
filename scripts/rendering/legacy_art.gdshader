shader_type canvas_item;
// Existing converted RAW files were incorrectly flipped and R/B-swapped.
// Undo that conversion at draw time; archival and PNG bytes remain unchanged.
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
    COLOR = tint * texture(TEXTURE, vec2(UV.x, 1.0 - UV.y)).bgra;
}
