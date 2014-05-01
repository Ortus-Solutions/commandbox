/**
* This is a test component to showcase all the cool stuff you can 
* do while printing out text to an ANSI console.  It doesn't really serve
* any other purpose than to make your screen look like a rainbow puked on it.
**/
component persistent="false" extends="cli.BaseCommand" aliases="" excludeFromHelp=true {


	function run(  )  {
		
		
		// Basic text output
		print.text( 'line : ' ); print.line( 'CommandBox Rox off your sox!' );
		
		// Line decoration
		print.text( 'bold : ' ); print.boldLine( 'CommandBox Rox off your sox!' );
		print.text( 'underscored : ' ); print.underscoredLine( 'CommandBox Rox off your sox!' );
		print.text( 'blinking : ' ); print.blinkingLine( 'CommandBox Rox off your sox!' );
		print.text( 'reversed : ' ); print.reversedLine( 'CommandBox Rox off your sox!' );
		print.text( 'concealed : ' ); print.concealedLine( 'CommandBox Rox off your sox!' );
		
		// Line colors
		print.text( 'blackOnWhite : ' ); print.blackOnWhiteLine( 'CommandBox Rox off your sox!' );
		print.text( 'red : ' ); print.redLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'green : ' ); print.greenLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'yellow : ' ); print.yellowLine( 'CommandBox Rox off your sox!' );
		print.text( 'blue : ' ); print.blueLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'magenta : ' ); print.magentaLine( 'CommandBox Rox off your sox!' );
		print.text( 'cyan : ' ); print.cyanLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'white : ' ); print.whiteLine( 'CommandBox Rox off your sox!' ) ;
		
		// Background colors
		print.text( 'OnBlack : ' ); print.textOnBlackLine( 'CommandBox Rox off your sox!' );
		print.text( 'OnRed : ' ); print.textOnRedLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'OnGreen : ' ); print.textOnGreenLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'OnYellow : ' ); print.textOnYelloLine( 'CommandBox Rox off your sox!' );
		print.text( 'OnBlue : ' ); print.textOnBlueLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'OnMagenta : ' ); print.textOnMagentaLine( 'CommandBox Rox off your sox!' );
		print.text( 'OnCyan : ' ); print.textOnCyanLine( 'CommandBox Rox off your sox!' ) ;
		print.text( 'BlackOnWhite : ' ); print.BlackTextOnWhiteLine( 'CommandBox Rox off your sox!' );
		
		// Combinations
		print.text( 'redOnWhite : ' ); print.redOnWhiteLine( 'CommandBox Rox off your sox!' );
		print.text( 'blueOnGreen : ' ); print.blueOnGreenLine( 'CommandBox Rox off your sox!' );
		print.text( 'blueOnRed : ' ); print.blueOnRedLine( 'CommandBox Rox off your sox!' );
		print.text( 'redOnCyan : ' ); print.redOnCyanLine( 'CommandBox Rox off your sox!' );
		
		// Get funky! ("Background" is just extranious text that will be ignored)
		print.text( 'boldBlinkingUnderscoredBlueLineOnRedBackground : ' ); print.boldBlinkingUnderscoredBlueLineOnRedBackground( 'CommandBox Rox off your sox!' );
		// "green" is the only thing used in this one
		print.text( 'dumpUglygreenCrapToStreen : ' ); print.dumpUglygreenCrapToStreenLine( 'CommandBox Rox off your sox!' );
		
	}


}