/**
 * View values set in box.json for this package.  Command must be executed from the root
 * directory of the package where box.json lives.
 * .
 * Outputs package name
 * {code}
 * package show name
 * {code}
 * .
 * Outputs package keywords
 * {code}
 * package show keywords
 * {code}
 * .
 * Nested attributes may be accessed by specifying dot-delimited names or using array notation.
 * If the accessed property is a complex value, the JSON representation will be displayed
 * .
 * Outputs testbox runner(s)
 * {code}
 * package show testbox.runner
 * {code}
 * .
 * Outputs the first testbox notify E-mail
 * {code}
 * package show testbox.notify.emails[1]
 * {code}
 * .
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	property name="packageService" inject="PackageService"; 
	
	/**
	 * @property.hint The name of the property to show.  Can nested to get "deep" properties
	 * @property.optionsUDF completeProperty
	 **/
	function run( required string property ) {
		
		// This will make each directory canonical and absolute		
		var directory = getCWD();
				
		// Check and see if box.json exists
		if( !packageService.isPackage( directory ) ) {
			return error( 'File [#packageService.getDescriptorPath( directory )#] does not exist.  Use the "init" command to create it.' );
		}
		
		boxJSON = packageService.readPackageDescriptor( directory );
		
		var fullPropertyName = 'boxJSON.#arguments.property#';
		if( !isDefined( fullPropertyName ) ) {
			return error( 'Property [#arguments.property#] doesn''t exist in this package''s box.json' );
		}
		
		var propertyValue = evaluate( fullPropertyName );
		
		if( isSimpleValue( propertyValue ) ) {
			print.line( propertyValue );
		} else {
			print.line( serializeJSON( propertyValue ) );			
		}
	}

	// Dynamic completion for property name based on contents of box.json
	function completeProperty() {
		var directory = fileSystemUtil.resolvePath( '' );
		return packageService.completeProperty( directory );				
	}
}