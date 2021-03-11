/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* CommandBox Command Line Parser and Tokenizer
*
*/
component {

	// DI
	property name="CR" inject="CR@constants";

	/**
	 * constructor
 	**/
	function init(  ) {
    	return this;
	}


	/**
	 * Tokenizes the command line entered by the user.  Returns array with command statements and arguments
	 *
	 * Consider making a dedicated CFC for this since some of the logic could benefit from
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
			remainingChars = mid( line, i+1, len( line ) );

			// Reset this every time
			isEscaped = false;

			// This character might be escaped
			if( prevChar == '\' && !prevEscaped ) {
				isEscaped = true;
			}

			// If we're in the middle of a quoted string, just keep appending
			if( inQuotes ) {
				// Auto-escape = in a quoted string so it doesn't screw up named-parameter detection.
				// It will be unescaped later when we parse the params.
				if( char == '=' && !isEscaped ) {
					token &= '\';
				}
				token &= char;
				// We just reached the end of our quoted string
				// This will break `foo="bar"baz` into two tokens: `foo="bar"` and `baz`
				if( char == quoteChar && !isEscaped ) {
					inQuotes = false;
					// Don't break if an = is next ...
					if( left( trim( remainingChars ), 1 ) != '=' ) {
						tokens.append( token);
						token = '';
					}
				}
				prevEscaped = isEscaped;
				prevChar = char;
				continue;
			}

			// Whitespace demarcates tokens outside of quotes
			// Whitespace outside of a quoted string is dumped and not added to the token
			if( trim(char) == '' || ( char == ';' && !isEscaped ) ) {

				// If this is an unquoted, unescaped semi colon (;)
				if( char == ';' ) {
					if( len( token ) ) {
						tokens.append( token);
						token = '';
					}
					tokens.append( char );
					prevEscaped = isEscaped;
					prevChar = char;
					continue;
				// Don't break if an = is next ...
				} else	if( left( trim( remainingChars ), 1 ) == '=' ) {
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
			if( ( char == '"' || char == "'"  || char == "`" ) && !isEscaped ) {
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
	function parseParameters( required array parameters, commandParameters ) {

		var results = {
			positionalParameters = [],
			namedParameters = {},
			flags = {}
		};

		if( !arrayLen( parameters ) ) {
			return results;
		}

		// Pull the valid param names out into an array for easy lookup
		var commandParameterNameLookup=[];
		for( var thisParam in commandParameters ) {
			commandParameterNameLookup.append( thisParam.name );
		}

		for( var param in parameters ) {

			// Remove escaped characters
			param = removeEscapedChars( param );

			// Flag --flagName
			if( param.startsWith( '--' ) && len( param ) >= 3 ) {
				// Strip off --
				var flagName = right( param, len( param ) - 2 );

				// Check for negation --!flagName
				if( flagName.startsWith( '!' ) ) {
					if( len( flagName ) > 1 ) {
						// Strip !
						flagName = right( flagName, len( flagName ) - 1 );
						// Flag is false
						results.flags [ flagName ] = false;
					}
				// If param name starts with "no" and matches existing param, then negate.
				} else if( len( flagName ) > 2 && left( flagName, 2 ) == 'no' && commandParameterNameLookup.findNoCase( mid( flagName, 3, len( flagName ) ) ) ) {
					results.flags [ mid( flagName, 3, len( flagName ) ) ] = false;
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
				name = unwrapQuotes( name );
				value = unwrapQuotes( value );

				// Mark expressions and system settings now while escaped chars are removed
				value = markExpressions( value );
				value = markSystemSettings( value );

				name = replaceEscapedChars( name );
				value = replaceEscapedChars( value );

				results.namedParameters[ name ] = value;

			// Positional params
			} else {
				// Unwrap quotes from value if used
				param = unwrapQuotes( param );

				// Mark expressions and system settings now while escaped chars are removed
				param = markExpressions( param );
				param = markSystemSettings( param );

				param = replaceEscapedChars( param );
				results.positionalParameters.append( param );
			}

		}

		return results;

	}

	/**
	* Find any strings encased in backticks and flags them as a CommandBox expression
	*/
	function markExpressions( required argValue ) {
		return reReplaceNoCase( argValue, '`(.*?)`', '__expression__\1__expression__', 'all' );
	}

	/**
	* Find any strings like ${foo} and flag them as a system setting
	*/
	function markSystemSettings( required argValue ) {
		return reReplaceNoCase( argValue, '\$\{(.*?)}', '__system__\1__system__', 'all' );
	}

	/**
	* Escapes a value and for inclusion in a command
	* The following replacements are made:
	* " 			--> \"
	* ' 			--> \'
	* ` 			--> \`
	* = 			--> \=
	* ; 			--> \;
	* & 			--> \&
	* | 			--> \|
	* ${ 			--> \${
	*/
	string function escapeArg( argValue ) {
		arguments.argValue = replace( arguments.argValue, '\', "\\", "all" );
		arguments.argValue = replace( arguments.argValue, '"', '\"', 'all' );
		arguments.argValue = replace( arguments.argValue, "'", "\'", "all" );
		arguments.argValue = replace( arguments.argValue, "`", "\`", "all" );
		arguments.argValue = replace( arguments.argValue, "=", "\=", "all" );
		arguments.argValue = replace( arguments.argValue, ";", "\;", "all" );
		arguments.argValue = replace( arguments.argValue, "&", "\&", "all" );
		arguments.argValue = replace( arguments.argValue, "|", "\|", "all" );
		arguments.argValue = replace( arguments.argValue, "${", "\${", "all" );
		return arguments.argValue;
	}

	function unwrapQuotes( theString ) {
		// If the value is wrapped with backticks, leave them be.  That is a signal to the CommandService
		// that the string is special and needs to be evaluated as an expression.

		// If the string begins with a matching single or double quote, strip it.
		var startChar = left( theString, 1 );
		if(  startChar == '"' || startChar == "'" ) {
			theString =  mid( theString, 2, len( theString ) - 1 );
			// Strip any matching single or double ending quote
			// Missing ending quotes are invalid but will be ignored
			if( right( theString, 1 ) == startChar ) {
				return mid( theString, 1, len( theString ) - 1 );
			}
		}
		return theString;
	}


	// ----------------------------- Private ---------------------------------------------

	function removeEscapedChars( theString ) {
		theString = replaceNoCase( theString, "\\", '__backSlash__', "all" );
		theString = replaceNoCase( theString, "\'", '__singleQuote__', "all" );
		theString = replaceNoCase( theString, '\"', '__doubleQuote__', "all" );
		theString = replaceNoCase( theString, '\`', '__backtick__', "all" );
		theString = replaceNoCase( theString, '\=', '__equalSign__', "all" );
		theString = replaceNoCase( theString, '\;', '__semiColon__', "all" );
		theString = replaceNoCase( theString, '\&', '__ampersand__', "all" );
		theString = replaceNoCase( theString, '\${', '__system_setting__', "all" );
		return		replaceNoCase( theString, '\|', '__pipe__', "all" );
	}

	function replaceEscapedChars( theString ) {
		theString = replaceNoCase( theString, '__backSlash__', "\", "all" );
		theString = replaceNoCase( theString, '__singleQuote__', "'", "all" );
		theString = replaceNoCase( theString, '__doubleQuote__', '"', "all" );
		theString = replaceNoCase( theString, '__backtick__', '`', "all" );
		theString = replaceNoCase( theString, '__equalSign__', '=', "all" );
		theString = replaceNoCase( theString, '__semiColon__', ';', "all" );
		theString = replaceNoCase( theString, '__ampersand__', '&', "all" );
		theString = replaceNoCase( theString, '__system_setting__', '${', "all" );
		return		replaceNoCase( theString, '__pipe__', '|', "all" );
	}


}
