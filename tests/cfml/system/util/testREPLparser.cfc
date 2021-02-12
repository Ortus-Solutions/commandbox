component name="TestREPLParser" extends="mxunit.framework.TestCase" {

	public void function setup() {
		REPLParser = application.wirebox.getInstance( 'REPLParser' );
		REPLParser.startCommand();
	}

	public void function testCommandLines() {
		var commands = [
			'writeOutput("Hello, World");',
			'writeOutput("Goodbye, World");'
		];

		assertTrue( isArray( REPLParser.getCommandLines() ), 'CommandLines is an array' );
		assertEquals( 0, arrayLen( REPLParser.getCommandLines() ), 'CommandLines start empty' );

		REPLParser.addCommandLine( commands[ 1 ] );
		assertEquals( 1, arrayLen( REPLParser.getCommandLines() ), 'Added a command' );
		REPLParser.addCommandLine( commands[ 2 ] );
		assertEquals( 2, arrayLen( REPLParser.getCommandLines() ), 'Added a second command' );
	}

	public void function testGetCommandAsString() {
		var commands = [
			'writeOutput("Hello, World");',
			'writeOutput("Goodbye, World");'
		];
		REPLParser.addCommandLine( commands[ 1 ] );
		REPLParser.addCommandLine( commands[ 2 ] );
		assertEquals( 2, arrayLen( REPLParser.getCommandLines() ), 'Added two CommandLines' );

		assertEquals( arrayToList( commands, chr( 10 ) ), REPLParser.getCommandAsString(), 'Getting command lines as a string is a simple concat' );
	}

	public void function testStripComments() {
		var simpleCommand = 'writeOutput("Hello, World");';
		assertEquals( simpleCommand, REPLParser.stripComments( simpleCommand ), 'Simple commands are exact.' );

		var commandWithComment = 'writeOutput("Hello, World");// Comment';
		assertEquals( simpleCommand, REPLParser.stripComments( commandWithComment ), 'Simple commands with comment is just simple command.' );

		var commandWithURL = 'writeOutput("https://www.google.com");';
		var commandWithURLSingle = 'writeOutput(''https://www.google.com'');';
		assertEquals( commandWithURL, REPLParser.stripComments( commandWithURL ), 'Forward slashes in strings should not be stripped.' );
		assertEquals( commandWithURLSingle, REPLParser.stripComments( commandWithURLSingle ), 'Forward slashes in strings should not be stripped.' );

		var commandWithURLAndComment = 'writeOutput("https://www.google.com");// Comment';
		var commandWithURLSingleAndComment = 'writeOutput(''https://www.google.com'');// Comment';
		assertEquals( commandWithURL, REPLParser.stripComments( commandWithURLAndComment ), 'Forward slashes in strings should not be stripped but comments should.' );
		assertEquals( commandWithURLSingle, REPLParser.stripComments( commandWithURLSingleAndComment ), 'Forward slashes in strings should not be stripped but comments should.' );
	}

}
