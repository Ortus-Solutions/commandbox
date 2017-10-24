/**
*********************************************************************************
* Copyright Since 2014 by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
* 
*/
component accessors="true" singleton alias='JSONPrettyPrint' {

	/**
	 * Pretty JSON
	 * @json A string containing JSON, or a complex value that can be serialized to JSON
	 * @lineEnding String to use for indenting lines.  Defaults to four spaces.
	 * @lineEnding String to use for line endings.  Defaults to CRLF.
	 * @spaceAfterColon Add space after each colon like "value": true instead of"value":true 
 	 **/
	public function formatJson( json, indent='    ', lineEnding=chr( 13 ) & chr( 10 ), boolean spaceAfterColon=false ) {
		
		// Overload this method to accept a struct or array
		if( !isSimpleValue( arguments.json ) ) {
			arguments.json = serializeJSON( arguments.json );
		}
		
		var retval = createObject( 'java', 'java.lang.StringBuilder' ).init( '' );
		var str = json;
	    var pos = 0;
	    var strLen = str.length();
		var indentStr = arguments.indent;
	    var newLine = arguments.lineEnding;
		var char = '';
		var nextChar = '';
		var inQuote = false;
		var isEscaped = false;
		var itemsInCollection = 0;

		for ( var i=0; i<strLen; i++ ) {
			nextChar = '';
			char = str.substring( i, i+1 );
			if( str.len()-1 > i ) {
				nextChar = str.substring( i+1, i+2 );				
			}
			if( isEscaped ) {
				isEscaped = false;
				retval.append( char );
				continue;
			}
			
			if( char == '\' ) {
				isEscaped = true;
				retval.append( char );
				continue;
			}
			
			if( char == '"' ) {
				if( inQuote ) {
					inQuote = false;
				} else {
					inQuote = true;					
				}
				retval.append( char );
				continue;
			}
			
			if( inQuote ) {
				retval.append( char );
				continue;
			}	
			
			
			if (char == '}' || char == ']') {
				pos = pos - 1;
				if( itemsInCollection ) {
					retval.append( newLine );
					retval.append( repeatString( indentStr, pos ) );
				}				
			}
			
			retval.append( char );
			
			if (char == ',') {
				retval.append( newLine );
				retval.append( repeatString( indentStr, pos ) );
			}
			
			if ( char == '{' || char == '[') {
				itemsInCollection = 0;
				pos = pos + 1;
				if( nextChar != ']' && nextChar != '}' ) {
					retval.append( newLine );
					retval.append( repeatString( indentStr, pos ) );
				}
			}
			
			if (char == ':' ) {
				itemsInCollection++;
				if( spaceAfterColon ) {
					retval.append( ' ' );
				}
			}
		}
		return retval.toString();
	}

}