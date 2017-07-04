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
component {

	property name="packageService" inject="PackageService";
	property name="JSONService" inject="JSONService";

	/**
	 * @property.hint Name of the property to clear
	 * @property.optionsUDF completeProperty
	 * @system.hint When true, show box.json data in the global CommandBox folder
	 **/
	function run( required string property, boolean system=false ) {

		if( arguments.system ) {
			var directory = expandPath( '/commandbox' );
		} else {
			var directory = getCWD();
		}

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

		try {
			JSONService.clear( boxJSON, arguments.property );
		} catch( JSONException var e ) {
			error( e.message );
		} catch( any var e ) {
			rethrow;
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
