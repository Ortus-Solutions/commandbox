/**
 * View the contents of a .properties file
 * .
 * Output a single property, all properties, or all properties as JSON.
 * {code:bash}
 * propertyFile show
 * propertyFile show property.name.here
 * propertyFile show --JSON
 * {code}
 *
 **/
component {

	/**
	 * @propertyFilePath The path to the property file to interact with
	 * @propertyName The name of the property to show
	 * @JSON Return all the properties in the file as JSON
	 **/
	function run(
		required string propertyFilePath,
		string propertyName='',
		boolean JSON=false
		) {

			// This will make each directory canonical and absolute
			propertyFilePath = fileSystemUtil.resolvePath( propertyFilePath );

			// Create and load property file object
			var propertyFile = propertyFile( propertyFilePath );

			// JSON output takes precedence
			if( JSON ) {
				print.text( formatterUtil.formatJson( propertyFile.getAsStruct() ) );
			// Output single property
			} else if( propertyName.len() ) {
				print.text( propertyFile.get( propertyName ) );
			// Output all properties
			} else {
				var properties = propertyFile.getAsStruct();
				properties
					.each( function( i ) {
						print.line( i & ' = ' & properties[ i ] );
					} );
			}

	}

}
