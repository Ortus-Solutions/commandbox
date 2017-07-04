/**
 * Remove a property from a property file.
 * .
 * {code:bash}
 * propertyFile clear my.name
 * {code}
 *
 **/
component {

	/**
	 * @propertyFilePath The path to the property file to interact with
	 * @propertyName The name of the property to clear
	 **/
	function run(
		required string propertyFilePath,
		required string propertyName
		) {

			// This will make each directory canonical and absolute
			propertyFilePath = fileSystemUtil.resolvePath( propertyFilePath );

			// Create and load property file object
			propertyFile( propertyFilePath )
				.remove( propertyName )
				.store();

			print
				.greenLine( 'Property removed!' )
				.line( propertyName );

	}

}