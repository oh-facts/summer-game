#version 450
#extension GL_ARB_bindless_texture : enable

layout (location=0) out vec4 out_color;

uniform uvec2 u_skybox;
in vec3 a_uv;

void main() 
{
	//out_color = vec4(1, 1, 1, 1);
	//out_color = vec4(a_uv, 1);
	//out_color = texture(u_skybox, vec3(1.0, 0.0, 0.0));
	
	
	vec4 tex_col = texture(samplerCube(u_skybox), a_uv);
	
	out_color = tex_col;
}