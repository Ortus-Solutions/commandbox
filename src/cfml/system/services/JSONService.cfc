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
	property name="configService" inject="ConfigService";
	property name="fileSystemUtil" inject="FileSystem";
	property name="formatterUtil" inject="Formatter";
	property name="logger"        inject="logbox:logger:{this}";
	property name="print"         inject="print";
	property name="parser"         inject="parser";

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
							targetProperty.append( complexValue, true );
						}
						results.append( '#propertyValue# appended to #prop#' );
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
			results.append( 'Set #prop# = #propertyValue#' );
		}
		return results;
	}


	/**
	* I clear a property from a deserialized JSON object.
	*/
	function clear( required any JSON, required string property ){

		// See if this string ends with array brackets containing a number greater than 1. Ex: test[3]
		var search = reFind( "\[\s*([1-9][0-9]*)\s*\]$", property, 1, true );

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

		// Else see if it's a dot-delimted struct path. Ex foo.bar
		} else if( listLen( property, '.' ) >= 2 ) {
			// Name of last key to remove
			var last = listLast( property, '.' );
			// path to containing struct
			var everythingBut = listDeleteAt( property, listLen( property, '.' ), '.' );

			// Confirm it exists
			var fullPropertyName = 'arguments.JSON' & toBracketNotation( everythingBut );

			if( !isDefined( fullPropertyName ) ) {
				throw( message='#arguments.property# does not exist.', type="JSONException");
			}
			// Get a reference to the containing struct
			var propertyValue = evaluate( fullPropertyName );
			// Remove the key
			structDelete( propertyValue, last );
		// Else just a simple propery name
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
	private function toBracketNotation( required string property ) {
		var tmpProperty = replace( arguments.property, '[', '.[', 'all' );
		tmpProperty = replace( tmpProperty, ']', '].', 'all' );
		var fullPropertyName = '';
		for( var item in listToArray( tmpProperty, '.' ) ) {
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
				fullPropertyName &= '[ "#item#" ]';
			}
		}
		return fullPropertyName;
	}
	
	private function findArrays( required string property ) {
		var tmpProperty = replace( arguments.property, '[', '.[', 'all' );
		tmpProperty = replace( tmpProperty, ']', '].', 'all' );
		var arrays = [];
		var fullPropertyName = '';
		for( var item in listToArray( tmpProperty, '.' ) ) {
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
		var propValue = ( len( prop ) ? evaluate( 'targetStruct#safeProp#' ) : targetStruct );

		if( isStruct( propValue ) ) {
			// Add all of this struct's keys
			for( var thisProp in propValue ) {
				var newProp = listAppend( prop, thisProp, '.' );
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
				i++;
				if( !isNull( value ) ) {
					if( isSimpleValue( value ) ) {
						target[ i ] = value;
					} else if( isStruct( value ) ) {
						target[ i ] = target[ i ] ?: {};
						mergeData( target[ i ], value )
					} else if( isArray( value ) ) {
						target[ i ] = target[ i ] ?: [];
						mergeData( target[ i ], value )
					}	
				}
			}
		}
		return target;

	}

}
