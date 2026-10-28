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
 * package set name=myPackage version="1.0.0" author="Brad Wood" slug="foo"
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
component {

	property name="packageService" inject="PackageService";
	property name="JSONService" inject="JSONService";

	/**
	 * This param is a dummy param just to get the custom completor to work.
	 * The actual parameter names will be whatever property name the user wants to set
	 * @_.hint Pass any number of property names in followed by the value to set
	 * @_.optionsUDF completeProperty
	 * @append.hint Append struct/array setting, instead of overwriting.
	 * @system.hint Set property in box.json in the global CommandBox folder
	 **/
	function run( _, boolean append=false, boolean system=false ) {
		var thisAppend = arguments.append;

		if( arguments.system ) {
			var directory = expandPath( '/commandbox' );
		} else {
			var directory = getCWD();
		}

		// Remove dummy args
		structDelete( arguments, '_' );
		structDelete( arguments, 'append' );
		structDelete( arguments, 'system' );

		// Check and see if box.json exists
		if( !packageService.isPackage( directory ) ) {
			return error( 'File [#packageService.getDescriptorPath( directory )#] does not exist.  Use the "init" command to create it.' );
		}
		// Read without defaulted values
		var boxJSON = packageService.readPackageDescriptorRaw( directory );

		var results = JSONService.set( boxJSON, arguments, thisAppend );

		// Write the file back out.
		PackageService.writePackageDescriptor( boxJSON, directory );

		for( var message in results ) {
			print.greeLine( message );
		}

	}

	// Dynamic completion for property name based on contents of box.json
	function completeProperty() {
		var directory = resolvePath( '' );
		// all=true will cause "package set" to prompt all possible box.json properties
		return packageService.completeProperty( directory, true, true );
	}
}
