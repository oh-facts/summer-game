VF_Shaders :: enum {
	Quad;
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

vf_shader_paths :[VF_Shaders.Count]string: .["triangle"];

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

RectF32 :: struct {
	min : Vector2;
	max : Vector2;
};

Quad :: struct {
	model : Matrix4;
	color : Vector4;
	src : RectF32;
	tex_id : u64;
	pad : u64;
}

quads : struct {
	data : [1024]Quad;
	count : int;
}

push_quad :: (pos : Vector3, rot : Vector3, size : Vector2, color : Vector4, image : Image, src : RectF32 = .{.{0, 0}, .{1, 1}}) {
	quad := quads.data.data + quads.count;
	
	mat := Matrix4_Identity;
	
	yaw : Quaternion;
	set_from_axis_and_angle (*yaw, 0, -1, 0, rot.x);
	pitch : Quaternion;
	set_from_axis_and_angle (*pitch, -1, 0, 0, rot.y);
	rotation := yaw * pitch;
	
	mat = translate(mat, pos);
	mat = rotate(mat, rotation);
	mat = scale(mat, .{size.x, size.y, 1});
	
	quad.model = mat;
	quad.color = color;
	quad.tex_id = image.resident;
	quad.src = src;
	quads.count += 1;
}

render_submit :: () {
	win_size := get_window_size(the_window);
	
	glViewport(0, 0, xx win_size.x, xx win_size.y);
	glClearColor(0.2, 0.2, 0.3, 1.0);
	glEnable(GL_DEPTH_TEST);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	shader := r_state.vf_shaders[VF_Shaders.Quad];
	buffer := r_state.inst_buffers[Instance_Buffers.Quad];
	
	glUseProgram(shader);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, buffer);
	
	ssbo_data : *u8 = glMapNamedBufferRange(buffer, 0, size_of(Quad) * quads.count, GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
	
	memcpy(ssbo_data, quads.data.data, size_of(Quad) * quads.count);
	
	glUnmapNamedBuffer(buffer);
	
	proj := Matrix4_Identity;
	proj = make_projection_matrix(45 * PI / 180.0, win_size.x / (cast(float) win_size.y), 0.001, 1000);
	
	proj_loc := glGetUniformLocation(shader, "u_proj");
	view_loc := glGetUniformLocation(shader, "u_view");
	
	glUniformMatrix4fv(view_loc, 1, GL_TRUE, *camera.view_matrix.coef[0][0]);
	glUniformMatrix4fv(proj_loc, 1, GL_TRUE, *proj.coef[0][0]);
	
	glDrawArraysInstanced(GL_TRIANGLES, 0, 6, xx quads.count);
	quads.count = 0;
}