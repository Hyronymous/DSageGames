module client.main;

import client.Link;

import aahz.widget.Viewport;
import aahz.widget.Skin;
import aahz.widget.WindowManager;
import aahz.widget.Cursor;
import aahz.draw.Image;
import aahz.draw.Font;

import tango.io.Stdout;
import tango.core.Memory;

import derelict.sdl.sdl;

int main() {
	SageApp currApp;
	
	// init
	Viewport.init("Sage Games", 640, 480);
	scope(exit) Viewport.cleanup();

	Cursor.init();
	scope(exit) Cursor.cleanup();

	Image.init();
	scope(exit) Image.cleanup();

	Skin.init("./skins/");
	scope(exit) Skin.cleanup();

	Font.init("./fonts/");
	scope(exit) Font.cleanup();

	Font.registerFont("FreeMono.ttf", "Mono", FontStyle.NORMAL);	// Default mono font
	Font.registerFont("FreeMonoBold.ttf", "Mono", FontStyle.BOLD);
	Font.registerFont("FreeMonoBoldOblique.ttf", "Mono", FontStyle.BOLD | FontStyle.ITALIC);
	Font.registerFont("FreeMonoOblique.ttf", "Mono", FontStyle.NORMAL | FontStyle.ITALIC);
	
	Font.registerFont("FreeSans.ttf", "Sans-Serif", FontStyle.NORMAL);	// Default sans-serif font
	Font.registerFont("FreeSansBold.ttf", "Sans-Serif", FontStyle.BOLD);
	Font.registerFont("FreeSansBoldOblique.ttf", "Sans-Serif", FontStyle.BOLD | FontStyle.ITALIC);
	Font.registerFont("FreeSansOblique.ttf", "Sans-Serif", FontStyle.NORMAL | FontStyle.ITALIC);

	Font.registerFont("FreeSerif.ttf", "Serif", FontStyle.NORMAL);	// Default serif font
	Font.registerFont("FreeSerifBold.ttf", "Serif", FontStyle.BOLD);
	Font.registerFont("FreeSerifBoldItalic.ttf", "Serif", FontStyle.BOLD | FontStyle.ITALIC);
	Font.registerFont("FreeSerifItalic.ttf", "Serif", FontStyle.NORMAL | FontStyle.ITALIC);

	Font.registerFont("Alilsenevol_-_Mariana_Slabserif.ttf", "Mariana Slabserif", FontStyle.NORMAL);
	Font.registerFont("JuraBook.ttf", "Jura", FontStyle.NORMAL);
	Font.registerFont("JuraDemiBold.ttf", "Jura", FontStyle.BOLD);
	Font.registerFont("JuraLight.ttf", "Jura", FontStyle.LIGHT);
	Font.registerFont("PhaistosDisk_-_Layne_Thicket.ttf", "Layne Thicket", FontStyle.NORMAL);
	Font.registerFont("tommyjh02_-_Holloway.ttf", "Holloway", FontStyle.NORMAL);
	Font.registerFont("Biffe_-_Holitter_Gothic.ttf", "Holitter Gothic", FontStyle.NORMAL);
	Font.registerFont("Biffe_-_Biffe_s_Calligraphy.ttf", "Biffe's Calligraphy", FontStyle.NORMAL);
	Font.registerFont("Miama.otf", "Miama", FontStyle.NORMAL);
	Font.registerFont("DaveDS_-_Sketchy.ttf", "Sketchy", FontStyle.NORMAL);
	Font.registerFont("SaleGajic_-_Black_Chancery_Serbian.ttf", "Black Chancery Serbian", FontStyle.NORMAL);
	Font.registerFont("5inq_-_Handserif.ttf", "Handserif", FontStyle.NORMAL);
	Font.registerFont("CRASS_ROOTS.ttf", "CRASS ROOTS", FontStyle.NORMAL);
	Font.registerFont("kawoszeh.ttf", "Kawoszeh", FontStyle.NORMAL);
	Font.registerFont("Gputeks-Bold.ttf", "Gputeks", FontStyle.BOLD);
	Font.registerFont("Gputeks-Regular.ttf", "Gputeks", FontStyle.NORMAL);
	Font.registerFont("szlichta07.ttf", "Szlichta07", FontStyle.NORMAL);
	Font.registerFont("Promocyja096.ttf", "Promocyja", FontStyle.NORMAL);
	Font.registerFont("Certege.ttf", "Certege", FontStyle.NORMAL);
	Font.registerFont("benweiner_-_Acknowledgement.otf", "Acknowledgement", FontStyle.NORMAL);
	Font.registerFont("dmiceman_-_DMScript.ttf", "DMScript", FontStyle.NORMAL);
	Font.registerFont("konstytucyja_091.ttf", "Konstytucyja", FontStyle.NORMAL);
	Font.registerFont("mmori.otf", "Momento Mori", FontStyle.NORMAL);
	Font.registerFont("mmori_o.otf", "Momento Mori", FontStyle.ITALIC);
	
	WindowManager.init();
	scope(exit) WindowManager.cleanup();
	WindowManager.loadSkin("Default");
	
	currApp = SageApp.appCreator[ "Default" ]();
	currApp.init();
	
	bool keepGoing = true;
	while (keepGoing) {
		keepGoing = WindowManager.doEvents();
		
		graphicsMutex.lock();
		WindowManager.paint();
		graphicsMutex.unlock();
	}

	currApp.cleanup();
	delete currApp;
	GC.collect();

	return 0;
}
