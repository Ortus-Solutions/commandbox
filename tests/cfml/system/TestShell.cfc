component name="TestShell" extends="mxunit.framework.TestCase" {

	public void function testCommandService()  {
    	var baos = createObject("java","java.io.ByteArrayOutputStream").init();
    	var testString = "ls#chr(10)#";
    	var bain = createObject("java","java.io.ByteArrayInputStream").init(testString.getBytes());
		shell = application.wirebox.getInstance( name='Shell', initArguments={ inStream=bain, outputStream=baos } );
		commandService = application.wirebox.getInstance( 'CommandService' );
		commandService.runCommandline("ls");
		debug(baos.toString());

	}

	public void function testShell()  {
    	var baos = createObject("java","java.io.ByteArrayOutputStream").init();
    	var n = chr(10);
    	var line = "ls" &n& "q" & n;
    	var inStream = createObject("java","java.io.ByteArrayInputStream").init(line.getBytes());
		shell = application.wirebox.getInstance( name='Shell', initArguments={ inStream=inStream, outputStream=baos } ); 	
		shell.run();
		//debug(baos.toString());

	}


	public void function testHTML2ANSI()  {
		formatter = application.wirebox.getInstance( 'formatter' );
		var result = formatter.HTML2ANSI("
		<b>some bold text</b>
		some non-bold text
		<b>some bold text</b>
		");
	}

	public void function testShellComplete()  {
    	var baos = createObject("java","java.io.ByteArrayOutputStream").init();
    	var t = chr(9);
    	var n = chr(10);
    	application.wirebox.clearSingletons();
		shell = application.wirebox.getInstance( name='Shell', initArguments={ outputStream=baos } );

		// TODO: Create a way to force the shell to load command synchronously, or set a flag when its finished.
		// This sleep is just giving the shell time to finish loading all the commands async
		sleep( 2000 );

		shell.run("hel#t#");
		wee = replace(baos.toString(),chr(0027),"","all");
		//request.debug(wee);
		assertTrue(find("help",wee));
		baos.reset();

		shell.run("cfdistro #t#");
		wee = replace(baos.toString(),chr(0027),"","all");
		assertTrue(find("war",wee));
		baos.reset();

		shell.run("cfdistro dep#t#");
		wee = replace(baos.toString(),chr(0027),"","all");
		assertTrue(find("dependency",wee));
		baos.reset();

		shell.run("ls #t#");
		wee = replace(baos.toString(),chr(0027),"","all");
		baos.reset();

		shell.run("ls#t#");
		wee = replace(baos.toString(),chr(0027),"","all");
		baos.reset();

		shell.run("test#t#");
		wee = replace(baos.toString(),chr(0027),"","all");
		baos.reset();

		shell.run("testplug ro#t# #n#");
		wee = replace(baos.toString(),chr(0027),"","all");
		baos.reset();

		shell.run("testplug o#t#");
		wee = replace(baos.toString(),chr(0027),"","all");
		baos.reset();

	}

	public void function testWindowsANSI()  {
		System = createObject("java", "java.lang.System");
		var ansiOut = createObject("java","org.fusesource.jansi.AnsiConsole").out;
        var baos 	= createObject("java","java.io.OutputStreamWriter").init( ansiOut,
        				// default to Cp850 encoding for Windows console output (ROO-439)
        				System.getProperty("jline.WindowsTerminal.output.encoding", "Cp850") );
    	var t = chr(9);
    	var n = chr(10);
    	application.wirebox.clearSingletons();
		shell = application.wirebox.getInstance( name='Shell', initArguments={ outputStream=printWriter } );

		shell.run("hel#t#");
		ansiOut.close();
		wee = replace(ansiOut,chr(0027),"","all");
		debug(wee);

	}

}