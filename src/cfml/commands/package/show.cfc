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
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	property name="packageService" inject="PackageService";
	property name="formatterUtil" inject="Formatter"; 
	
	/**
	 * @property.hint The name of the property to show.  Can nested to get "deep" properties
	 * @property.optionsUDF completeProperty
	 **/
	function run( string property ) {
		
		// This will make each directory canonical and absolute		
		var directory = getCWD();
				
		// Check and see if box.json exists
		if( !packageService.isPackage( directory ) ) {
			return error( 'File [#packageService.getDescriptorPath( directory )#] does not exist.  Use the "init" command to create it.' );
		}
		
		boxJSON = packageService.readPackageDescriptor( directory );
		
		// Convert foo.bar-baz[1] to ['foo']['bar-baz'][1]
		var tmpProperty = replace( arguments.property, '[', '.[', 'all' );
		tmpProperty = replace( tmpProperty, ']', '].', 'all' );
		var fullPropertyName = '';
		for( var item in listToArray( tmpProperty, '.' ) ) {
			if( item.startsWith( '[' ) ) {
				fullPropertyName &= item;
			} else {
				fullPropertyName &= '[ "#item#" ]';	
			}
		}
		fullPropertyName = 'boxJSON' & fullPropertyName;
				
		if( !isDefined( fullPropertyName ) ) {
			return error( 'Property [#arguments.property#] doesn''t exist in this package''s box.json' );
		}
		
		var propertyValue = evaluate( fullPropertyName );
		
		if( isSimpleValue( propertyValue ) ) {
			print.line( propertyValue );
		} else {
			print.line( formatterUtil.formatJson( propertyValue ) );			
		}
	}

	// Dynamic completion for property name based on contents of box.json
	function completeProperty() {
		var directory = fileSystemUtil.resolvePath( '' );
		return packageService.completeProperty( directory );				
	}
}