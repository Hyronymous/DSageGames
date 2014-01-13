module Default.Default;

import client.Link;
import aahz.widget.WindowManager;
import aahz.widget.Window;
import aahz.widget.Event;
import aahz.widget.Widget;
import aahz.widget.Viewport;
import aahz.widget.Panel;
import aahz.widget.ScrollPanel;
import aahz.widget.Area;
import aahz.draw.Graphics;
import aahz.draw.Image;
import aahz.draw.Font;
import aahz.util.String;

import aahz.render.Camera;
import aahz.render.Shapes;
import aahz.render.Model;
import aahz.render.Light;
import aahz.math.Vector;
import aahz.math.Euler;
import aahz.net.ClientManager;
import aahz.net.NetThread;
import aahz.crypt.RSA;
import tango.util.Convert;
import tango.text.xml.Document;
import tango.io.device.File;
import tango.math.BigInt;

import aahz.widget.Button;
import aahz.widget.TextInput;
import aahz.draw.Label;

import tango.io.Stdout;
import tango.math.Math;
import tango.util.Convert;


import derelict.opengl.gl;
import derelict.opengl.glu;

class GLWidget : Widget {
public:
//	Image img;
	Label l;
	ubyte[4] white;
	ubyte[4] black;

	this() {
		super();
		
		Font f = new Font("Sans-Serif", 30, FontStyle.ITALIC);
		l = new Label(f, new String("Hello there, gargantuan one"));
//		f.setColor(cast(ubyte)0xff, cast(ubyte)0xff, cast(ubyte)0xff);
//		img = f.getText( new String("Hello there") );
		
		white[0] = 0xff;
		white[1] = 0xff;
		white[2] = 0xff;
		white[3] = 0xff;
		black[3] = 0xff;
	}

	void paint() {
		scope Graphics g = new Graphics(m_drawBox);
		Viewport.do2D(m_clipBox);
		
		g.setColor(cast(ubyte)0xff, cast(ubyte)0xff, cast(ubyte)0xff, cast(ubyte)0xff);
		g.fillSquare(0, 0, m_drawBox.width, m_drawBox.height);
		
		g.setColor(cast(ubyte)0xFF, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0xff);
		g.draw(l, 10, 10);
	}
}

class Default : SageApp {
package:
	bool connected = false;
	bool cancelConnect = false;
	bool cancelJoin = false;
	
	class TButton : Button {
		void delegate() dg;
		
		this(String title, void delegate() doStuff) {
			super(title);
			dg = doStuff;
		}
		
		void onClick() {
//			NetThread t = new NetThread( dg );
//			t.start();
		}
	}
	
	TButton btn, btn2;
	TextInput ti;
	GLWidget gl;

	void doConnect() {
		try {
			ClientManager.connect(cancelConnect);
			connected = true;
			synchronized (Stdout) Stdout("Connected\n").flush;
		}
		catch (Exception e) {
			synchronized (Stdout) Stdout.format("ERROR: {}\n", e.toString()).flush;
		}
	}

	void doChannel() {
		try {
			ClientManager.joinChannel(cancelJoin, "NetChannel", "test", "testpass");
			synchronized (Stdout) Stdout("Joined\n").flush;
		}
		catch (Exception e) {
			synchronized (Stdout) Stdout.format("ERROR: {}\n", e.toString()).flush;
		}
	}

public:
	static SageApp create() {
		return new Default();
	}

	static this() {
		appCreator[ "Default" ] = &create;
	}
	
	void init() {
		gl = new GLWidget();
		gl.situate("left:0", "bottom:0", "100%", "100%");
		WindowManager.add(0, gl);
		
//		ClientManager.setLoginInfo("chris", "nopassword");
//
//		btn = new TButton( new String("Connect"), &doConnect );
//		btn.situate("center:0", "center:0", "250", "1");
//		WindowManager.add(0, btn);
//
//		btn2 = new TButton( new String("Join Channel"), &doChannel );
//		btn2.situate("center:0", "center:-50", "250", "1");
//		WindowManager.add(0, btn2);
//
//		ti = new TextInput();
//		ti.situate("center:0", "center:-100", "250", "1");
//		WindowManager.add(0, ti);
	}
	
	void cleanup() {
		WindowManager.remove(gl);
//		WindowManager.remove(btn);
//		WindowManager.remove(btn2);
//		WindowManager.remove(ti);
//		ClientManager.stop();
	}
}
