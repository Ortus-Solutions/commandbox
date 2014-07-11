/**
 * Use this command to view values set in box.json for this package.  Command must be executed from the root
 * directory of the package where box.json lives.
 * Nested attributes may be accessed by specifying dot-delimited names or using array notation.
 * If the accessed property is a complex value, the JSON representation will be displayed
 * .
 * # outputs package name
 * package show name
 * .
 * # outputs package keywords
 * package show keywords
 * .
 * # outputs testbox runner(s)
 * package show testbox.runner
 * .
 * # outputs the first testbox notify E-mail
 * package show testbox.notify.emails[1]
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
		arguments.directory = fileSystemUtil.resolvePath( '' );
				
		// Check and see if box.json exists
		var boxJSONPath = arguments.directory & '/box.json';
		if( !fileExists( boxJSONPath ) ) {
			return error( 'File [#boxJSONPath#] does not exist.  Use the "init" command to create it.' );
		}
		
		boxJSON = packageService.readPackageDescriptor( arguments.directory );
		
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