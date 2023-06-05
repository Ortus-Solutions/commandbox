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

	processingdirective pageEncoding='UTF-8';

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
		return _onMissingMethod( argumentCollection=arguments );
	}

	private function _onMissingMethod( missingMethodName, missingMethodArguments ) {

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

		var foundANSI = false;

		// Text needing formatting
		var text = arrayLen(missingMethodArguments) ? missingMethodArguments[ 1 ] : '';
		// Convert complex values to a string representation
		if( isXMLNode( text ) ) {
			text = formatterUtil.formatXML( text );
		} else if( !isSimpleValue( text ) ) {

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
	 * @width Override the terminal width
     */
	function table(
		required any data=[],
        any includedHeaders="",
        any headerNames="",
		boolean debug=false,
		width=-1
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

	public String function columns( required array items, formatUDF=()=>'' ) {
		var numItems = items.len();
		var widestItem = items.map( (v)=>len( v ) ).max();
		var colWdith = widestItem + 4;
		var termWidth = shell.getTermWidth()-1;
		var numCols = max( termWidth\colWdith, 1 );
		var numRows = ceiling( numItems/numCols );
		var columnText = createObject( 'java', 'java.lang.StringBuilder' ).init( '' );

		loop from=1 to=numRows index="local.row" {
			loop from=1 to=numCols index="local.col" {
				var thisIndex = row+((col-1)*numRows);
				if( thisIndex > numItems ) {
					var thisItem = '';
				} else {
					var thisItem = items[thisIndex];
				}
				columnText.append( _onMissingMethod( 'text', [ padRight( thisItem, colWdith ), formatUDF( thisItem, row, col ) ] ) );
			}
			columnText.append( cr );
		}
		return columnText.toString();
	}

    /**
     * Adds characters to the right of a string until the string reaches a certain length.
     * If the text is already greater than or equal to the maxWidth, the text is returned unchanged.
     * @text The text to pad.
     * @maxWidth The number of characters to pad up to.
     * @padChar The character to use to pad the text.
     */
	private string function padRight( required string text, required numeric maxWidth, string padChar = " " ) {
		var textLength = len( arguments.text );
		if ( textLength == arguments.maxWidth ) {
			return arguments.text;
		} else if( textLength > arguments.maxWidth ) {
			if( arguments.maxWidth < 4 ) {
				return left( text, arguments.maxWidth );
			} else {
				return left( text, arguments.maxWidth-3 )&'...';
			}
		}
		arguments.text &= repeatString( arguments.padChar, arguments.maxWidth-textLength );
		return arguments.text;
	}

	/**
	* Print a struct of structs as a tree
	*
	* @data top level struct
	* @formatUDF A UDF receiving both a string-concatenated prefix of keys, and an array of the same data.  Returns string of special formating for that node of the tree
	*/
	function tree( required struct data, formatUDF=()=>'' ) {
		var treeSB = createObject( 'java', 'java.lang.StringBuilder' ).init( '' );
		_tree( parent=data, prefix='', formatUDF=formatUDF, treeSB=treeSB );
		return treeSB.toString();
	}

	private function _tree( required struct parent, required string prefix, required formatUDF, required any treeSB, Array keyPath=[] ) {
		var i = 0;
		var keyCount = structCount( arguments.parent );
		for( var keyName in arguments.parent ) {
			keyPath.append( keyName );
			var child = arguments.parent[ keyName ];
			var childKeyCount = isStruct( child ) ? structCount( child ) : 0;
			i++;
			var isLast = ( i == keyCount );
			var branch = ( isLast ? '└' : '├' ) & '─' & ( childKeyCount ? '┬' : '─' );
			var branchCont = ( isLast ? ' ' : '│' ) & ' ' & ( childKeyCount ? '│' : ' ' );

			// If the key name has line breaks, output each individually
			keyName.listToArray( chr(13)&chr(10) ).each( ( l, i )=>{
				treeSB.append( prefix & ( i == 1 ? branch : branchCont ) & ' ' );
				treeSB.append( _onMissingMethod( 'line', [ l, formatUDF( keyPath.toList( '' ), keyPath ) ] ) );
			} );

			if( isStruct( child ) ) {
				_tree( parent=child, prefix=prefix & ( isLast ? '  ' : '│ ' ), formatUDF=formatUDF, treeSB=treeSB, keyPath=keyPath );
			}
			keyPath.deleteAt( keyPath.len() );
		}
	}
}