#version 450
#extension GL_ARB_bindless_texture : enable
uniform uvec2 u_base_tex_id;

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
	
	vec4 tex_col = texture(sampler2D(u_base_tex_id), a_uv);
	
	//vec3 color = normalize(a_normal) * 0.5 + 0.5;
	//out_color = vec4(color, 1);
	
	//out_color = vec4(1, 1, 1, 1);
	out_color = tex_col * vec4(result, 1);
}