component name="TestPrint" extends="mxunit.framework.TestCase" {

	public void function testPrint()  {
		print = application.wirebox.getInstance( 'Print' );
		cr = print.cr;

		// Basic text output
		assertTrue( print.text( '' ) == '[0m' );
		assertTrue( print.Line( '' ) == '[0m' & cr );
		assertTrue( print.text() == '[0m' );
		assertTrue( print.Line() == '[0m' & cr );
		assertTrue( print.text( 'Test' ) == 'Test[0m' );
		assertTrue( print.line( 'Test' ) == 'Test[0m' & cr );

		// Text decoration
		assertTrue( print.boldText( 'Test' ) == '[1mTest[0m' );
		assertTrue( print.underscoredText( 'Test' ) == '[4mTest[0m' );
		assertTrue( print.blinkingText( 'Test' ) == '[5mTest[0m' );
		assertTrue( print.reversedText( 'Test' ) == '[7mTest[0m' );
		assertTrue( print.concealedText( 'Test' ) == '[8mTest[0m' );

		// Text colors
		assertTrue( print.blackText( 'Test' ) == '[30mTest[0m' );
		assertTrue( print.redText( 'Test' ) == '[31mTest[0m' );
		assertTrue( print.greenText( 'Test' ) == '[32mTest[0m' );
		assertTrue( print.yellowText( 'Test' ) == '[33mTest[0m' );
		assertTrue( print.blueText( 'Test' ) == '[34mTest[0m' );
		assertTrue( print.magentaText( 'Test' ) == '[35mTest[0m' );
		assertTrue( print.cyanText( 'Test' ) == '[36mTest[0m' );
		assertTrue( print.whiteText( 'Test' ) == '[37mTest[0m' );

		// Background colors
		assertTrue( print.textOnBlack( 'Test' ) == '[40mTest[0m' );
		assertTrue( print.textOnRed( 'Test' ) == '[41mTest[0m' );
		assertTrue( print.textOnGreen( 'Test' ) == '[42mTest[0m' );
		assertTrue( print.textOnYellow( 'Test' ) == '[43mTest[0m' );
		assertTrue( print.textOnBlue( 'Test' ) == '[44mTest[0m' );
		assertTrue( print.textOnMagenta( 'Test' ) == '[45mTest[0m' );
		assertTrue( print.textOnCyan( 'Test' ) == '[46mTest[0m' );
		assertTrue( print.textOnWhite( 'Test' ) == '[47mTest[0m' );

		// Combinatinos
		assertTrue( print.redOnWhiteText( 'Test' ) == '[31m[47mTest[0m' );
		assertTrue( print.redOnWhiteLine( 'Test' ) == '[31m[47mTest[0m' & cr );

		// Get funky! ("Background" is just extranious text that will be ignored)
		assertTrue( print.boldBlinkingUnderscoredBlueTextOnRedBackground( 'Test' ) == '[1m[5m[4m[34m[41mTest[0m' );
		// "green" is the only thing used in this one
		assertTrue( print.dumpUglygreenCrapToStreen( 'Test' ) == '[32mTest[0m' );

	}

}