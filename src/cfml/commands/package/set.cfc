/**
 * Use this command to set values set in box.json for this package.  Command must be executed from the root
 * directory of the package where box.json lives.
 * Nested attributes may be set by specifying dot-delimited names or using array notation.
 * If the set value is JSON, it will be stored as a complex value in the box.json.
 * .
 * # set package name
 * package set name=myPackage
 * .
 * # set repo type
 * package set repository.type=Git
 * .
 * # set first testbox notify E-mail
 * package set testbox.notify.email[1]="brad@bradwood.com"
 * .
 * # Set multiple params at once
 * package set name=myPackage version="1.0.0.000" author="Brad Wood" slug="foo"
 * .
 * # Set complex value as JSON
 * package set testbox.notify.emails="[ 'test@test.com', 'me@example.com' ]"
 * .
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	property name="packageService" inject="PackageService"; 
	
	/**
	 * This param is a dummy param just to get the custom completor to work.
	 * The actual parameter names will be whatever property name the user wants to set  
	 * @_.hint Pass any number of property names in followed by the value to set 
	 * @_.optionsUDF completeProperty
	 **/
	function run( _ ) {
		// Remove dummy arg
		structDelete( arguments, '_' );
		
		// This will make each directory canonical and absolute		
		var directory = fileSystemUtil.resolvePath( '' );
				
		// Check and see if box.json exists
		var boxJSONPath = directory & '/box.json';
		if( !fileExists( boxJSONPath ) ) {
			return error( 'File [#boxJSONPath#] does not exist.  Use the "init" command to create it.' );
		}
		
		boxJSON = packageService.readPackageDescriptor( directory );
		
		for( var arg in arguments ) {
			var fullPropertyName = 'boxJSON.#arg#';
			var propertyValue = arguments[ arg ];
			if( isJSON( propertyValue ) ) {
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