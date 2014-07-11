/**
 * Use this command to view values set in box.json for this package.  Command must be executed from the root
 * directory of the package where box.json lives, or the location of box.json must be specified.
 * Nested attributes may be accessed by specifying dot-delimited names
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
	 * @directory.hint The directory to look for box.json. Defaults to current working directory
	 **/
	function run( required string property, directory="" ) {
		
		// This will make each directory canonical and absolute		
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
				
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
		arguments.directory = fileSystemUtil.resolvePath( '' );
		var props = [];
		
		// Check and see if box.json exists
		var boxJSONPath = arguments.directory & '/box.json';
		if( fileExists( boxJSONPath ) ) {
			boxJSON = packageService.readPackageDescriptor( arguments.directory );
			props = addProp( props, '', boxJSON );			
		}
		return props;		
	}
	
	// Recursive function to crawl box.json and create a string that represents each property.
	private function addProp( props, prop, boxJSON ) {
		var propValue = ( len( prop ) ? evaluate( 'boxJSON.#prop#' ) : boxJSON );
		
		if( isStruct( propValue ) ) {
			// Add all of this struct's keys
			for( var thisProp in propValue ) {
				var newProp = listAppend( prop, thisProp, '.' );
				props.append( newProp );
				props = addProp( props, newProp, boxJSON );
			}			
		}
		
		if( isArray( propValue ) ) {
			// Add all of this array's indexes
			var i = 0;
			while( ++i <= propValue.len() ) {
				var newProp = '#prop#[#i#]';
				props.append( newProp );
				props = addProp( props, newProp, boxJSON );
			}
		}
		
		return props;
	}

}