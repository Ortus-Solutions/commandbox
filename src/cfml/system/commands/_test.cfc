/**
* This is a test component to showcase all the cool stuff you can 
* do while printing out text to an ANSI console.  It doesn't really serve
* any other purpose than to make your screen look like a rainbow puked on it.
**/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=true {


	function run(  )  {
		
		
		print.line();
		
		var key = waitForKey( 'Press any key to continue' );
		print.line( "You pressed ASCII code #key#" );
		
		print.line();
		
		// Basic text output
		print.text( 'line : ' ).line( 'CommandBox Rox off your sox!' );
		
		print.line();
		
		// Line decoration
		print.text( 'bold : ' ).boldLine( 'CommandBox Rox off your sox!' );
		print.text( 'underscored : ' ).underscoredLine( 'CommandBox Rox off your sox!' );
		print.text( 'blinking : ' ).blinkingLine( 'CommandBox Rox off your sox!' );
		print.text( 'reversed : ' ).reversedLine( 'CommandBox Rox off your sox!' );
		print.text( 'concealed : ' ).concealedLine( 'CommandBox Rox off your sox!' );
		
		print.line();
		
		// Line colors
		print.text( 'blackOnWhite : ' ).blackOnWhiteLine( 'CommandBox Rox off your sox!' );
		print.text( 'red : ' ).redLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'green : ' ).greenLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'yellow : ' ).yellowLine( 'CommandBox Rox off your sox!' );
		print.text( 'blue : ' ).blueLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'magenta : ' ).magentaLine( 'CommandBox Rox off your sox!' );
		print.text( 'cyan : ' ).cyanLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'white : ' ).whiteLine( 'CommandBox Rox off your sox!' ) ;
		
		print.line();
		
		// Background colors
		print.text( 'OnBlack : ' ).textOnBlackLine( 'CommandBox Rox off your sox!' );
		print.text( 'OnRed : ' ).textOnRedLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'OnGreen : ' ).textOnGreenLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'OnYellow : ' ).textOnYelloLine( 'CommandBox Rox off your sox!' );
		print.text( 'OnBlue : ' ).textOnBlueLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'OnMagenta : ' ).textOnMagentaLine( 'CommandBox Rox off your sox!' );
		print.text( 'OnCyan : ' ).textOnCyanLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'BlackOnWhite : ' ).BlackTextOnWhiteLine( 'CommandBox Rox off your sox!' );
		
		print.line();
		// Combinations
		print.text( 'redOnWhite : ' ).redOnWhiteLine( 'CommandBox Rox off your sox!' );
		print.text( 'blueOnGreen : ' ).blueOnGreenLine( 'CommandBox Rox off your sox!' );
		print.text( 'blueOnRed : ' ).blueOnRedLine( 'CommandBox Rox off your sox!' );
		print.text( 'redOnCyan : ' ).redOnCyanLine( 'CommandBox Rox off your sox!' );
		
		print.line();
		
		// Get funky! ("Background" is just extranious text that will be ignored)
		print.text( 'boldBlinkingUnderscoredBlueLineOnRedBackground : ' ).boldBlinkingUnderscoredBlueLineOnRedBackground( 'CommandBox Rox off your sox!' );
		
		print.line();
		
		// "green" is the only thing used in this one
		print.text( 'dumpUglygreenCrapToStreen : ' ).dumpUglygreenCrapToStreenLine( 'CommandBox Rox off your sox!' );
		
	}


}