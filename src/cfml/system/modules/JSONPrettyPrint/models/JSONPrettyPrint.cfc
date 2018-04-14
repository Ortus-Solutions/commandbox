/**
*********************************************************************************
* Copyright Since 2014 by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
* 
*/
component accessors="true" singleton alias='JSONPrettyPrint' {

	function init() {
		variables.os = createObject( "java", "java.lang.System" ).getProperty( "os.name" ).toLowerCase();
		return this;
	}
		
	// OS detector
	private boolean function isWindows(){ return variables.os.contains( "win" ); }

	/**
	 * Pretty JSON
	 * @json A string containing JSON, or a complex value that can be serialized to JSON
	 * @indent String to use for indenting lines.  Defaults to four spaces.
	 * @lineEnding String to use for line endings.  Defaults to CRLF on Windows and LF on *nix
	 * @spaceAfterColon Add space after each colon like "value": true instead of"value":true 
 	 **/
	public function formatJson( any json, string indent='    ', lineEnding, boolean spaceAfterColon=false ) {
		
		// Default line ending based on OS
		if( isNull( arguments.lineEnding ) ) {
			if( isWindows() ) {
				arguments.lineEnding = chr( 13 ) & chr( 10 );
			} else {
				arguments.lineEnding = chr( 10 );				
			}
		}
		
		// Overload this method to accept a struct or array
		if( !isSimpleValue( arguments.json ) ) {
			arguments.json = serializeJSON( arguments.json );
		}
		
		arguments.json = arguments.json.replace( '	', '', 'all' );
		arguments.json = arguments.json.replace( chr( 10 ), '', 'all' );
		arguments.json = arguments.json.replace( chr( 13 ), '', 'all' );
		
		var retval = createObject( 'java', 'java.lang.StringBuilder' ).init( '' );
		var str = json;
		var strLen = str.len();
	    var pos = 0;
	    var strLen = str.length();
		var indentStr = arguments.indent;
	    var newLine = arguments.lineEnding;
		var char = '';
		var nextChar = '';
		var inQuote = false;
		var isEscaped = false;
		var itemsInCollection = [];

		for ( var i=0; i<strLen; i++ ) {
			nextChar = ' ';
			// The current char we're looking at
			char = str.mid( i+1, 1 );
			
			// Is current char escaped
			if( isEscaped ) {
				isEscaped = false;
				retval.append( char );
				continue;
			}
			
			// Next char is Escaped
			if( char == '\' ) {
				isEscaped = true;
				retval.append( char );
				continue;
			}
			
			// Detect start of quotes
			if( char == '"' ) {
				if( inQuote ) {
					inQuote = false;
				} else {
					inQuote = true;					
				}
				retval.append( char );
				continue;
			}
			
			// All text in quotes is appended right in
			if( inQuote ) {
				retval.append( char );
				continue;
			}	
			
			// Ignore whitespace not in quotes.  We'll be adding back in what we want
			if ( !char.trim().len() ) {
				continue;				
			}
			
			// Ending a block
			if (char == '}' || char == ']') {
				pos = pos - 1;
				if( itemsInCollection.last() ) {
					retval.append( newLine );
					retval.append( repeatString( indentStr, pos ) );
				}
				itemsInCollection.deleteAt( itemsInCollection.len() );
			}
			
			retval.append( char );
			
			// End of an item in an object or array
			if (char == ',') {
				retval.append( newLine );
				retval.append( repeatString( indentStr, pos ) );
			}
			
			// Startinga block
			if ( char == '{' || char == '[') {
				pos = pos + 1;
				
				// "peek" at the next non-whitespace char in line
				var offset = 1;
				while( strLen > i+offset && nextChar == ' ' ) {
					nextChar = str.mid( i+offset+1, 1 );
					offset++;
				}
				
				if( nextChar != ']' && nextChar != '}' ) {
					itemsInCollection.append( true );
					retval.append( newLine );
					retval.append( repeatString( indentStr, pos ) );
				} else {
					itemsInCollection.append( false );
				}				
			}
			
			// Colon between key and value.
			if (char == ':' ) {
				if( spaceAfterColon ) {
					retval.append( ' ' );
				}
			}
			
		} // End for loop
		
		return retval.toString();
	}

}
