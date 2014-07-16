/**
 * Initialize a package in the current directory by creating a default box.json file.
 * Pass in an arguments you want and a property in the box.json will be initialized with the 
 * same name as the argument name using the argument value. 
 * 
 * init
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="init" excludeFromHelp=false {

	property name="PackageService" inject="PackageService";

	/**
	 * @name.hint The humnan-readable name for this package 
	 * @slug.hint The ForgeBox slug for this package (no spaces or special chars)
	 **/
	function run( name='myApplication', slug='mySlug' ) {
		
		// This will make each directory canonical and absolute
		var directory = getCWD();
		
		// Read current box.json if it exists, otherwise, get a new one
		var boxJSON = PackageService.readPackageDescriptor( directory );
		
		// Don't use these defaults if the existing box.json already has something useful
		if( len( boxJSON.name ) && arguments.name == 'myApplication' ) {
			structDelete( arguments, 'name' );
		}		
		if( len( boxJSON.slug ) && arguments.slug == 'mySlug' ) {
			structDelete( arguments, 'slug' );
		}
				
		print.greenLine( 'Package Initialized!' );
		
		// Append any values passed here in
		for( var arg in arguments ) {
			var fullPropertyName = 'boxJSON.#arg#';
			var propertyValue = arguments[ arg ];
			if( isJSON( propertyValue ) ) {
				evaluate( '#fullPropertyName# = deserializeJSON( arguments[ arg ] )' );				
			} else {
				evaluate( '#fullPropertyName# = arguments[ arg ]' );				
			}
			print.greenLine( 'Set #arg# = #arguments[ arg ]#' );
		}
			
		// Write the file back out
		PackageService.writePackageDescriptor( boxJSON, directory );
		
		print.greenLine( 'Created ' & directory & '/box.json' );
			
	}
}