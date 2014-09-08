/**
 * Set values set in box.json for this package.  Command must be executed from the root
 * directory of the package where box.json lives.
 * .
 * set package name
 * {code:bash}
 * package set name=myPackage
 * {code}
 * .
 * Nested attributes may be set by specifying dot-delimited names or using array notation.
 * If the set value is JSON, it will be stored as a complex value in the box.json.
 * .
 * set repo type
 * {code:bash}
 * package set repository.type=Git
 * {code}
 * .
 * set first testbox notify E-mail
 * {code:bash}
 * package set testbox.notify.email[1]="brad@bradwood.com"
 * {code}
 * .
 * Set multiple params at once
 * {code:bash}
 * package set name=myPackage version="1.0.0.000" author="Brad Wood" slug="foo"
 * {code}
 * .
 * Set complex value as JSON
 * {code:bash}
 * package set testbox.notify.emails="[ 'test@test.com', 'me@example.com' ]"
 * {code}
 * .
 * Structs and arrays can be appended to using the "append" parameter.
 * .
 * Add an additional contributor to the existing list
 * This only works if the property and incoming value are both of the same complex type.
 * {code:bash}
 * package set contributors="[ 'brad@coldbox.org' ]" --append
 * {code}
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	property name="packageService" inject="PackageService"; 
	
	/**
	 * This param is a dummy param just to get the custom completor to work.
	 * The actual parameter names will be whatever property name the user wants to set  
	 * @_.hint Pass any number of property names in followed by the value to set 
	 * @_.optionsUDF completeProperty  
	 * @append.hint If setting an array or struct, set to true to append instead of overwriting.
	 **/
	function run( _, boolean append=false ) {
		var thisAppend = arguments.append;
		// Remove dummy arg
		structDelete( arguments, '_' );
		structDelete( arguments, 'append' );
		
		
		// This will make each directory canonical and absolute		
		var directory = getCWD();
				
		// Check and see if box.json exists
		if( !packageService.isPackage( directory ) ) {
			return error( 'File [#packageService.getDescriptorPath( directory )#] does not exist.  Use the "init" command to create it.' );
		}
		boxJSON = packageService.readPackageDescriptor( directory );
		
		for( var arg in arguments ) {
			// Convert foo.bar-baz[1] to ['foo']['bar-baz'][1]
			var tmpProperty = replace( arg, '[', '.[', 'all' );
			tmpProperty = replace( tmpProperty, ']', '].', 'all' );
			var fullPropertyName = '';
			for( var item in listToArray( tmpProperty, '.' ) ) {
				if( item.startsWith( '[' ) ) {
					fullPropertyName &= item;
				} else {
					fullPropertyName &= '[ "#item#" ]';	
				}
			}
			fullPropertyName = 'boxJSON' & fullPropertyName;
			
			
			var propertyValue = arguments[ arg ];
			if( isJSON( propertyValue ) ) {
				// We're trying to append and the target property exists
				if( thisAppend && isDefined( fullPropertyName ) ) {
					// The target property we're trying to append to
					var targetProperty = evaluate( fullPropertyName );
					// The value we want to append
					var complexValue = deserializeJSON( arguments[ arg ] );
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
						print.greenLine( '#arguments[ arg ]# appended to #arg#' );
						continue;
					}
					
				}
				// If any of the ifs above fail, we'll fall back through to this
				evaluate( '#fullPropertyName# = deserializeJSON( arguments[ arg ] )' );				
			} else {
				evaluate( '#fullPropertyName# = arguments[ arg ]' );				
			}
			print.greenLine( 'Set #arg# = #arguments[ arg ]#' );
		}
		
		// Write the file back out.
		PackageService.writePackageDescriptor( boxJSON, directory );
			
	}

	// Dynamic completion for property name based on contents of box.json
	function completeProperty() {
		var directory = fileSystemUtil.resolvePath( '' );
		return packageService.completeProperty( directory );				
	}
}