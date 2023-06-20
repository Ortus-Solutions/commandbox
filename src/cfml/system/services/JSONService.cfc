/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I am a collection of shared functionality for dealing with JSON files
*/
component accessors="true" singleton {

	// DI
	property name="configService"	inject="ConfigService";
	property name="fileSystemUtil"	inject="FileSystem";
	property name="formatterUtil"	inject="Formatter";
	property name="logger"			inject="logbox:logger:{this}";
	property name="Consolelogger"	inject="logbox:logger:console";
	property name="print"			inject="print";
	property name="parser"			inject="parser";
	property name="jmespath"		inject="jmespath";

	/**
	* Constructor
	*/
	function init(){
		return this;
	}

	/**
	* I check for the existence of a property
	*/
	boolean function check( required any JSON, required string property ){

		var fullPropertyName = 'arguments.JSON' & toBracketNotation( arguments.property );

		return isDefined( fullPropertyName );
	}

	/**
	* I get a property from a deserialized JSON object and return it
	*/
	function show( required any JSON, required string property, defaultValue ){

		//pass to JMESPath search command `showJMES` if 'jq:' is found in the beginning of the search string
		if(left(arguments.property,3) == "jq:"){
			return showJMES(arguments.JSON, right(arguments.property,len(arguments.property)-3),arguments.defaultValue);
		}

		var fullPropertyName = 'arguments.JSON' & toBracketNotation( arguments.property );

		if( !isDefined( fullPropertyName ) ) {
			if( structKeyExists( arguments, 'defaultValue' ) ) {
				return arguments.defaultValue;
			} else {
				throw( message='Property [#arguments.property#] doesn''t exist.', type="JSONException");
			}
		}

		return evaluate( fullPropertyName );
	}

	/**
	* I get a property from a deserialized JSON object and return it using JMESPath
	*/
	function showJMES( required any JSON, required string property, defaultValue ){
		if  (arguments.property == '') return arguments.JSON;

        try {
            var results = jmespath.search(arguments.JSON,arguments.property);
            if ( !isNull(results) ){
				return results;
			}
			if ( structKeyExists( arguments, 'defaultValue' ) ){
				return arguments.defaultValue;
			}

			throw( message='Query [#arguments.property#] didn''t return anything.', type="JSONException");
		} catch( JSONException e ){
			rethrow;
		} catch( JMESError e ){
			throw( message=e.message, detail=e.detail & chr( 10 ) & e.tagContext[ 1 ].template & ':' &  e.tagContext[ 1 ].line, type="JSONException");
		} catch( any e ){
			Consolelogger.error( 'Query:[ #arguments.property# ] failed because ' & e.message );
			rethrow;
        }

	}


	/**
	* I set a property from a deserialized JSON object and returns an array of messages regarding the word that was done.
	*/
	function set( required any JSON, required struct properties, required boolean thisAppend ){
		var results = [];

		for( var prop in arguments.properties ) {

			var fullPropertyName = 'arguments.JSON' & toBracketNotation( prop );
			var arrays = findArrays( prop );

			var propertyValue = arguments.properties[ prop ];
			if( isJSON( propertyValue ) ) {
				// We're trying to append and the target property exists
				if( thisAppend && isDefined( fullPropertyName ) ) {
					// The target property we're trying to append to
					var targetProperty = evaluate( fullPropertyName );
					// The value we want to append
					var complexValue = deserializeJSON( propertyValue );
					// The target property is not simple, and matches the same data type as the incoming data
					if( !isSimpleValue( targetProperty ) && ( isArray( targetProperty ) == isArray( complexValue ) ) ) {
						// Make this idempotent so arrays don't get duplicate values
						if( isArray( complexValue ) ) {
							// For each new value
							for( var newValue in complexValue ) {
								// Check to see if it's already in the array
								if( !targetProperty.find( newValue ) ) {
									// If not, add it.
									targetProperty.append( newValue );
								}
							}
						// structs
						} else {
							mergeData( targetProperty, complexValue );
						}
						results.append( '#propertyValue.toString()# appended to #prop#' );
						continue;
					}

				}
				// If any of the ifs above fail, we'll fall back through to this

				// Double check if value is really JSON due to Lucee bug
				if( listFind( '",{,[', left( propertyValue, 1 ) ) ) {
					evaluate( '#fullPropertyName# = deserializeJSON( propertyValue )' );
				} else {
					arrays.each( (a)=>evaluate( 'JSON#a# = JSON#a# ?: []' ) );
					evaluate( '#fullPropertyName# = propertyValue' );
				}
			} else {
				// Intialize any arrays so foo[1]=true creates an array and not a struct
				arrays.each( (a)=>evaluate( 'JSON#a# = JSON#a# ?: []' ) );
				evaluate( '#fullPropertyName# = propertyValue' );
			}
			results.append( 'Set #prop# = #propertyValue.toString()#' );
		}
		return results;
	}


	/**
	* I clear a property from a deserialized JSON object.
	*/
	function clear( required any JSON, required string property ){

		// See if this string ends with array brackets containing a number greater than 1. Ex: test[3]
		var search = reFind( "\[\s*([1-9][0-9]*)\s*\]$", property, 1, true );

		var propArray = tokenizeProp( arguments.property );

		// Deal with array index
		if( search.pos[1] ) {
			// Index to remove
			var arrayIndex = mid( property, search.pos[2], search.len[2] );
			// Path to the array
			var theArray = left( property, search.pos[1]-1 );

			// Verify the full path exists (including the array index)

			var fullPropertyName = 'arguments.JSON' & toBracketNotation( arguments.property );
			if( !isDefined( fullPropertyName ) ) {

				throw( message='#arguments.property# does not exist.', type="JSONException");
			}
			// Get the array reference
			var fullPropertyName = 'arguments.JSON' & toBracketNotation( theArray );
			var propertyValue = evaluate( fullPropertyName );
			// Remove the index
			propertyValue.deleteAt( arrayIndex );

		// Else see if it's a dot-delimited struct path. Ex foo.bar
		} else if( propArray.len() >= 2 ) {
			// Name of last key to remove
			var last = propArray.last().trim();
			// Clean up ['foo'] or 'foo'
			last = parser.unwrapQuotes( trim( last ) );
			if( last.startsWith( '[' ) && last.endsWith( ']' ) ) {
				last = last.right(-1).left(-1);
				last = parser.unwrapQuotes( trim( last ) )
			}

			// path to containing struct
			var everythingBut = propArray.slice( 1, propArray.len()-1 );

			// Confirm it exists
			var fullPropertyName = 'arguments.JSON' & toBracketNotation( everythingBut );

			if( !isDefined( fullPropertyName ) ) {
				throw( message='#arguments.property# does not exist.', type="JSONException");
			}
			// Get a reference to the containing struct
			var propertyValue = evaluate( fullPropertyName );
			// Remove the key
			structDelete( propertyValue, last );
		// Else just a simple property name
		} else {
			// Make sure it exists
			if( !structKeyExists( JSON, arguments.property ) ) {
				throw( message='#arguments.property# does not exist.', type="JSONException");
			}
			// Remove it
			structDelete( JSON, arguments.property );
		}

	}


	// Convert foo.bar-baz[1] to ['foo']['bar-baz'][1]
	public function toBracketNotation( required any property ) {
		if( isSimpleValue( arguments.property ) ) {
			arguments.property = tokenizeProp( arguments.property );
		}
		var fullPropertyName = '';
		for( var item in arguments.property ) {
			if( item.startsWith( '[' ) && item.endsWith( ']' ) ) {
				var innerItem = item.right(-1).left(-1);
				if( isNumeric( innerItem ) ) {
					fullPropertyName &= item;
				} else {
					// ensure foo[bar] becomes foo["bar"] and foo["bar"] stays that way
					innerItem = parser.unwrapQuotes( trim( innerItem ) );
					fullPropertyName &= '[ "#innerItem#" ]';
				}
			} else {
				item = parser.unwrapQuotes( trim( item ) );
				fullPropertyName &= '[ "#item#" ]';
			}
		}
		return fullPropertyName;
	}

	function tokenizeProp( required string str ) {

		// Holds token
		var tokens = [];
		// Used to build up each token
		var token = '';
		// Are we currently inside a quoted string
		var inQuotes = false;
		// Are we currently inside of []
		var inBrackets = false;
		// What quote character is around our current quoted string (' or ")
		var quoteChar = '';
		// The previous character to handle escape chars.
		var prevChar = '';
		// Pointer to the current character
		var i = 0;

		// Loop over each character in the line
		while( ++i <= len( str ) ) {
			// Current character
			var char = mid( str, i, 1 );
			// All the remaining characters
			var remainingChars = mid( str, i+1, len( str ) );

			// If we're in the middle of a quoted string, just keep appending
			if( inQuotes ) {

				token &= char;
				// We just reached the end of our quoted string
				if( char == quoteChar ) {
					inQuotes = false;
				}
				prevChar = char;
				continue;
			}

			if( inBrackets ) {

				token &= char;

				if( char == ']' ) {
					inBrackets = false;
				}
				prevChar = char;
				continue;
			}

			// period or break in brackets means break in token
			if( ( char == '.' && !inBrackets ) || char == '[' ) {

				// We're starting a bracketed string
				if( ( char == '[' ) ) {
					inBrackets = true;
				}

				if( len( token ) ) {
					tokens.append( token );
					token = '';
				}

				if( char == '[' ) {
					token &= char;
				}
				prevChar = char;
				continue;

			}

			// We're starting a quoted string
			if( ( char == '"' || char == "'"  ) ) {
				inQuotes = true;
				quoteChar = char;
			}

			// Keep appending
			token &= char;

			prevChar = char;

		} // end while

		// Anything left after the loop is our last token
		if( len( token ) ) {
			tokens.append( token );
		}

		return tokens;
	}

	// ['foo']['bar-baz'][1] or ["foo"]["bar-baz"][1] --> "foo"."bar-baz"[1]
	private function toJMESNotation(str){
        //find bracketed items with quotes
        //replace them with with double quotes only

		//open bracket + either type of quotes + (value inside of quotes) + either type of quotes + close bracket
        var rgx = "\[[\'\""]([^\[\]\'\""]+)[\'\""]\]";
        var quotesWithDots = rereplace(str,rgx,'."\1"','all'); // "foo""bar-baz"[1]


        return quotesWithDots;
    }
	private function findArrays( required string property ) {
		var arrays = [];
		var fullPropertyName = '';
		for( var item in tokenizeProp( arguments.property ) ) {
			if( item.startsWith( '[' ) && item.endsWith( ']' ) ) {
				var innerItem = item.right(-1).left(-1);
				if( isNumeric( innerItem ) ) {
					if( !arrays.find( fullPropertyName ) ) {
						arrays.append( fullPropertyName );
					}
					fullPropertyName &= item;
				} else {
					// ensure foo[bar] becomes foo["bar"] and foo["bar"] stays that way
					innerItem = parser.unwrapQuotes( trim( innerItem ) );
					fullPropertyName &= '[ "#innerItem#" ]';
				}
			} else {
				fullPropertyName &= '[ "#item#" ]';
			}
		}
		return arrays;
	}

	// Recursive function to crawl struct and create a string that represents each property.
	function addProp( props, prop, safeProp, targetStruct ) {
		if( len( prop ) ) {
			// Handle null key
			if( !isDefined( 'targetStruct#safeProp#' ) ) {
				return props;
			}
			var propValue = evaluate( 'targetStruct#safeProp#' )
		} else {
			var propValue = targetStruct;
		}

		if( isStruct( propValue ) ) {
			// Add all of this struct's keys
			for( var thisProp in propValue ) {
				if( thisProp contains '.' ) {
					var newProp = "#prop#['#thisProp#']";
				} else {
					var newProp = listAppend( prop, thisProp, '.' );
				}
				var newSafeProp = "#safeProp#['#thisProp#']";
				props.append( newProp );
				props = addProp( props, newProp, newSafeProp, targetStruct );
			}
		}

		if( isArray( propValue ) ) {
			// Add all of this array's indexes
			var i = 0;
			while( ++i <= propValue.len() ) {
				if( isNull( propValue[i] ) ) {
					continue;
				}
				var newProp = '#prop#[#i#]';
				var newSafeProp = '#safeProp#[#i#]';
				props.append( newProp );
				props = addProp( props, newProp, newSafeProp, targetStruct );
			}
		}

		return props;
	}

	/**
	* I write JSON objects to disk after pretty printing them.
	* (I also work for CFML objects that can be serialized to JSON.)
	* @path.hint The file path to write to
	* @json.hint A string containing JSON, or a complex value that can be serialized to JSON
	* @locking.hint Set to true to have file system access wrapped in a lock
	*/
	function writeJSONFile( required string path, required any json, boolean locking = false ) {
		var sortKeysIsSet = configService.settingExists( 'JSON.sortKeys' );
		var sortKeys = configService.getSetting( 'JSON.sortKeys', 'textnocase' );
		var oldJSON = '';

		if ( fileExists( path ) ) {
			oldJSON = locking ? fileSystemUtil.lockingFileRead( path ) : fileRead( path );
			// if sortKeys is not explicitly set try to determine current file state
			if ( !sortKeysIsSet && !isSortedJSON( oldJSON, sortKeys ) ) {
				sortKeys = '';
			}
		}

		var newJSON = formatterUtil.formatJson( json = json, sortKeys = sortKeys );
		if ( !oldJSON.len() || oldJSON.right( 1 ) == chr( 10 ) ) {
			newJSON &= configService.getSetting( 'JSON.lineEnding', server.separator.line );
		}

		if ( oldJSON == newJSON ) {
			return;
		}

		// ensure we are writing to an existing directory
		directoryCreate( getDirectoryFromPath( path ), true, true );

		if ( locking ) {
			fileSystemUtil.lockingFileWrite( path, newJSON );
		} else {
			fileWrite( path, newJSON );
		}
	}

	/**
	* I check to see if a JSON object has sorted keys.
	* (I also work for CFML objects that can be serialized to JSON.)
	* @json.hint A string containing JSON, or a complex value that can be serialized to JSON
	* @sortKeys.hint The type of key sorting to check for - i.e. "text" or "textnocase"
	*/
	function isSortedJSON( required any json, required string sortKeys ) {
		if ( isSimpleValue( json ) ) {
			json = deserializeJSON( json );
		}

		var isSorted = function( obj ) {
			if ( isStruct( obj ) ) {
				if ( obj.keyList() != obj.keyArray().sort( sortKeys ).toList() ) {
					return false;
				}
				return obj.every( ( k, v ) => isSorted( v ) );
			}

			if ( isArray( obj ) ) {
				return obj.every( isSorted );
			}

			return true;
		}

		return isSorted( json );
	}

	/**
	* Get ANSI colors for formatting JSON.  Returns defaults if no settings are present
	*/
	function getANSIColors() {
		var ANSIColors = {
            'constant' : configService.getSetting( 'JSON.ANSIColors.constant', 'red' ),
            'key' : configService.getSetting( 'JSON.ANSIColors.key', 'blue' ),
            'number' : configService.getSetting( 'JSON.ANSIColors.number', 'aqua' ),
            'string' : configService.getSetting( 'JSON.ANSIColors.string', 'lime' )
		};

		return ANSIColors.map( function( k, v ) {
			if( v.startsWith( chr( 27 ) ) ) {
				return v;
			} else {
				// Use print helper to convert "DeepPink2" or "color203" to the escape
				return print.text( '', v, true );
			}
		} );

	}


	/**
	* Merges data from source into target
	*/
	function mergeData( any target, any source ) {

		// If it's a struct...
		if( isStruct( source ) && !isObject( source ) && isStruct( target ) && !isObject( target ) ) {
			// Loop over and process each key
			for( var key in source ) {
				var value = source[ key ];
				if( isSimpleValue( value ) ) {
					target[ key ] = value;
				} else if( isStruct( value ) ) {
					target[ key ] = target[ key ] ?: {};
					mergeData( target[ key ], value )
				} else if( isArray( value ) ) {
					target[ key ] = target[ key ] ?: [];
					mergeData( target[ key ], value )
				}
			}
		// If it's an array...
		} else if( isArray( source ) && isArray( target ) ) {
			var i=0;
			for( var value in source ) {
				if( !isNull( value ) ) {
					// For arrays, just append them into the target without overwriting existing items
					target.append( value );
				}
			}
		}
		return target;

	}

}
