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
#load "camera.jai";
#load "render_opengl.jai";

COLOR_WHITE :: Vector4.{1, 1, 1, 1};
COLOR_BLACK :: Vector4.{0, 0, 0, 1};

COLOR_RED :: Vector4.{1, 0, 0, 1};
COLOR_GREEN :: Vector4.{0, 1, 0, 1};
COLOR_BLUE :: Vector4.{0, 0, 1, 1};
COLOR_YELLOW :: Vector4.{1, 1, 0, 1};
COLOR_CYAN :: Vector4.{0, 1, 1, 1};
COLOR_MAGENTA :: Vector4.{1, 0, 1, 1};

COLOR_ORANGE :: Vector4.{0.79, 0.33, 0, 1};

KB :: (v : u64) -> u64 #expand {
	return v * 1024;
}

MB :: (v : u64) -> u64 #expand {
	return KB(v) * 1024;
}

GB :: (v : u64) -> u64 #expand {
	return MB(v) * 1024;
}

TB :: (v : u64) -> u64 #expand {
	return GB(v) * 1024;
}

counter : float;
//counter += delta;

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
	
	the_window = create_window(960, 540, "Window Creation");
	
	exe_folder = path_strip_filename(get_path_of_running_executable());
	art_folder = join(exe_folder, "../art");
	
	render_init();
	
	bmp_tex, grass_tex, tree_tex : Image;
	
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
		
		if is_key_pressed(.TAB) {
			g_control_camera = !g_control_camera;
			cursor_hidden = !cursor_hidden;
			toggle_cursor(xx cursor_hidden);
		}
		
		update_flying_camera(*camera, delta);
		
		// tree
		{
			for x : -5 .. 5 {
				for y : -5 .. 5 {
					
					pos := Vector3.{0, 0.5, 0};
					pos.x += x;
					pos.z += y;
					
					push_quad(pos, .{}, .{1, 1}, COLOR_WHITE, tree_tex);
					push_quad(pos, .{90 * PI/180, 0, 0}, .{1, 1}, COLOR_WHITE, tree_tex);
				}
			}
		}
		
		// house 
		{
			// walls 1
			push_quad(.{0.5, 0.5, 0.5}, .{90 * PI/180, 0, 0}, .{1, 1}, COLOR_RED, r_state.white_tex);
			push_quad(.{-0.5, 0.5, 0.5}, .{90 * PI/180, 0, 0}, .{1, 1}, COLOR_BLUE, r_state.white_tex);
			
			// walls 2
			push_quad(.{0, 0.5, 0}, .{}, .{1, 1}, COLOR_ORANGE, r_state.white_tex);
			push_quad(.{0, 0.5, 1}, .{}, .{1, 1}, COLOR_MAGENTA, r_state.white_tex);
		}
		
		// terrain
		{
			push_quad(.{0, 0, 0}, .{0, 90 * PI/180, 0}, .{10, 10}, .{1, 1, 1, 1}, grass_tex, .{.{0, 0}, .{10, 10}});
		}
		
		render_submit();
		dc := GetDC(the_window);
		SwapBuffers(dc);
		
		end := get_perf_counter();
		time_elapsed = (end - start) / (freq * 1.);
		delta = time_elapsed - time_since_last;
	}
	
	print("quit safely\n");
}

Bitmap :: struct {
	data : *void;
	w : s32;
	h : s32;
	n : s32;
}

bitmap_dim :: (data : string) -> s32, s32 {
	comp : s32;
	
	x, y : s32;
	stbi_info_from_memory(data.data, xx data.count, *x, *y, *comp);
	
	return x, y;
}

bitmap :: (data : string) -> Bitmap {
	out : Bitmap;
	//stbi_set_flip_vertically_on_load(1);
	
	w, h, n : s32;
	
	bytes := stbi_load_from_memory(data.data, xx data.count, *w, *h, *n, 4);
	
	out.w = w;
	out.h = h;
	out.n = 4;
	out.data = bytes;
	
	return out;
}

bitmap_free :: (bmp : *Bitmap) {
	stbi_image_free(bmp.data);
}

Tex_Params :: enum {
	Linear;
	Nearest;
}

get_perf_counter :: () -> s64 {
	counter : s64;
	QueryPerformanceCounter(*counter);
	return counter;
}

get_perf_freq :: () -> s64 {
	frequency : s64;
	QueryPerformanceFrequency(*frequency);
	return frequency;
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

/*
		// model
		{
			euler : Vector2;
			euler.x = counter;
			//euler.y = counter;
			yaw : Quaternion;
			set_from_axis_and_angle (*yaw, 0, -1, 0, euler.x);
			pitch : Quaternion;
			set_from_axis_and_angle (*pitch, -1, 0, 0, euler.y);
			rotation := yaw * pitch;
			
			model = rotate(model, rotation);
		}
		*/
