#version 450

uniform mat4 u_view;
uniform mat4 u_proj;
uniform mat4 u_model;

struct Vertex
{
	vec3 pos;
	float uv_x;
	vec3 normal;
	float uv_y;
	vec4 color;
	vec3 tangent;
	float pad;
};

out vec2 a_uv;
out vec3 a_normal;
out vec3 a_frag_pos;

layout (std430, binding = 1) buffer ssbo2 {
	Vertex vertices[];
};

void main()
{
	Vertex v = vertices[gl_VertexID];
	gl_Position = u_proj * u_view * u_model * vec4(v.pos, 1);
	a_uv.x = v.uv_x;
	a_uv.y = v.uv_y;
	
	a_normal = mat3(transpose(inverse(u_model))) * v.normal;
	
	a_frag_pos = vec3(u_model * vec4(v.pos, 1.0f));
}