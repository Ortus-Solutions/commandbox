/**
 * Set property into a property file.
 * .
 * {code:bash}
 * propertyFile set myFile.properties mySetting myValue
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
			propertyFilePath = resolvePath( propertyFilePath );

			// Create and load property file object
			if( fileExists( propertyFilePath ) ){
				var pf = propertyFile( propertyFilePath );
			} else {
				var pf = propertyFile();				
			}
			pf
				.set( propertyName, propertyValue )
				.store( propertyFilePath );

			print
				.greenLine( 'Property set!' )
				.line( propertyName & ' = ' & propertyValue );

	}

}
