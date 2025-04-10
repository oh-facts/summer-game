#import "Compiler";
#import "File";

build :: () {
	
	options := get_build_options();
	args := options.compile_time_command_line;
	
	for args {
		if it == {
			case "clean";
			delete_directory(".build/");
		}
	}
	
	w := compiler_create_workspace("winter");
	target_options := get_build_options(w);
	target_options.output_executable_name = "winter";
	target_options.output_path = ".build/";
	target_options.backend = .X64;
	set_build_options(target_options, w);
	
	add_build_file("src/main.jai", w);
	
	set_build_options_dc(.{do_output=false});
}

#run build();