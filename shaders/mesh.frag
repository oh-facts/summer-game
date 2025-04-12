#version 450
#extension GL_ARB_bindless_texture : enable

struct Light {
	vec3 pos;
	vec3 dir;
	
	vec3 ambient;
	vec3 diffuse;
	vec3 specular;
};

float constant = 1.0f;
float linear = 0.09f;
float quadratic = 0.032f;

uniform uvec2 u_base_tex_id;
uniform Light u_dir_light;

#define NUM_POINT_LIGHTS 1  
uniform Light u_point_lights[NUM_POINT_LIGHTS];

in vec2 a_uv;
in vec3 a_normal;
in vec3 a_frag_pos;

layout (location=0) out vec4 out_color;

void main() 
{
	vec4 tex_col = texture(sampler2D(u_base_tex_id), a_uv);
	vec3 norm = normalize(a_normal);
	
	vec3 dir_light_result;
	vec3 point_light_result;
	
	// dir light
	{
		vec3 light_dir = normalize(-u_dir_light.dir);
		
		float diff = max(dot(norm, light_dir), 0.0);
		
		vec3 ambient = u_dir_light.ambient * tex_col.xyz;
		vec3 diffuse = diff * u_dir_light.diffuse  * tex_col.xyz;
		
		dir_light_result = ambient + diffuse;
	}
	
	// point lights
	for (int i = 0; i < NUM_POINT_LIGHTS; i++) {
		Light light = u_point_lights[i];
		
		vec3 light_dir = normalize(light.pos - a_frag_pos);
		float diff = max(dot(norm, light_dir), 0.0);
		
		float distance = length(light.pos - a_frag_pos);
    float attenuation = 1.0 / (constant + linear * distance + 
															 quadratic * (distance * distance));    
		
		vec3 ambient = light.ambient * tex_col.xyz;
		vec3 diffuse = diff * light.diffuse  * tex_col.xyz;
		diffuse *= attenuation;
		
		point_light_result += ambient + diffuse;
	}
	//dir_light_result + 
	//out_color = vec4(1, 1, 1, 1);
	out_color = vec4(point_light_result, 1);
	
	if (false)
	{
		vec3 color = normalize(a_normal) * 0.5 + 0.5;
		out_color = vec4(color, 1);
	}
}