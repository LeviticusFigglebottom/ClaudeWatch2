shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// First-person viewmodel material.
// * Projects with its own (narrower) vertical FOV so the weapon keeps sane proportions regardless of the world FOV.
// * Compresses view-space depth toward the camera so the arms/weapon draw in front of nearby walls instead of clipping.
// Screen position is unchanged by the depth compression (uniform scale about the eye), so hand/muzzle positions
// computed by FirstPersonRig.vm_to_world() line up with what is drawn.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float vm_fov = 55.0;
uniform float depth_scale = 0.3;

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	mat4 p = PROJECTION_MATRIX;
	// Keep the sign of the diagonal terms: Godot's Vulkan projection flips Y.
	float aspect = abs(p[1][1] / p[0][0]);
	float f = 1.0 / tan(radians(vm_fov) * 0.5);
	p[1][1] = sign(p[1][1]) * f;
	p[0][0] = sign(p[0][0]) * f / aspect;
	POSITION = p * vec4(vp.xyz * depth_scale, 1.0);
}

void fragment() {
	ALBEDO = albedo.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = emission.rgb * emission_energy;
}
