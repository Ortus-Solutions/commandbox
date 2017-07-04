/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am a helper object for creating pretty ANSI-formmatted
* text in the shell.  I use onMissingMethod to allow for nice,
* readable methods that contain combinations of text and background
* colors as well as text formatting.
* Ex.
* print.Line()
* print.text( 'Hello World' );
* print.boldText( 'Hello World' );
* print.line( 'Hello World' );
* print.redLine( 'Hello World' );
* print.redOnWhiteLine( 'Hello World' );
* print.redOnWhiteBold( 'Hello World' );
* print.boldBlinkingUnderscoredBlueTextOnRedBackground( 'Test' );
*
* If you want to modify formatting at runtime, pass a second parameter of additional text
* that will be appended to the method name upon processing.
*
* print.text( 'Hello World', 'blue' );
* print.text( 'Hello World', statusColor );
* print.text( 'Hello World', ( status == 'running' ? 'green' : 'red' ) );
*
* Indent each carridge return with two spaces like so:
*
* print.indentedLine( 'Hello World' );
*
*/
component {

	property name='cr' inject='cr@constants' scope='this';

	this.tab 		= chr( 9 );
	this.esc 		= chr( 27 );

	// These are the valid ANSI attributes
	this.ANSIAttributes = {
		// Remove all formatting
		"off" : 0,
		"none" : 0,

		// Text decoration
		"bold" : 1,
		"underscored" : 4,
		"blinking" : 5,
		"reversed" : 7,
		"concealed" : 8,

		// Text Color
		"black" : 30,
		"red" : 31,
		"green" : 32,
		"yellow" : 33,
		"blue" : 34,
		"magenta" : 35,
		"cyan" : 36,
		"white" : 37,

		// Background
		"onBlack" : 40,
		"onRed" : 41,
		"onGreen" : 42,
		"onYellow" : 43,
		"onBlue" : 44,
		"onMagenta" : 45,
		"onCyan" : 46,
		"onWhite" : 47
	};

	/**
	 * Removes ANSI attributes from string
	 * @string.hint string to remove ANSI from
  	 **/
	function unansi(required ansiString) {
		var st = createObject("java","org.fusesource.jansi.AnsiString").init(ansiString);
		return st.getPlain();
	}

	/**
	 * This allows you concatenate pretty method names to describe the kind of text you want to generate
	 * If the method name contains "line", it will be appended with a carriage return
	 * Any other token in the name that exists in the list of ANSI attributes above will be picked up and applied to the text
	 *
  	 **/
	function onMissingMethod( missingMethodName, missingMethodArguments ) {

		// Flag for if this is a line or not
		var newLine = false;

		// Name of the method to chop up
		var methodName = missingMethodName;

		// TODO: Actually use a string buffer
		var ANSIString = "";

		// Text needing formatting
		var text = arrayLen(missingMethodArguments) ? missingMethodArguments[ 1 ] : '';
		// Additional formatting text
		var methodName &= arrayLen(missingMethodArguments) > 1 ? missingMethodArguments[ 2 ] : '';
		// Don't turn off ANSI formatting at the end
		var noEnd = arrayLen(missingMethodArguments) > 2 ? missingMethodArguments[ 3 ] : false;

		// Carve it up until it's gone
		while( len( methodName ) ) {
			foundANSI = false;

			// Look for each attrib
			for( var attrib in this.ANSIAttributes ) {

				// Check for an attribute match
				var attribLen = len( attrib );
				if( left( methodName, attribLen ) == attrib ) {

					// Add that attribute to the string
					ANSIString &= getANSIAttribute( this.ANSIAttributes[ attrib ] );
					// Slice this bit off the method name
					methodName  = mid( methodName, attribLen+1, len( methodName ) );
					foundANSI = true;
					// Next!
					break;
				}

			}

			// If we matched an ANSI code, start the loop over
			if( foundANSI ) {
				continue;
			}

			// Check for "indented"
			if( left( methodName, 8 ) == 'indented' ) {
				text = indent( text );
				// Slice this bit off the method name
				methodName  = mid( methodName, 9, len( methodName ) );
				// Next!
				continue;
			}

			// Check for "line"
			if( left( methodName, 4 ) == 'line' ) {
				newLine = true;
				// Slice this bit off the method name
				methodName  = mid( methodName, 5, len( methodName ) );
				// Next!
				continue;
			}

			// Check for "text"
			if( left( methodName, 4 ) == 'text' ) {
				// This is just placeholder text for readability, so don't do anything with it

				// Slice this bit off the method name
				methodName  = mid( methodName, 5, len( methodName ) );
				// Next!
				continue;
			}

			// If we reached here, it means unrecognized text got in the method name.
			// Just slice of a character and try again.  Eventually we'll reach something we
			// recognize, or we'll hit the end of the string
			methodName  = mid( methodName, 2, len( methodName ) );

		} // End While loop

		// Don't mess with the string if we didn't format it
		if( len( ANSIString ) ) {
			text = ANSIString & text;
			if( !noEnd ) {
				text &= getANSIAttribute( this.ANSIAttributes["off"] );
			}
		}

		// Add a CR if this was supposed to be a line
		if( newLine ) {
			text &= this.cr;
		}

		return text;

	}

	/**
	* Get an ANSI Attribute
	*/
	private String function getANSIAttribute( required attribute ) {
		return this.ESC & "[" & arguments.attribute & "m";
    }

	/**
	* Pad all lines with 2 spaces
	*/
	private String function indent( text ) {
		return '  ' & replaceNoCase( arguments.text, this.cr, this.cr & '  ', 'all' );
    }

}