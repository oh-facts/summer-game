// Read this.
// Since some of our artists use blockbench.
// The model needs to be opened in blender and shaded smooth
// However, the faces in blockbench aren't joined together
// so first combine all vertices, then smooth shade
// I am sure there is a python (ew) script that can do this.
// https://github.com/JannisX11/blockbench/issues/2024

Primitive :: struct {
	start : u32;
	count : u32;
	
	base_color : Vector3;
	base_tex_index : u64;
	//normal_tex_index : u32;
};

Vertex :: struct {
	pos : Vector3;
	uv_x : float;
	normal : Vector3;
	uv_y : float;
	color : Vector4;
	tangent : Vector3;
	pad : float;
};

Mesh :: struct {
	primitives : *Primitive;
	num_primitives : u64;
	indices : *u32;
	num_indices : u64;
	
	vertices : *Vertex;
	num_vertices : u64;
	
	buffer : Mesh_Buffer;
	
	transform : Matrix4;
};

GLTF_Scene :: struct {
	gpu_textures : *Image;
	textures : *Bitmap;
	num_textures : u64;
	
	meshes : *Mesh;
	num_meshes : u64;
	xform := Matrix4_Identity;
};

GLTF_It :: struct {
	arena : *Arena;
	mesh_index : u64;
	scene : *GLTF_Scene;
	data : *cgltf_data;
	dir : string;
};

gltf_traverseNode :: (it : *GLTF_It, node : *cgltf_node) {
	if node.mesh {
		node_mesh := node.mesh;
		
		mesh := it.scene.meshes + it.mesh_index;
		mesh.num_primitives = node_mesh.primitives_count;
		mesh.primitives = push_array(it.arena, Primitive, mesh.num_primitives);
		
		m_vertex_num := 0;
		m_index_num := 0;
		
		for i : 0 .. mesh.num_primitives - 1{
			node_prim := node.mesh.primitives + i;
			index_attrib := node_prim.indices;
			
			mesh.num_indices += index_attrib.count;
		}
		
		for i : 0 .. mesh.num_primitives - 1 {
			node_prim := node.mesh.primitives + i;
			
			for j : 0 .. node_prim.attributes_count - 1 {
				attrib := node_prim.attributes + j;
				
				if attrib.type == .cgltf_attribute_type_position {
					vert_attrib := attrib.data;
					mesh.num_vertices += vert_attrib.count;
				}
			}
		}
		
		mesh.indices = push_array(it.arena, u32, mesh.num_indices);
		mesh.vertices = push_array(it.arena, Vertex, mesh.num_vertices);
		
		for i : 0 .. mesh.num_primitives - 1 {
			init_vtx := m_vertex_num;
			init_index := m_index_num;
			
			node_prim := node.mesh.primitives + i;
			
			p := mesh.primitives + i;
			
			if node_prim.material.pbr_metallic_roughness.base_color_texture.texture {
				p.base_tex_index = cgltf_texture_index(it.data, node_prim.material.pbr_metallic_roughness.base_color_texture.texture); 
			}
			
			if node_prim.material.normal_texture.texture {
				//p.normal_tex_index = cgltf_texture_index(it.data, node_prim.material.normal_texture.texture);
			}
			
			index_attrib := node_prim.indices;
			
			p.start = xx init_index;
			p.count = xx index_attrib.count;
			
			// indices
			{
				for j : 0 .. index_attrib.count - 1 {
					index := cgltf_accessor_read_index(index_attrib, j);
					mesh.indices[j + xx m_index_num] = xx (index + xx init_vtx);
				}
				
				m_index_num += xx index_attrib.count;
			}
			
			// vertices
			for j : 0 .. node_prim.attributes_count - 1 {
				attrib := node_prim.attributes + j;
				
				if attrib.type == .cgltf_attribute_type_position {
					vert_attrib := attrib.data;
					m_vertex_num += xx vert_attrib.count;
					
					for k : 0 .. vert_attrib.count - 1 {
						cgltf_accessor_read_float(vert_attrib, k, mesh.vertices[k + xx init_vtx].pos.component.data, size_of(float));
					}
				}
				
				if attrib.type == .cgltf_attribute_type_normal {
					norm_attrib := attrib.data;
					
					for k : 0 .. norm_attrib.count - 1 {
						cgltf_accessor_read_float(norm_attrib, k, mesh.vertices[k + xx init_vtx].normal.component.data, size_of(float));
					}
				}
				
				if attrib.type == .cgltf_attribute_type_color {
					color_attrib := attrib.data;
					for k : 0 .. color_attrib.count - 1 {
						cgltf_accessor_read_float(color_attrib, k, mesh.vertices[k + xx init_vtx].color.component.data, size_of(float));
					}
				}
				
				if attrib.type == .cgltf_attribute_type_texcoord {
					tex_attrib := attrib.data;
					
					// TODO(mizu):  difference b/w attrib index 0 and 1
					if attrib.index == 0 {
						for k : 0 .. tex_attrib.count - 1 {
							tex : [2]float;
							
							cgltf_accessor_read_float(tex_attrib, k, tex.data, size_of(float));
							mesh.vertices[k + xx init_vtx].uv_x = tex[0];
							mesh.vertices[k + xx init_vtx].uv_y = 1 - tex[1];
						}
					}
				}
				
				if attrib.type == .cgltf_attribute_type_tangent {
					tangent_attrib := attrib.data;
					for k : 0 .. tangent_attrib.count - 1 {
						cgltf_accessor_read_float(tangent_attrib, k, mesh.vertices[k + xx init_vtx].tangent.component.data, size_of(float));
					}
				}
			}
		}
		
		mat : [16]float;
		cgltf_node_transform_world(node, mat.data);
		
		for i : 0 .. 4 - 1 {
			for j : 0 .. 4 - 1 {
				mesh.transform.coef[j][i] = mat[i * 4 + j];
			}
		}
		
		it.mesh_index+=1;
	}
	
	for i : 0 .. (cast(int)node.children_count) - 1 {
		gltf_traverseNode(it, node.children[i]);
	}
}

