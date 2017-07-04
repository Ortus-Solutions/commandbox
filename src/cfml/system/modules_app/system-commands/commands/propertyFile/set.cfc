/**
 * Set property into a property file.
 * .
 * {code:bash}
 * propertyFile set name=mySetting
 * {code}
 *
 **/
component {

	/**
	 * @propertyFilePath The path to the property file to interact with
	 * @propertyName The name of the property to set
	 * @propertyValue The value of the property to set
	 **/
	function run(
		required string propertyFilePath,
		required string propertyName,
		required string propertyValue
		) {

			// This will make each directory canonical and absolute
			propertyFilePath = fileSystemUtil.resolvePath( propertyFilePath );

			// Create and load property file object
			propertyFile( propertyFilePath )
				.set( propertyName, propertyValue )
				.store();

			print
				.greenLine( 'Property set!' )
				.line( propertyName & ' = ' & propertyValue );

	}

}