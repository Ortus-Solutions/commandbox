/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am a helper object for creating pretty ANSI-formatted
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
* Indent each carriage return with two spaces like so:
*
* print.indentedLine( 'Hello World' );
*
*/
component {

	property name='cr'				inject='cr@constants';
	property name='shell'			inject='shell';
	property name='colors256Data'	inject='colors256Data@constants';
	property name='formatterUtil'	inject='formatter';
	property name='JSONService'		inject='JSONService';
	property name='tablePrinter'    inject='provider:TablePrinter';

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

	};

	/**
	 * Removes ANSI attributes from string
	 * @string.hint string to remove ANSI from
  	 **/
	function unansi(required ansiString) {
		return createObject("java","org.jline.utils.AttributedString").stripAnsi( ansiString );
	}

	/**
	 * This allows you concatenate pretty method names to describe the kind of text you want to generate
	 * If the method name contains "line", it will be appended with a carriage return
	 * Any other token in the name that exists in the list of ANSI attributes above will be picked up and applied to the text
	 *
  	 **/
	function onMissingMethod( missingMethodName, missingMethodArguments ) {

		// Check for Ctrl-C
		shell.checkInterrupted();

		// Flag for if this is a line or not
		var newLine = false;

		// Keep track of bold separately
		var bold = false;

		// Name of the method to chop up
		var methodName = missingMethodName;

		// TODO: Actually use a string buffer
		var ANSIString = "";

		// Text needing formatting
		var text = arrayLen(missingMethodArguments) ? missingMethodArguments[ 1 ] : '';
		// Convert complex values to a string representation
		if( !isSimpleValue( text ) ) {

			// Serializable types
			if( isBinary( text ) ) {
				// Generally speaking, leave binary alone, but if it just so happens to be a string that happens to be JSON, let's format it!
				// CommandBox will turn the binary to a string when it outputs anyway if we don't here.
				if( isJSON( toString( text ) ) ) {
					text = formatterUtil.formatJson( json=toString( text ), ANSIColors=JSONService.getANSIColors() );
				}
			} else if( isArray( text ) || isStruct( text ) || isQuery( text ) ) {
				text = serializeJSON( text, 'struct' );
				text = formatterUtil.formatJson( json=text, ANSIColors=JSONService.getANSIColors() );
			// Yeah, I give up
			} else {
				text = '[#text.getClass().getName()#]';
			}

		}
		// Additional formatting text
		var methodName &= arrayLen(missingMethodArguments) > 1 ? missingMethodArguments[ 2 ] : '';
		// Don't turn off ANSI formatting at the end
		var noEnd = arrayLen(missingMethodArguments) > 2 ? missingMethodArguments[ 3 ] : false;

		// Carve it up until it's gone
		while( len( methodName ) ) {
			foundANSI = false;

			// 256 color support.  Denormalized into groups to reduce the amount of string manipulation
			for( var group in colors256Data ) {
				// Bail if the remaining string isn't even long enough to search
				if( methodName.len() < group.len ) {
					continue;
				}
				// Peel off this many chars and check for all colors of that length at once
				var thisToken = methodName.left( group.len );
				if( group.colors.keyExists( thisToken ) ) {
					// Generate the ANSI escape code
					ANSIString &= get256Color( group.colors[ thisToken ].colorID );

					// Slice this bit off the method name
					methodName  = mid( methodName, group.len+1, len( methodName ) );
					foundANSI = true;
					// Next!
					break;
				}
				// Check for background colors

				// Bail if the remaining string isn't even long enough to search
				if( methodName.len() < group.len + 2 ) {
					continue;
				}
				// Peel off this many chars and check for all colors of that length at once
				var thisToken = methodName.left( group.len + 2 );
				if( group.colors.keyExists( thisToken.right( -2 ) ) ) {
					// Generate the ANSI escape code
					ANSIString &= get256Color( group.colors[ thisToken.right( -2 ) ].colorID, false );

					// Slice this bit off the method name
					methodName  = mid( methodName, group.len+3, len( methodName ) );
					foundANSI = true;
					// Next!
					break;
				}
			}

			// If we matched an ANSI code, start the loop over
			if( foundANSI ) {
				continue;
			}

			// Look for each attrib
			for( var attrib in this.ANSIAttributes ) {

				// Check for an attribute match
				var attribLen = len( attrib );
				if( left( methodName, attribLen ) == attrib ) {
					// Bold gets added at the end
					if( attrib == 'bold' ) {
						bold = true;
					} else {
						// Add that attribute to the string
						ANSIString &= getANSIAttribute( this.ANSIAttributes[ attrib ] );
					}
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

			// Check for "color123"
			if( methodName.left( 5 ) == 'color' ) {
				// Slice this bit off the method name
				methodName  = mid( methodName, 6, len( methodName ) );
				var colorID = val( methodName );

				if( colorID > 0 || methodname.startsWith( '0' ) ) {

					ANSIString &= get256Color( colorID );

					// Slice this bit off the method name
					methodName  = mid( methodName, len( colorID )+1 , len( methodName ) );

					// Next!
					continue;
				}
			}

			// Check for "onColor123"
			if( methodName.left( 7 ) == 'onColor' ) {
				// Slice this bit off the method name
				methodName  = mid( methodName, 8, len( methodName ) );
				var colorID = val( methodName );

				if( colorID > 0 || methodname.startsWith( '0' ) ) {

					ANSIString &= get256Color( colorID, false );

					// Slice this bit off the method name
					methodName  = mid( methodName, len( colorID )+1 , len( methodName ) );

					// Next!
					continue;
				}
			}

			// If we reached here, it means unrecognized text got in the method name.
			// Just slice of a character and try again.  Eventually we'll reach something we
			// recognize, or we'll hit the end of the string
			methodName  = mid( methodName, 2, len( methodName ) );

		} // End While loop

		// Don't mess with the string if we didn't format it
		if( len( ANSIString ) || bold ) {
			// Bold doesn't always work if it's not at the end
			if( bold ) {
				ANSIString &= getANSIAttribute( this.ANSIAttributes[ 'bold' ] );
			}
			text = ANSIString & text;
			if( !noEnd ) {
				text &= getANSIAttribute( this.ANSIAttributes["off"] );
			}
		}

		// Add a CR if this was supposed to be a line
		if( newLine ) {
			text &= cr;
		}

		return text;

	}

    /**
     * Outputs a table to the screen
	 * @data Any type of data for the table.  Each item in the array may either be
	 *            an array in the correct order matching the number of headers or a struct
	 *            with keys matching the headers.
	 * @includedHeaders A list of headers to include.  Used for query inputs
     * @headerNames An list/array of column headers to use instead of the default
	 * @debug Only print out the names of the columns and the first row values
     */
	function table(
		required any data=[],
        any includedHeaders="",
        any headerNames="",
		boolean debug=false
    ){
		return tablePrinter.print( argumentCollection=arguments );
	}

	/**
	* Get an ANSI Attribute
	*/
	private String function getANSIAttribute( required attribute ) {
		return this.ESC & "[" & arguments.attribute & "m";
    }

	/**
	* Get an 256 color ANSI
	*/
	private String function get256Color( required id, foreground=true ) {
		return this.ESC & "[" & ( foreground ? 3 : 4 ) & "8;5;" & arguments.id & "m";
    }

	/**
	* Pad all lines with 2 spaces
	*/
	private String function indent( text ) {
		return '  ' & replaceNoCase( arguments.text, cr, cr & '  ', 'all' );
    }

}