gltf_print :: (scene : *GLTF_Scene) {
	for i : 0 .. scene.num_meshes - 1 {
		mesh := scene.meshes + i;
		
		print("indices %\n", i);
		for j : 0 .. mesh.num_indices - 1 {
			print("%, ", mesh.indices[j]);
		}
		print("\n");
		
		print("verticess %\n", i);
		for j : 0 .. mesh.num_vertices - 1 {
			vert := mesh.vertices + j;
			print("[%, %, %]", vert.pos.x, vert.pos.y, vert.pos.z);
		}
		print("\n");
		
		for j : 0 .. mesh.num_primitives - 1 {
			p := mesh.primitives;
			
			print("start: %\n", p.start);
			print("count: %\n", p.count);
		}
		
		print("\n");
	}
}

gltf_loadMesh :: (arena : *Arena, filename : string) -> GLTF_Scene {
	out : GLTF_Scene;
	
	it : GLTF_It;
	
	foldername := path_strip_filename(filename);
	
	options : cgltf_options;
	data : *cgltf_data;
	
	if cgltf_parse_file(*options, filename.data, *data) != .cgltf_result_success {
		assert(false, "couldn't find %", filename);
	}
	
	if cgltf_load_buffers(*options, data, filename.data) != .cgltf_result_success {
		assert(false, "couldn't load buffers %", filename);
	}
	
	// load textures
	
	out.num_textures = data.textures_count;
	out.textures = push_array(arena, Bitmap, data.textures_count);
	
	for i : 0 .. data.textures_count - 1 {
		
		uri_str : string;
		uri_str.data = data.textures[i].image.uri;
		
		c := uri_str.data[0];
		index : int;
		
		while c != #char "\0" {
			c = uri_str.data[index];
			index += 1;
		}
		
		uri_str.count = index;
		
		texture_abs_path := tprint("%0% ",foldername, uri_str);
		
		texture_file_data := read_entire_file(texture_abs_path);
		
		out.textures[i] = bitmap(texture_file_data);
	}
	
	// load meshes
	out.num_meshes = data.meshes_count;
	out.meshes = push_array(arena, Mesh, out.num_meshes);
	
	it.scene = *out;
	it.arena = arena;
	it.data = data;
	
	for i : 0 .. data.scenes_count - 1 {
		scene := data.scenes + i;
		
		for j : 0 .. scene.nodes_count - 1 {
			node := scene.nodes[j];
			
			gltf_traverseNode(*it, node);
		}
	}
	
	//gltf_print(it.scene);
	
	cgltf_free(data);
	
	return out;
}

gltf_upload :: (arena : *Arena, scene : *GLTF_Scene) {
	scene.gpu_textures = push_array(arena, Image, scene.num_textures);
	for i : 0 .. scene.num_textures - 1 {
		scene.gpu_textures[i] = image(scene.textures[i]);
	}
	
	for i : 0 .. scene.num_meshes - 1 {
		mesh := scene.meshes + i;
		mesh.buffer = mesh_buffer(mesh.vertices, xx mesh.num_vertices, mesh.indices, xx mesh.num_indices);
	}
}

cgltf_texture_index :: (data : *cgltf_data, object : *cgltf_texture) -> cgltf_size {
	//assert(object && (cgltf_size)(object - data->textures) < data->textures_count);
	return cast(cgltf_size)(object - data.textures);
}