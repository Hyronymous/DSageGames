import tango.core.Exception;
import tango.io.FileSystem;
import tango.io.FileScan;
import tango.io.FilePath;
import tango.io.Stdout;
import tango.io.device.File;
import tango.io.device.TempFile;
import tango.io.stream.TextFile;
import tango.sys.Process;
import tango.text.Ascii;
import tango.text.xml.Document;

version (Windows) {
	const char[] EXE_EXT = ".exe";
	const char[] LIB_EXT = ".lib";
	const char[] OBJ_EXT = ".obj";
	const char[] DEF_EXT = ".def";
}
else version (linux) {
	const char[] EXE_EXT = "";
	const char[] LIB_EXT = ".a";
	const char[] OBJ_EXT = ".o";
	const char[] DEF_EXT = ".def";
}
else {
	static assert(0);
}

char[] getAttribute(Document!(char).Node node, char[] name) {
	foreach (attr; node.attributes) if (attr.name == name) return attr.value;
	return "";
}

int main(char[][] args) {
	char[] settingsFilePath;
	char[] extraArgs;
	char[] outName;
	char[] outType;
	char[] defName = "";
	char[] libs;
	char[][] folders;
	
	for (uint L = 1; L < args.length; L++) {	// skip first arg
		if (args[L][0] == '-') {
			extraArgs ~= args[L] ~ " ";
		}
		else if (settingsFilePath.length == 0) {	// Can only be one, so this should be unset
			settingsFilePath = args[L].dup;
		}
		else {	// Invalid parameter
			Stdout("Usage: builder [dmd args] <build XML file>\n");
			return 1;
		}
	}
	
	scope char[] fileData = cast(char[])File.get(settingsFilePath);
	scope auto fileXML = new Document!(char);
	fileXML.parse(fileData);
	
	foreach (n; fileXML.tree.children) switch (n.name) {
	case "project":
		foreach (attr; n.attributes) switch (attr.name) {
		case "out":
			outName = attr.value.dup;
		break;
		case "type":
			outType = attr.value.dup;
		break;
		case "def":
			defName = attr.value.dup;
		break;
		default: break;
		}
		
		foreach (n2; n.children) switch (n2.name) {
		case "libs":
			foreach (n3; n2.children) switch (n3.name) {
			case "lib":
				libs ~= getAttribute(n3, "path").dup ~ " ";
			break;
			default: break;
			}
		break;
		case "folders":
			foreach (n3; n2.children) switch (n3.name) {
			case "folder":
				folders.length = folders.length + 1;
				folders[$ - 1] = getAttribute(n3, "path").dup;
			break;
			default: break;
			}
		break;
		default: break;
		}
	break;
	default: break;
	}
	
	if (
		folders.length == 0
		|| outName.length == 0
		|| outType.length == 0
		|| (
			outType != "exe"
			&& outType != "lib"
		)
	) {
		Stdout("Invalid build file.\n");
		return 1;
	}
	
	char[] temp = "build.tmp";
	TextFileOutput output = new TextFileOutput(temp);
	if (outType == "exe") {
		output.write("-of" ~ outName ~ EXE_EXT ~ " ");
	}
	else {	// lib
		output.write("-of" ~ outName ~ LIB_EXT ~ " -lib ");
	}
	output.write(defName ~ " ");
	output.write(extraArgs);
	
	foreach (folder; folders) {
		FileScan d_scan = (new FileScan)(folder, ".d");
		foreach (file; d_scan.files) {
			output.write(file.toString() ~ " ");
		}
	}
	
	output.write(libs);
	output.flush.close;
	
	try {
		auto command = "dmd @" ~ temp;
		auto p = new Process(command, null);
		p.execute();
		p.setRedirect(Redirect.OutputToError);
		Stdout.copy(p.stderr).flush;
		auto res = p.wait();
		
		if (res.reason != Process.Result.Exit) throw new Exception("Build error!");
		auto objFile = new FilePath(outName ~ OBJ_EXT);
		objFile.remove();
	}
	catch (ProcessException e) {
		Stdout.formatln ("Process execution failed: {}", e);
	}
	
//	auto tempFile = new FilePath(temp);
//	tempFile.remove();
	
	return 0;
}
