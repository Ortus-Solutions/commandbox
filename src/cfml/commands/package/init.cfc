/**
 * Initialize a package in the current directory by creating a default box.json file.
 * This command will interview you about your package
 * .
 * {code:bash}
 * init
 * {code}
 * .
 * Pass in an arguments you want and a property in the box.json will be initialized with the 
 * same name as the argument name using the argument value.
 * {code:bash}
 * init name="My App" slug=myApp version=1.0.0.0
 * {code}
 *
 **/
component extends="commandbox.system.BaseCommand" aliases="init" excludeFromHelp=false {

	// DI
	property name="PackageService" 	inject="PackageService";

	/**
	 * @name The human-readable name for this package 
	 * @slug The ForgeBox or unique slug for this package (no spaces or special chars)
	 * @version The version for this package, please use semantic versioning - 0.0.0
	 * @private Would you like to mark your package as private, which prevents it to submit it to ForgeBox
	 * @shortDescription A short description for the package
	 * @author The author of the package, you!
	 * @keywords A nice list of keywords that describe your package
	 * @homepage Your package's homepage URL
	 * @ignoreList add commonly ignored files to the package's ignore list
	 **/
	function run( 
		required name, 
		required slug,
		required version,
		required boolean private,
		required shortDescription,
		required author,
		required keywords,
		required homepage,
		required boolean ignoreList
	){
		
		// This will make each directory canonical and absolute
		var directory = getCWD();
		
		// Read current box.json if it exists, otherwise, get a new one
		var boxJSON = PackageService.readPackageDescriptor( directory );

		// Defaults to arguments
		if( !len( arguments.name ) ){ arguments.name = "My Package"; }
		if( !len( arguments.slug ) ){ arguments.slug = "my-package"; }
		if( !len( arguments.version ) ){ arguments.version = "0.0.0"; }
		if( !len( arguments.shortDescription ) ){ arguments.shortDescription = "A nice package"; }
		
		// Don't use these defaults if the existing box.json already has something useful
		if( len( boxJSON.name ) && arguments.name == 'My Package' ) {
			structDelete( arguments, 'name' );
		}		
		if( len( boxJSON.slug ) && arguments.slug == 'my-package' ) {
			structDelete( arguments, 'slug' );
		}

		// Ignore List
		if( arguments.ignoreList ){
			arguments[ "ignore" ] = serializeJSON( [ '**/.*', 'test', 'tests' ] );
		}
		// Cleanup the argument so it does not get written.
		structDelete( arguments, "ignoreList" );

		// Append any values passed here in
		for( var arg in arguments ) {
			var fullPropertyName = 'boxJSON.#arg#';
			var propertyValue = arguments[ arg ];
			if( isJSON( propertyValue ) ) {
				evaluate( '#fullPropertyName# = deserializeJSON( arguments[ arg ] )' );				
			} else {
				evaluate( '#fullPropertyName# = arguments[ arg ]' );				
			}
			print.blueLine( 'Set #arg# = #arguments[ arg ]#' );
		}
			
		// Write the file back out
		PackageService.writePackageDescriptor( boxJSON, directory );
		
		// Info message
		print.yellowLine( 'Package Initialized & Created ' & directory & '/box.json' ).toConsole();
	}
}