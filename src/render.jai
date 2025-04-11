Corner_00 :: 0;
Corner_01 :: 1;
Corner_10 :: 2;
Corner_11 :: 3;
Corner_COUNT :: 4;

Tex_Params :: enum {
	Linear;
	Nearest;
}

// NOTE(mizu):
// U32 : w, h
// U64 : ptr, tex_id

Quad :: struct {
	model : Matrix4;
	color : Vector4;
	src : RectF32;
	tex_id : u64;
	pad : u64;
}

Batch :: struct {
	base : *u8;
	count : u32;
	size : s64;
	cap : s64;
	next : *Batch;
};

Batch_List :: struct {
	first : *Batch;
	last : *Batch;
	count : u32;
};

Pass_Kind :: enum {
	Quad;
	Light;
	GLTF_Scene;
}

Pass :: struct {
	next : *Pass;
	kind : Pass_Kind;
	batches : Batch_List;
	scenes : [4]GLTF_Scene;
	scene_count : int;
	view : Matrix4;
	proj : Matrix4;
}

Pass_List :: struct {
	first : *Pass;
	last : *Pass;
	count : u32;
	
	gen : u64;
	last_gen : u64;
	
	scissor_stack : struct {
		top : *Scissor_Node;
	}
}

Scissor_Node :: struct {
	next : *Scissor_Node;
	v : RectF32;
}

push_scissor :: (list : *Pass_List, v : RectF32) {
	node : *Scissor_Node = xx tpush_struct(Scissor_Node);
	node.v = v;
	node.next = list.scissor_stack.top;
	list.scissor_stack.top = node;
	list.gen += 1;
}

pop_scissor :: (list : *Pass_List) {
	list.scissor_stack.top = list.scissor_stack.top.next;
	list.gen += 1;
}

push_batch :: (list : *Batch_List, cap : s64) -> *Batch {
	out : *Batch = talloc(size_of(Batch));
	<< out = .{};
	
	if !out {
		i := 1;
	};
	
	if !list.first {
		list.last = out;
		list.first = out;
	}
	else {
		list.last.next = out;
		list.last = out;		
	}
	
	out.cap = cap;
	out.base = talloc(size_of(u8) * cap);
	list.count+=1;
	
	return out;
}

null_scissor_node : Scissor_Node = .{
	v = .{.{0, 0}, .{1920, 1051}}
};

push_pass :: (list : *Pass_List, kind : Pass_Kind) -> *Pass{
	out : *Pass = talloc(size_of(Pass));
	<< out = .{};
	out.kind = kind;
	
	if list.last {
		list.last.next = out;
		list.last = out;
	} else {
		list.last = out;
		list.first = out;
		//list.scissor_stack.top = *null_scissor_node;
	}
	
	list.count += 1;
	
	return out;
}

push_quad_impl :: (kind : Pass_Kind, list : *Pass_List, pos : Vector3, rot : Vector3, size : Vector2, color : Vector4, image : Image, src : RectF32 = .{.{0, 0}, .{1, 1}}) {
	pass := list.last;
	
	if !pass || pass.kind != kind || (list.gen != list.last_gen){
		pass = push_pass(list, kind);
		
		// set state params
		//pass.scissor = list.scissor_stack.top.v;
		list.last_gen = list.gen;
	}
	
	batches := *pass.batches;
	batch := batches.last;
	
	if !batch || (batch.cap < batch.size + size_of(Quad)) {
		batch = push_batch(batches, xx MB(1));
	}
	
	out : *Quad = xx (batch.base + batch.size);
	
	mat := Matrix4_Identity;
	
	yaw : Quaternion;
	set_from_axis_and_angle (*yaw, 0, -1, 0, rot.x);
	pitch : Quaternion;
	set_from_axis_and_angle (*pitch, -1, 0, 0, rot.y);
	rotation := yaw * pitch;
	
	mat = translate(mat, pos);
	mat = rotate(mat, rotation);
	mat = scale(mat, .{size.x, size.y, 1});
	
	out.model = mat;
	out.color = color;
	out.tex_id = image.resident;
	out.src = src;
	
	batch.count+=1;
	batch.size += size_of(Quad);
}

push_quad :: (list : *Pass_List, pos : Vector3, rot : Vector3, size : Vector2, color : Vector4, image : Image, src : RectF32 = .{.{0, 0}, .{1, 1}}) {	
	push_quad_impl(.Quad, list, pos, rot, size, color, image, src);
}

push_light :: (list : *Pass_List, pos : Vector3, rot : Vector3, size : Vector2, color : Vector4, image : Image, src : RectF32 = .{.{0, 0}, .{1, 1}}) {	
	push_quad_impl(.Light, list, pos, rot, size, color, image, src);
}

push_gltf_scene :: (list : *Pass_List, scene : GLTF_Scene) {
	pass := list.last;
	
	if !pass || pass.kind != .GLTF_Scene || (list.gen != list.last_gen){
		pass = push_pass(list, .GLTF_Scene);
		
		// set state params
		//pass.scissor = list.scissor_stack.top.v;
		list.last_gen = list.gen;
	}
	
	pass.scenes[pass.scene_count] = scene;
	pass.scene_count += 1;
}