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
	property name="logger" inject="logbox:logger:{this}";
	
	/**
	* Constructor
	*/
	function init(){
		return this;
	}
	
	/**
	* I get a property from a deserialized JSON object and return a pretty verison of it
	*/
	function show( required any JSON, required string property ){
			
		// Convert foo.bar-baz[1] to ['foo']['bar-baz'][1]
		var tmpProperty = replace( arguments.property, '[', '.[', 'all' );
		tmpProperty = replace( tmpProperty, ']', '].', 'all' );
		var fullPropertyName = '';
		for( var item in listToArray( tmpProperty, '.' ) ) {
			if( item.startsWith( '[' ) ) {
				fullPropertyName &= item;
			} else {
				fullPropertyName &= '[ "#item#" ]';	
			}
		}
		fullPropertyName = 'arguments.JSON' & fullPropertyName;
				
		if( !isDefined( fullPropertyName ) ) {
			throw( message='Property [#arguments.property#] doesn''t exist in this package''s box.json', type="JSONException");
		}
		
		var propertyValue = evaluate( fullPropertyName );
		
		return propertyValue;
	}


	/**
	* I set a property from a deserialized JSON object and returns an array of messages regarding the word that was done.
	*/
	function set( required any JSON, required struct properties, required boolean thisAppend ){
		var results = [];
		
		for( var prop in arguments.properties ) {
			// Convert foo.bar-baz[1] to ['foo']['bar-baz'][1]
			var tmpProperty = replace( prop, '[', '.[', 'all' );
			tmpProperty = replace( tmpProperty, ']', '].', 'all' );
			var fullPropertyName = '';
			for( var item in listToArray( tmpProperty, '.' ) ) {
				if( item.startsWith( '[' ) ) {
					fullPropertyName &= item;
				} else {
					fullPropertyName &= '[ "#item#" ]';	
				}
			}
			fullPropertyName = 'arguments.JSON' & fullPropertyName;
			
			
			var propertyValue = arguments.properties[ prop ];
			if( isJSON( propertyValue ) ) {
				// We're trying to append and the target property exists
				if( thisAppend && isDefined( fullPropertyName ) ) {
					// The target property we're trying to append to
					var targetProperty = evaluate( fullPropertyName );
					// The value we want to append
					var complexValue = deserializeJSON( arguments.properties[ prop ] );
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
						results.append( '#arguments.properties[ prop ]# appended to #prop#' );
						continue;
					}
					
				}
				// If any of the ifs above fail, we'll fall back through to this
				evaluate( '#fullPropertyName# = deserializeJSON( arguments.properties[ prop ] )' );				
			} else {
				evaluate( '#fullPropertyName# = arguments.properties[ prop ]' );				
			}
			results.append( 'Set #prop# = #arguments.properties[ prop ]#' );
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
			var fullPropertyName = 'JSON.#property#';
			if( !isDefined( fullPropertyName ) ) {
				throw( message='#arguments.property# does not exist.', type="JSONException");
			}
			// Get the array reference
			var fullPropertyName = 'JSON.#theArray#';
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
			var fullPropertyName = 'JSON.#everythingBut#';
			if( !isDefined( fullPropertyName ) ) {
				throw( message='#arguments.property# does not exist.', type="JSONException");
			}
			// Get a refernce to the containing struct
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
				var newProp = '#prop#[#i#]';
				var newProp = '#safeProp#[#i#]';
				var newSafeProp = newProp;
				props.append( newProp );
				props = addProp( props, newProp, newSafeProp, targetStruct );
			}
		}
		
		return props;
	}
		
}