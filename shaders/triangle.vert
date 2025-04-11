#version 450

uniform mat4 u_view;
uniform mat4 u_proj;

flat out uvec2 a_tex_id;
flat out vec4 a_color;
out vec2 a_uv;
out vec3 a_normal;
out vec3 a_frag_pos;

struct Vertex2
{
	vec2 pos;
	vec2 uv;
};

struct Rect
{
	vec2 tl;
	vec2 br;
};

struct Quad
{
	mat4 model;
	vec4 color;
	Rect src;
	uvec2 tex_id;
	uint pad[2];
};

layout (std430, binding = 1) buffer ssbo2 {
	layout(row_major) Quad quads[];
};

void main()
{
	Quad obj = quads[gl_InstanceID];
	
	Vertex2 vertices[] = 
	{
		{{-0.5, -0.5}, {obj.src.tl.x, obj.src.br.y}},
		{{0.5, -0.5}, {obj.src.br.x, obj.src.br.y}},
		{{-0.5, 0.5}, {obj.src.tl.x, obj.src.tl.y}},
		
		{{-0.5, 0.5}, {obj.src.tl.x, obj.src.tl.y}},
		{{0.5, -0.5}, {obj.src.br.x, obj.src.br.y}},
		{{0.5, 0.5}, {obj.src.br.x, obj.src.tl.y}},
	};
	
	Vertex2 v = vertices[gl_VertexID];
	vec4 pos = vec4(v.pos, 0, 1);
	
	a_normal = mat3(transpose(inverse(obj.model))) * vec3(0, 0, 1);
	
	a_frag_pos = vec3(obj.model * vec4(v.pos, 0, 1.0f));
	
	a_uv = v.uv;
	a_uv.y = 1 - a_uv.y;
	a_tex_id = obj.tex_id;
	a_color = obj.color;
	gl_Position = u_proj * u_view * obj.model * pos;
}

/*
	Vertex2 vertices[] = 
	{
		{{-0.5, -0.5}, {0, 0}},
		{{0.5, -0.5}, {1, 0}},
		{{-0.5, 0.5}, {0, 1}},
		
		{{-0.5, 0.5}, {0, 1}},
		{{0.5, -0.5}, {1, 0}},
		{{0.5, 0.5}, {1, 1}},
	};
*/