#version 450
#extension GL_ARB_bindless_texture : enable

flat in uvec2 a_tex_id;
flat in vec4 a_color;
in vec2 a_uv;
in vec3 a_normal;
in vec3 a_frag_pos;

layout (location=0) out vec4 out_color;

void main() 
{
	vec3 light_color = vec3(1, 1, 1); 
	vec3 light_pos = vec3(1, 1, 1); 
	
	float ambient_str = 0.4;
	vec3 ambient = ambient_str * light_color;
	
	vec3 norm = normalize(a_normal);
	vec3 light_dir = normalize(light_pos - a_frag_pos);
	float diff = max(dot(norm, light_dir), 0.0);
	vec3 diffuse = diff * light_color;
	
	vec3 result = ambient + diffuse;
	
	vec4 tex_col = texture(sampler2D(a_tex_id), a_uv);
	
	if (tex_col.a < 0.1) {
		discard;
	}
	
	//vec3 color = normalize(a_normal) * 0.5 + 0.5;
	//out_color = vec4(color, 1);
	
	//out_color = vec4(1, 1, 1, 1) * vec4(result, 1);
	out_color = tex_col * a_color * vec4(result, 1);
}