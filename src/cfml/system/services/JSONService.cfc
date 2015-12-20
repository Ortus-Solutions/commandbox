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
	property name="formatterUtil" inject="Formatter";
	
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
		
		if( isSimpleValue( propertyValue ) ) {
			return propertyValue;
		} else {
			return formatterUtil.formatJson( propertyValue );			
		}
	}


	/**
	* I set a propertyiesfrom a deserialized JSON object and returns an array of messages regarding the word that was done.
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

	
}