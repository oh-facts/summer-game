#version 450
#extension GL_ARB_bindless_texture : enable

in vec2 a_uv;
in vec3 a_normal;

layout (location=0) out vec4 out_color;

void main() 
{
	//out_color = vec4(1, 1, 1, 1);
	out_color = vec4(a_normal, 1);
}