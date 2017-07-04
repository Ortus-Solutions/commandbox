/**
 * View proprties set in box.json for this package.  Command must be executed from the root
 * directory of the package where box.json lives.  Call with no parameters to view the entire box.json
 * .
 * Outputs package name
 * {code:bash}
 * package show name
 * {code}
 * .
 * Outputs package keywords
 * {code:bash}
 * package show keywords
 * {code}
 * .
 * Nested attributes may be accessed by specifying dot-delimited names or using array notation.
 * If the accessed property is a complex value, the JSON representation will be displayed
 * .
 * Outputs testbox runner(s)
 * {code:bash}
 * package show testbox.runner
 * {code}
 * .
 * Outputs the first testbox notify E-mail
 * {code:bash}
 * package show testbox.notify.emails[1]
 * {code}
 * .
 **/
component {

	property name="packageService" inject="PackageService";
	property name="JSONService" inject="JSONService";

	/**
	 * @property.hint The name of the property to show.  Can nested to get "deep" properties
	 * @property.optionsUDF completeProperty
	 * @system.hint When true, show box.json data in the global CommandBox folder
	 **/
	function run( string property='', boolean system=false ) {

		if( arguments.system ) {
			var directory = expandPath( '/commandbox' );
		} else {
			var directory = getCWD();
		}

		// Check and see if box.json exists
		if( !packageService.isPackage( directory ) ) {
			return error( 'File [#packageService.getDescriptorPath( directory )#] does not exist.  Use the "init" command to create it.' );
		}

		// Read without defaulted values
		var boxJSON = packageService.readPackageDescriptorRaw( directory );

		try {

			var propertyValue = JSONService.show( boxJSON, arguments.property );

			if( isSimpleValue( propertyValue ) ) {
				print.line( propertyValue );
			} else {
				print.line( formatterUtil.formatJson( propertyValue ) );
			}

		} catch( JSONException var e ) {
			error( e.message );
		} catch( any var e ) {
			rethrow;
		}

	}

	// Dynamic completion for property name based on contents of box.json
	function completeProperty() {
		var directory = fileSystemUtil.resolvePath( '' );
		return packageService.completeProperty( directory );
	}
}
