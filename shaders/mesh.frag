#version 450
#extension GL_ARB_bindless_texture : enable
uniform uvec2 u_base_tex_id;

in vec2 a_uv;
in vec3 a_normal;

layout (location=0) out vec4 out_color;

void main() 
{
	vec4 tex_col = texture(sampler2D(u_base_tex_id), a_uv);
	
	//vec3 color = normalize(a_normal) * 0.5 + 0.5;
	//out_color = vec4(color, 1);
	
	//out_color = vec4(1, 1, 1, 1);
	out_color = tex_col;
}