#version 450
#extension GL_ARB_bindless_texture : enable

flat in uvec2 a_tex_id;
flat in vec4 a_color;
in vec2 a_uv;

layout (location=0) out vec4 out_color;

void main() 
{
	vec4 tex_col = texture(sampler2D(a_tex_id), a_uv);
	
	if (tex_col.a < 0.1) {
		discard;
	}
	
	out_color = tex_col * a_color;
	//out_color = vec4(1, 1, 1, 1);
}