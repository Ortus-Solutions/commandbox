/**
 * Remove a property out of the box.json for this package.  Command must be executed from the root
 * directory of the package where box.json lives.
 * Nested attributes may be set by specifying dot-delimited names or using array notation.
 * .
 * {code:bash}
 * package clear description
 * {code}
 * .
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	property name="packageService" inject="PackageService"; 
	
	/**  
	 * @property.hint Name of the property to clear 
	 * @property.optionsUDF completeProperty
	 **/
	function run( required string property ) {
		
		// This will make each directory canonical and absolute		
		var directory = getCWD();
				
		// Check and see if box.json exists
		if( !packageService.isPackage( directory ) ) {
			return error( 'File [#packageService.getDescriptorPath( directory )#] does not exist.  Use the "init" command to create it.' );
		}
		
		if( arguments.property == 'name' ) {
			return error( '[name] is a required property and cannot be cleared.' );			
		}
		if( arguments.property == 'slug' ) {
			return error( '[slug] is a required property and cannot be cleared.' );			
		}
		var boxJSON = packageService.readPackageDescriptorRaw( directory );
		
		// See if this string ends with array brackets containing a number greater than 1. Ex: test[3]
		var search = reFind( "\[\s*([1-9][0-9]*)\s*\]$", property, 1, true );
		
		// Deal with array index
		if( search.pos[1] ) {
			// Index to remove
			var arrayIndex = mid( property, search.pos[2], search.len[2] );
			// Path to the array
			var theArray = left( property, search.pos[1]-1 );
			
			// Verify the full path exists (including the array index)
			var fullPropertyName = 'boxJSON.#property#';
			if( !isDefined( fullPropertyName ) ) {
				return error( '#arguments.property# does not exist.' );
			}
			// Get the array reference
			var fullPropertyName = 'boxJSON.#theArray#';
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
			var fullPropertyName = 'boxJSON.#everythingBut#';
			if( !isDefined( fullPropertyName ) ) {
				return error( '#arguments.property# does not exist.' );
			}
			// Get a refernce to the containing struct
			var propertyValue = evaluate( fullPropertyName );
			// Remove the key			
			structDelete( propertyValue, last );
		// Else just a simple propery name
		} else {
			// Make sure it exists
			if( !structKeyExists( boxJSON, arguments.property ) ) {
				return error( '#arguments.property# does not exist.' );
			}
			// Remove it
			structDelete( boxJSON, arguments.property );
		}
		
		print.greenLine( 'Removed #arguments.property#' );
				
		// Write the file back out.
		PackageService.writePackageDescriptor( boxJSON, directory );
			
	}

	// Dynamic completion for property name based on contents of box.json
	function completeProperty() {
		var directory = fileSystemUtil.resolvePath( '' );
		return packageService.completeProperty( directory );				
	}
	
}