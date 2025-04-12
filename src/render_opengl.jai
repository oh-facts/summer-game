VF_Shaders :: enum {
	Quad;
	Light;
	Mesh;
	Skybox;
	Count;
}

Instance_Buffers :: enum {
	Quad;
	Count;
}

r_state : struct {
	shaders_folder : string;
	
	vf_shaders : [VF_Shaders.Count]GLuint;
	inst_buffers : [Instance_Buffers.Count]GLuint;
	
	white_tex : Image;
}

vf_shader_paths :[VF_Shaders.Count]string: .["triangle", "light", "mesh", "skybox"];

make_ssbo :: (size : u64) -> GLuint {
	ssbo : GLuint;
	glCreateBuffers(1, *ssbo);
	glNamedBufferData(ssbo, xx size, xx 0, GL_STREAM_DRAW);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);
	
	return ssbo;
}

compile_shaders :: () {
	for 0 .. VF_Shaders.Count - 1 {
		vert_abs_path := tprint("%/%.vert", r_state.shaders_folder, vf_shader_paths[it]);
		
		vert_shader_file := read_entire_file(vert_abs_path, true);
		defer free(vert_shader_file);
		
		frag_abs_path := tprint("%/%.frag", r_state.shaders_folder, vf_shader_paths[it]);
		
		frag_shader_file := read_entire_file(frag_abs_path, true);
		defer free(frag_shader_file);
		
		r_state.vf_shaders[it] = make_shader_program(vert_shader_file, frag_shader_file);
	}
}

check_compile_errors :: (shader : GLuint, type : *u8) {
	success : s32;
	infoLog: [1024]u8;
	
	glGetShaderiv(shader, GL_COMPILE_STATUS, *success);
	if !success {
		glGetShaderInfoLog(shader, 1024, xx 0, xx infoLog.data);
		print("% compilation error:\n%\n", to_string(type), to_string(infoLog.data));
		assert(false);
	}
}

check_link_errors :: (shader : GLuint, type : *u8) {
	success : s32;
	infoLog : [1024]u8;
	glGetProgramiv(shader, GL_LINK_STATUS, *success);
	if !success {
		glGetProgramInfoLog(shader, 1024, xx 0, xx infoLog.data);
		print("% linking error:\n%\n", to_string(type), to_string(infoLog.data));
		assert(false);
	}
}

make_shader_program :: (vertexShaderSource : string, fragmentShaderSource : string) -> GLuint {
	vert_shader := glCreateShader(GL_VERTEX_SHADER);
	glShaderSource(vert_shader, 1, *(vertexShaderSource.data), xx 0);
	glCompileShader(vert_shader);
	
	check_compile_errors(vert_shader, "vertex shader");
	
	frag_shader := glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(frag_shader, 1, *(fragmentShaderSource.data), xx 0);
	glCompileShader(frag_shader);
	check_compile_errors(frag_shader, "fragment shader");
	
	shader_prog := glCreateProgram();
	glAttachShader(shader_prog, vert_shader);
	glAttachShader(shader_prog, frag_shader);
	
	glLinkProgram(shader_prog);
	check_link_errors(shader_prog, "vert/frag shader");
	
	glDeleteShader(vert_shader);
	glDeleteShader(frag_shader);
	
	return shader_prog;
}

uvec2_from_u64 :: (v : u64) -> u32, u32 {
	l : u32 = cast(u32) (v & 0xFFFFFFFF); 
	r: u32 = cast(u32) (v >> 32);
	
	return l, r;
}

Image :: struct {
	id : GLuint;
	resident : GLuint64;
	w : u32;
	h : u32;
}

Mesh_Buffer :: struct {
	vertex_buffer : GLuint;
	index_buffer : GLuint;
}

