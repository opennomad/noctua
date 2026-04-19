#include <flutter/runtime_effect.glsl>

// u_time: fractional cycle count (0→1 per screen crossing at speed=1)
uniform float u_time;
uniform float u_width;
uniform float u_height;
uniform vec4  u_color_bg;
uniform vec4  u_color_a;
uniform vec4  u_color_b;
uniform float u_amplitude;
uniform float u_density;

out vec4 fragColor;

float hash1v(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One tiled layer of rising bubbles.
// Samples the 3×3 cell neighbourhood so glow is never clipped at cell edges
// (which would produce visible grid lines).
vec3 bubbleLayer(
    vec2 uv,
    float cell_size,
    float rise_rate,
    float layer_phase,
    vec3 col_a,
    vec3 col_b
) {
  vec2 grid  = uv / cell_size;
  vec2 cid   = floor(grid);
  vec2 cfrac = fract(grid);

  vec3 total = vec3(0.0);

  for (int dy = -1; dy <= 1; dy++) {
    for (int dx = -1; dx <= 1; dx++) {
      vec2 nid   = cid + vec2(float(dx), float(dy));
      vec2 nfrac = cfrac - vec2(float(dx), float(dy));  // fragment pos in neighbour space

      float h1 = hash1v(nid);
      float h2 = hash1v(nid + vec2(38.2, 17.9));
      float h3 = hash1v(nid + vec2(93.7, 55.4));

      // Seamless rise: fract wraps so the bubble loops bottom→top.
      float t_cell = fract(u_time * rise_rate + layer_phase + h3 * 0.9);

      // Gentle horizontal wobble as the bubble rises.
      float wobble = sin((u_time * rise_rate + h1 * 6.28318) * 2.5) * 0.07;

      // Bubble centre within its cell (y=0 is top, so 1-t_cell moves upward).
      vec2 center = vec2(0.15 + h1 * 0.70 + wobble, 1.0 - t_cell);

      float dist   = length(nfrac - center);
      float radius = 0.09 + h2 * 0.11;

      // Soft Gaussian glow.
      float glow = exp(-dist * dist / (radius * radius * 0.45));

      // Fade in near bottom (t_cell≈0) and out near top (t_cell≈1).
      // Note: smoothstep requires edge0 < edge1; reversed fade-out uses 1-smoothstep.
      float fade = smoothstep(0.0, 0.12, t_cell) * (1.0 - smoothstep(0.85, 1.0, t_cell));

      total += mix(col_a, col_b, h1) * (glow * fade);
    }
  }

  return total;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / vec2(u_width, u_height);

  // Aspect-correct so bubbles stay circular on any screen shape.
  float asp = u_width / u_height;
  vec2 auv  = vec2(uv.x * asp, uv.y);

  float cell = 0.22 / clamp(u_density, 0.2, 3.0);

  vec3 bg    = u_color_bg.rgb;
  vec3 col_a = u_color_a.rgb;
  vec3 col_b = u_color_b.rgb;
  float amp  = clamp(u_amplitude, 0.0, 2.0);

  vec3 result = bg;
  result += bubbleLayer(auv, cell * 1.50, 1.00, 0.00, col_a, col_b) * amp;
  result += bubbleLayer(auv, cell * 0.95, 1.40, 0.33, col_b, col_a) * amp * 0.80;
  result += bubbleLayer(auv, cell * 0.60, 1.85, 0.66, col_a, col_b) * amp * 0.55;

  fragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}
