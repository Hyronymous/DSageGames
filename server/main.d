import tango.io.Stdout;
import tango.util.Convert;
import tango.text.xml.Document;
import tango.io.device.File;
import tango.math.BigInt;

import aahz.net.ServerManager;
import aahz.crypt.RSA;

void startup() {
	
}

void shutdown() {
	
}

bool connect(char[] username, char[] password) {
	return true;
}

void disconnect() {
	
}

int main(char[][] args) {
	uint uid;
	char[] ip;
	ushort port;
	
	if (args.length < 2) {
		Stdout("Usage: sageserver <settings file>\n");
		return 1;
	}
	ServerManager.init();
	
	try {
		char[] getAttribute(Document!(char).Node node, char[] name) {
			foreach (attr; node.attributes) if (attr.name == name) return attr.value;
			return "";
		}
		
		char[] fileData = cast(char[])File.get(args[1]);
		auto fileXML = new Document!(char);
		fileXML.parse(fileData);
		
		foreach (n; fileXML.tree.children) switch (n.name) {
		case "server":
			foreach (attr; n.attributes) switch (attr.name) {
			case "uid":
				uid = to!(uint)(attr.value);
			break;
			case "ip":
				ip = attr.value.dup;
			break;
			case "port":
				port = to!(ushort)(attr.value);
			break;
			case "folder":
				ServerManager.setCacheFolder( attr.value );
			break;
			default: break;
			}
			
			foreach (n2; n.children) switch (n2.name) {
			case "rsa":
				ServerManager.setRSA(
					RSAPublicKey(
						BigInt( getAttribute(n2, "n") ),
						BigInt( getAttribute(n2, "e") )
					),
					RSAPrivateKey(
						BigInt( getAttribute(n2, "n") ),
						BigInt( getAttribute(n2, "d") ),
						BigInt( getAttribute(n2, "p") ),
						BigInt( getAttribute(n2, "q") )
					)
				);
			break;
			case "peer":
				ServerManager.registerServer(
					to!(uint)(getAttribute(n2, "uid")),
					getAttribute(n2, "ip"),
					to!(ushort)(getAttribute(n2, "port"))
				);
			break;
			default: break;
			}
		break;
		default: break;
		}
	}
	catch (Exception e) {
		Stdout("Error reading settings file");
		return 1;
	}
	
	ServerManager.setCallbacks( &startup, &shutdown, &connect, &disconnect );
	ServerManager.run(uid, ip, port, 4);

	return 0;
}