image :: (bmp : Bitmap, params := Tex_Params.Nearest) -> Image {
	
	id : GLuint;
	glCreateTextures(GL_TEXTURE_2D, 1, *id);
	
	if params == .Linear {
		glTextureParameteri(id, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTextureParameteri(id, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	} else {
		glTextureParameteri(id, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTextureParameteri(id, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	}
	
	glTextureStorage2D(id, 1, GL_RGBA32F, xx bmp.w, xx bmp.h);
	if bmp.data {
		glTextureSubImage2D(id, 0, 0, 0, xx bmp.w, xx bmp.h, GL_RGBA, GL_UNSIGNED_BYTE, bmp.data);
	}
	
	glTextureParameteri(id, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTextureParameteri(id, GL_TEXTURE_WRAP_T, GL_REPEAT);
	
	//glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
	//glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	
	resident := glGetTextureHandleARB(id);
	glMakeTextureHandleResidentARB(resident);
	
	out : Image;
	
	out.id = id;
	out.resident = resident;
	out.w = xx bmp.w;
	out.h = xx bmp.h;
	
	return out;
}

mesh_buffer :: (vertices : *Vertex, num_vertices : u32, indices : *u32, num_indices : u32) -> Mesh_Buffer {
	out : Mesh_Buffer;
	
	// vertex buffer
	{
		vbo : GLuint;
		size := size_of(Vertex) * num_vertices;
		
		glCreateBuffers(1, *vbo);
		glNamedBufferData(vbo, xx size, vertices, GL_STATIC_DRAW);
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, vbo);
		out.vertex_buffer = vbo;
	}
	
	// index buffer
	{
		ebo : GLuint;
		size := size_of(u32) * num_indices;
		
		glCreateBuffers(1, *ebo);
		glNamedBufferData(ebo, size, indices, GL_STATIC_DRAW);
		out.index_buffer = ebo;
	}
	
	return out;
}

whitey : u32 = 0xFFFFFFFF;

render_init :: () {
	gl_create_context(the_window, 4, 6);
	gl_load(*gl);
	r_state.shaders_folder = join(exe_folder, "../shaders");
	
	stupid_fucking_opengl : GLuint;
	glCreateVertexArrays(1, *stupid_fucking_opengl);
	glBindVertexArray(stupid_fucking_opengl);
	
	compile_shaders();
	
	for 0 .. Instance_Buffers.Count - 1 {
		r_state.inst_buffers[it] = make_ssbo(MB(8));
	}
	
	white_bmp : Bitmap;
	white_bmp.data = *whitey;
	white_bmp.w = 1;
	white_bmp.h = 1;
	white_bmp.n = 4;
	
	r_state.white_tex = image(white_bmp);
}

cubemap_tex : GLuint64;

render_submit :: (passes : Pass_List) {
	win_size := get_window_size(the_window);
	
	glViewport(0, 0, xx win_size.x, xx win_size.y);
	glClearColor(0.2, 0.2, 0.3, 1.0);
	glEnable(GL_DEPTH_TEST);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	// skybox
	{
		glDepthMask(GL_FALSE);
		shader := r_state.vf_shaders[VF_Shaders.Skybox];
		
		glUseProgram(shader);
		
		proj_loc := glGetUniformLocation(shader, "u_proj");
		view_loc := glGetUniformLocation(shader, "u_view");
		
		view := make_matrix4(make_matrix3(camera.view_matrix));
		
		proj := Matrix4_Identity;
		proj = make_projection_matrix(60 * PI / 180.0, win_size.x / (cast(float) win_size.y), 0.001, 1000);
		
		glUniformMatrix4fv(view_loc, 1, GL_TRUE, *view.coef[0][0]);
		glUniformMatrix4fv(proj_loc, 1, GL_TRUE, *proj.coef[0][0]);
		
		loc := glGetUniformLocation(shader, "u_skybox");
		
		l, r := uvec2_from_u64(cubemap_tex);
		glUniform2ui(loc, l, r);
		
		glDrawArrays(GL_TRIANGLES, 0, 36);
		glDepthMask(GL_TRUE);
	}
	
	// passes
	{
		pass := passes.first;
		while pass {
			defer pass = pass.next;
			
			if pass.kind == {
				
				case .Light; #through;
				case .Quad;
				
				shader := r_state.vf_shaders[VF_Shaders.Quad];
				buffer := r_state.inst_buffers[Instance_Buffers.Quad];
				
				if pass.kind == .Light {
					shader = r_state.vf_shaders[VF_Shaders.Light];
				}
				
				glUseProgram(shader);
				glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, buffer);
				
				proj := Matrix4_Identity;
				proj = make_projection_matrix(60 * PI / 180.0, win_size.x / (cast(float) win_size.y), 0.001, 1000);
				
				proj_loc := glGetUniformLocation(shader, "u_proj");
				view_loc := glGetUniformLocation(shader, "u_view");
				
				glUniformMatrix4fv(view_loc, 1, GL_TRUE, *camera.view_matrix.coef[0][0]);
				glUniformMatrix4fv(proj_loc, 1, GL_TRUE, *proj.coef[0][0]);
				
				batches := pass.batches;
				batch := batches.first;
				while batch	{
					ssbo_data : *u8 = glMapNamedBufferRange(buffer, 0, batch.size, GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
					
					memcpy(ssbo_data, batch.base, batch.size);
					
					glUnmapNamedBuffer(buffer);
					
					glDrawArraysInstanced(GL_TRIANGLES, 0, 6, batch.count);
					
					batch = batch.next;
				}
				
				case .GLTF_Scene;
				
				glEnable(GL_CULL_FACE);
				glCullFace(GL_BACK);
				glFrontFace(GL_CCW);
				
				shader := r_state.vf_shaders[VF_Shaders.Mesh];
				
				glUseProgram(shader);
				
				proj := Matrix4_Identity;
				proj = make_projection_matrix(60 * PI / 180.0, win_size.x / (cast(float) win_size.y), 0.001, 1000);
				
				proj_loc := glGetUniformLocation(shader, "u_proj");
				view_loc := glGetUniformLocation(shader, "u_view");
				model_loc := glGetUniformLocation(shader, "u_model");
				image_loc := glGetUniformLocation(shader, "u_base_tex_id");
				
				glUniformMatrix4fv(view_loc, 1, GL_TRUE, *camera.view_matrix.coef[0][0]);
				glUniformMatrix4fv(proj_loc, 1, GL_TRUE, *proj.coef[0][0]);
				
				// dir light dir
				{
					loc := glGetUniformLocation(shader, "u_dir_light.dir");
					
					v := Vector3.{-0.2, -1, -0.3};
					glUniform3fv(loc, 1, *v.component[0]);
				}
				
				// dir light ambient
				{
					loc := glGetUniformLocation(shader, "u_dir_light.ambient");
					v := Vector3.{0.1, 0.1, 0.1};
					glUniform3fv(loc, 1, *v.component[0]);
				}
				
				// dir light diffuse
				{
					loc := glGetUniformLocation(shader, "u_dir_light.diffuse");
					v := Vector3.{0.5, 0.5, 0.5};
					glUniform3fv(loc, 1, *v.component[0]);
				}
				
				// point light diffuse
				{
					loc := glGetUniformLocation(shader, "u_point_lights[0].diffuse");
					v := Vector3.{0.5, 0.5, 0.5};
					glUniform3fv(loc, 1, *v.component[0]);
				}
				
				// point light pos
				{
					loc := glGetUniformLocation(shader, "u_point_lights[0].pos");
					v := Vector3.{0.91, 1, 1.6};
					glUniform3fv(loc, 1, *v.component[0]);
				}
				
				for 0 .. pass.scene_count - 1 {
					scene := pass.scenes[it];
					
					for 0 .. scene.num_meshes - 1 {
						mesh := scene.meshes + it;
						
						vertex_buffer := mesh.buffer.vertex_buffer;
						index_buffer := mesh.buffer.index_buffer;
						
						glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, vertex_buffer);
						
						model_mat := scene.xform * mesh.transform;
						
						glUniformMatrix4fv(model_loc, 1, GL_TRUE, *model_mat.coef[0][0]);
						glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, index_buffer);
						
						for 0 .. mesh.num_primitives - 1 {
							prim := mesh.primitives + it;
							
							base_tex_id := scene.gpu_textures[prim.base_tex_index].resident;
							
							l, r := uvec2_from_u64(base_tex_id);
							
							glUniform2ui(image_loc, l, r);
							
							glDrawElements(GL_TRIANGLES, prim.count, GL_UNSIGNED_INT, xx (prim.start * size_of(u32)));
						}
					}
				}
				//glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
				glDisable(GL_CULL_FACE);
			}
		}
	}
}