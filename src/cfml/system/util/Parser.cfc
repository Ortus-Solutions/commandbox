/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* CommandBox Command Line Parser and Tokenizer
*
*/
component {

	// DI
	property name="CR" 				inject="CR";
	
	/**
	 * constructor
 	**/	
	function init(  ) {
    	return this;
	}
	
	
	/**
	 * Tokenizes the command line entered by the user.  Returns array with command statements and arguments
	 *
	 * Consider making a dedicated CFC for this since some of the logic could benifit from 
	 * little helper methods to increase readability and reduce duplicate code.
 	 **/
	function tokenizeInput( string line ) {
		
		// Holds token
		var tokens = [];
		// Used to build up each token
		var token = '';
		// Are we currently inside a quoted string
		var inQuotes = false;
		// What quote character is around our current quoted string (' or ")
		var quoteChar = '';
		// Is the current character escaped
		var isEscaped = false;
		// Are we waiting for the "value" portion of a name/value pair. (In case there is whitespace we're wading through)
		var isWaitingOnValue = false;
		// The previous character to handle escape chars.
		var prevChar = '';
		// The previous character was escaped
		var prevEscaped = false;
		// Pointer to the current character
		var i = 0;
		
		// Loop over each character in the line
		while( ++i <= len( line ) ) {
			// Current character
			char = mid( line, i, 1 );
			// All the remaining characters
			remainingChars = mid( line, i, len( line ) );
			// Reset this every time
			isEscaped = false;
			
			// This character might be escaped
			if( prevChar == '\' && !prevEscaped ) {
				isEscaped = true;
			}
			
			// If we're in the middle of a quoted string, just keep appending
			if( inQuotes ) {
				token &= char;
				// We just reached the end of our quoted string
				if( char == quoteChar && !isEscaped ) {
					inQuotes = false;
					tokens.append( token);
					token = '';
				}
				prevEscaped = isEscaped;
				prevChar = char;
				continue;
			}
			
			// Whitespace demarcates tokens outside of quotes
			// Whitespace outside of a quoted string is dumped and not added to the token
			if( trim(char) == '' ) {
				
				// Don't break if an = is next ...
				if( left( trim( remainingChars ), 1 ) == '=' ) {
					isWaitingOnValue = true;
					prevEscaped = isEscaped;
					prevChar = char;
					continue;
				// ... or if we just processed one and we're waiting on the value.
				} else if( isWaitingOnValue ) {
					prevEscaped = isEscaped;
					prevChar = char;
					continue;
				// Append what we have and start anew
				} else {
					if( len( token ) ) {
						tokens.append( token);
						token = '';					
					}
					prevEscaped = isEscaped;
					prevChar = char;
					continue;
				}
			}
			
			// We're starting a quoted string
			if( ( char == '"' || char == "'" ) && !isEscaped ) {
				inQuotes = true;
				quoteChar = char;
			}
			
			// Keep appending
			token &= char;
			
			// If we're waiting for a value in a name/value pair and just hit something OTHER than an =
			if( isWaitingOnValue && char != '=' ) {
				// Then the wait is over
				isWaitingOnValue = false;
			}
			
			prevEscaped = isEscaped;
			prevChar = char;
			
		} // end while
		
		// Anything left after the loop is our last token
		if( len( token ) ) {
			tokens.append( token);					
		}
		
		return tokens;
	}


	/**
	 * Parse an array of parameter tokens. unescape values and determine if named or positional params are being used.
 	 **/
	function parseParameters( required array parameters ) {
		
		var results = {
			positionalParameters = [],
			namedParameters = {},
			flags = {}
		};
		
		if( !arrayLen( parameters ) ) {
			return results;			
		}
		
		for( var param in parameters ) {
			
			// Remove escaped characters
			param = removeEscapedChars( param );
			
			// Flag --flagName
			if( param.startsWith( '--' ) && len( param ) > 3 ) {
				// Strip off --
				var flagName = right( param, len( param ) - 2 );
				
				// Check for negation --!flagName
				if( flagName.startsWith( '!' ) ) {
					// Strip !
					flagName = right( flagName, len( flagName ) - 1 );
					// Flag is false
					results.flags [ flagName ] = false;
				} else {
					// Flag is true
					results.flags [ flagName ] = true;
				}
				
			// named params
			} else if( find( '=', param, 2 ) ) {
				// Extract the name and value pair
				var name = listFirst( param, '=' );
				var value = listRest( param, '=' );
				
				// Unwrap quotes from value if used
				value = unwrapQuotes( value );
				
				name = replaceEscapedChars( name );
				value = replaceEscapedChars( value );
								
				results.namedParameters[ name ] = value;
				
			// Positional params
			} else {
				if(param contains 'widget'){
					//writeDump(param);abort;
				}
				// Unwrap quotes from value if used
				param = unwrapQuotes( param );
				param = replaceEscapedChars( param );
				results.positionalParameters.append( param );				
			}
						
		}
		
		return results;
		
	}

	private function unwrapQuotes( theString ) {
		if( left( theString, 1 ) == '"' or left( theString, 1 ) == "'") {
			return mid( theString, 2, len( theString ) - 2 );
		}
		return theString;
	}
	
	private function removeEscapedChars( theString ) {
		theString = replaceNoCase( theString, "\\", '__backSlash__', "all" );
		theString = replaceNoCase( theString, "\'", '__singleQuote__', "all" );
		theString = replaceNoCase( theString, '\"', '__doubleQuote__', "all" );
		theString = replaceNoCase( theString, '\n', '__newLine__', "all" );
		return		replaceNoCase( theString, '\=', '__equalSign__', "all" );
	}
	
	private function replaceEscapedChars( theString ) {
		theString = replaceNoCase( theString, '__backSlash__', "\", "all" );
		theString = replaceNoCase( theString, '__singleQuote__', "'", "all" );
		theString = replaceNoCase( theString, '__doubleQuote__', '"', "all" );
		theString = replaceNoCase( theString, '__newLine__', CR, "all" );
		return		replaceNoCase( theString, '__equalSign__', '=', "all" );
	}
	
	
	
}