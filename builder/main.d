import defines;

import tango.text.Ascii;
import tango.sys.Process;
import tango.io.FileSystem;
import tango.io.FileScan;
import tango.io.FilePath;
import tango.io.Stdout;
import tango.io.File;
import tango.io.TempFile;
import tango.io.stream.TextFileStream;
import tango.text.Regex;
import tango.text.convert.Integer;
import tango.text.convert.Layout;

FileSystem fs;
char[] root_folder;
char[] aahz_folder;

void buildNetObjects() {
	enum DNOSearch {
		SEARCHING,
		CLASS,
		METHOD
	}
	char[][] garble;
	DNOSearch state = DNOSearch.SEARCHING;
	Regex classStart = new Regex(r"(.+)class\s+(\S+)\s+C\{.*");
	Regex classClient = new Regex("client");
	Regex classServer = new Regex("server");
	Regex classEnd = new Regex(r".*\}C.*");
	
	Regex memberDec = new Regex("(.*);.*");
	Regex memberInitDec = new Regex("(.*)=(.*);.*");

	regex methodStart = new Regex(r".*M\{.*");
	regex methodEnd = new Regex(r".*\}M.*");
	
	NetObject nObj;

	FileScan dno_scan = (new FileScan)(aahz_folder, ".dno");
	foreach (file; dno_scan.files) {
		uint lineCount = 0;
		TextFileInput input = new TextFileInput(file.toString());
	
		foreach(line; input) {
			++lineCount;
			
			switch (state) {
			case DNOSearch.SEARCHING:
				if (classStart.test(line)) {	// A net class declaration
					classStart.search(line);
					if (classClient.test(classStart.match(1))) {
						nObj = new NetObject;
						nObj.classLoc = NetLocation.CLIENT;
					}
					else if (classServer.test(classStart.match(1))) {
						nObj = new NetObject;
						nObj.classLoc = NetLocation.SERVER;
					}
					else {
						throw new Exception("Class location is not specified (" ~ file.toString() ~ ":" ~ Integer.toString(lineCount) ~ ")");
					}
					
					state = DNOSearch.CLASS;
				}
				else {	// Non-net stuff
					garble ~= line ~ "\n";
				}
			break;
			case DNOSearch.CLASS:
				if (memberDec.test(line)) {	// Member
					if (memberInitDec.test(line)) {	// Has = X
						memberInitDec.search(line);
					}
					else {
						memberDec.search(line);
					}
				}
				else if (methodStart.test(line)) {	// Method start
					state = DNOSearch.METHOD;
					
					
				}
				else if (classEnd.test(line)) {	// Class end
					state = DNOSearch.SEARCHING;
				}
			break;
			case DNOSearch.METHOD:
				if (methodEnd.test(line)) {
					state = DNOSearch.CLASS;
				}
				else {	// method body
					nObj.methods[$-1].code ~= line ~ "\n";
				}
			break;
			}
		}

foreach (line; garble) {
	Stdout(line);
}
//		TextFileOutput output = new TextFileOuput(file.path() ~ file.name() ~ ".d");
		
		
	}
}

int main(char[][] args) {
	bool build_debug = false;
	bool build_profile = false;
	bool build_docs = false;
	bool build_clean = false;
	bool build_net = false;

	char[] libs = "libdb45.lib sqlite3.obj enet.lib winmm.lib ws2_32.lib";
	char[] temp = "build.tmp";
	TextFileOutput output;
	
	foreach (char[] arg; args) {
		switch(toLower(arg)) {
			case "-debug":
		 		build_debug 	= true;
			break;
			case "-profile":
			 	build_profile 	= true;
			break;
			case "-ddoc":
			 	build_docs 		= true;
			break;
			case "-clean":
			 	build_clean 	= true;
			break;
			case "-net":
				build_net		= true;
			break;
			default:
			break;
		}
	}
	
	root_folder = fs.getDirectory();
	aahz_folder = root_folder ~ "/aahz";
	
	buildNetObjects();
	if (build_net) return 0;	// All done
	
	output = new TextFileOutput(temp);
	output.write("-ofsageserver.exe -I. ");
	
	FileScan d_scan = (new FileScan)(aahz_folder, ".d");
	foreach (file; d_scan.files) {
		output.write(file.toString() ~ " ");
	}
	
	output.write("main.d " ~ libs);
	output.flush.close;
	
	auto command = "dmd @" ~ temp;
	auto p = new Process(command, null);
	p.execute();
	Stdout.copy(p.stdout).flush;
	auto res = p.wait();
	if (res.reason != Process.Result.Exit) throw new Exception("Build error!");
	
	
	
	return 0;
}
