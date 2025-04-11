#import "Basic";
#import "System";
#import "String";
#import "Math";
#import "File";
#import "File_Utilities";
#import "IntroSort";
#import "Random";
#import "Thread";
#import "Compiler";
#import "stb_image";
#import "Window_Creation";
#import "Input";
#import "Windows";
#import "Math";
#import "GL" (ENABLE_ALL_EXTENSIONS = true);
#import "jai_cgltf";

#load "camera.jai";
#load "render_opengl.jai";
#load "base.jai";
#load "os_win32.jai";
#load "mesh.jai";
#load "render.jai";

counter : float;

the_window: Window_Type;

exe_folder : string;
art_folder : string;

get_window_size :: (win : Window_Type) -> Vector2 {
	out : Vector2;
	rect, rect2 : RECT;
	GetClientRect(win, *rect);
	out.x = xx (rect.right - rect.left);
	out.y = xx (rect.bottom - rect.top);
	
	return out;
}

main :: () {
	print("Do not enter is written on the doorway, why can't everyone just go away\n");
	print("Except for you, you can stay\n");
	
	SetProcessDPIAware();
	
	the_window = create_window(960, 540, "The Sad Debugger");
	
	exe_folder = path_strip_filename(get_path_of_running_executable());
	art_folder = join(exe_folder, "../art");
	
	render_init();
	
	// load 3d model
	arena := arena_init();
	forest, thing, sponza: GLTF_Scene;
	{
		//filename := tprint("%/%", art_folder, "duck/model.gltf ");
		//filename := tprint("%/%", art_folder, "sponza/Sponza.gltf ");
		
		filename := tprint("%/%", art_folder, "aos/model2.gltf");
		thing = gltf_loadMesh(arena, filename);
		gltf_upload(arena, *thing);
	}
	
	{
		filename := tprint("%/%", art_folder, "forest/model.gltf");
		forest = gltf_loadMesh(arena, filename);
		gltf_upload(arena, *forest);
	}
	
	if 0 {
		filename := tprint("%/%", art_folder, "sponza/Sponza.gltf");
		sponza = gltf_loadMesh(arena, filename);
		gltf_upload(arena, *sponza);
	}
	
	{
		filename := tprint("%/%", art_folder, "psy_man.png");
		data := read_entire_file(filename);
		bmp := bitmap(data);
		bmp_tex = image(bmp);
	}
	
	{
		filename := tprint("%/%", art_folder, "grass.png");
		data := read_entire_file(filename);
		bmp := bitmap(data);
		grass_tex = image(bmp, .Linear);
	}
	
	{
		filename := tprint("%/%", art_folder, "tree.png");
		data := read_entire_file(filename);
		bmp := bitmap(data);
		tree_tex = image(bmp);
	}
	
	delta : float;
	time_elapsed : float;
	
	start := get_perf_counter();
	freq := get_perf_freq();
	
	toggle_cursor(xx 0);
	
	quit := false;
	while !quit {
		counter += delta;
		
		time_since_last := time_elapsed;
		
		update_window_events();
		
		for events_this_frame {
			if it.type == .QUIT then quit = true;
			
			if it.type == .KEYBOARD {
				if it.key_pressed == 0 continue;
				
				if it.key_code == .ESCAPE {
					quit = true;
				}
			}
		}
		
		if g_control_camera {
			x, y, w, h := get_dimensions (the_window, false);
			user32 :: #system_library "User32";
			SetCursorPos :: (x : s32, y : s32) -> s32 #foreign user32;
			SetCursorPos (w / 2, h / 2);
		}
		
		if is_key_pressed(.TAB) {
			g_control_camera = !g_control_camera;
			cursor_hidden = !cursor_hidden;
			toggle_cursor(xx cursor_hidden);
		}
		
		update_flying_camera(*camera, delta);
		
		passes : Pass_List;
		
		{
			draw_tree(*passes, .{1.6, 0.65, -1});
		}
		
		{
			{
				model := Matrix4_Identity;
				
				euler : Vector2;
				euler.x = counter;
				//euler.y = counter;
				yaw : Quaternion;
				set_from_axis_and_angle (*yaw, 0, -1, 0, euler.x);
				pitch : Quaternion;
				set_from_axis_and_angle (*pitch, -1, 0, 0, euler.y);
				rotation := yaw * pitch;
				
				model = translate(model, .{1.05, 0.12, -0.75});
				model = rotate(model, rotation);
				model = scale(model, .{0.08, 0.08, 0.08});
				thing.xform = model;
			}
			
			push_gltf_scene(*passes, thing);
			
			
			{
				forest.xform = scale(Matrix4_Identity, .{0.5, 0.5, 0.5});
				push_gltf_scene(*passes, forest);
			}
			//push_gltf_scene(*passes, sponza);
		}
		
		render_submit(passes);
		dc := GetDC(the_window);
		SwapBuffers(dc);
		
		end := get_perf_counter();
		time_elapsed = (end - start) / (freq * 1.);
		delta = time_elapsed - time_since_last;
		
		reset_temporary_storage();
	}
	
	print("quit safely\n");
}

mouse_delta : Vector2;
position : Vector3 = .{0, 0, -1};
rotation_input : Vector2;
euler_angles : Vector3;

is_key_down :: inline (key : Key_Code) -> bool #must {
	return (input_button_states[cast (s64) key] & .DOWN) != 0;
}

is_key_pressed :: inline (key : Key_Code) -> bool #must {
	return (input_button_states[cast (s64) key] & .START) != 0;
}

cursor_hidden : bool;

toggle_cursor :: (show : s32) {
	count := ShowCursor(show);
	if show {
		while (count < 0) count = ShowCursor(1);
	} else {
		while (count >= 0) count = ShowCursor(0);
	}
} 

bmp_tex, grass_tex, tree_tex : Image;

draw_tree :: (passes : *Pass_List, pos : Vector3) {
	push_quad(passes, pos, .{}, .{1, 1}, COLOR_WHITE, tree_tex);
	push_quad(passes, pos, .{90 * PI/180, 0, 0}, .{1, 1}, COLOR_WHITE, tree_tex);
}
