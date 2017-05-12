/**
 * Initialize a package in the current directory by creating a default box.json file.
 * If you pass a `--wizard` flag, then the command will give you a wizard to init a package
 * .
 * {code:bash}
 * init
 * {code}
 * .
 * Init with a wizard
 * {code:bash}
 * init --wizard
 * {code}
 * .
 * Pass in an arguments you want and a property in the box.json will be initialized with the 
 * same name as the argument name using the argument value.
 * {code:bash}
 * init name="My App" slug=myApp version=1.0.0.0
 * {code}
 *
 **/
component aliases="init" {

	// DI
	property name="PackageService" 	inject="PackageService";

	/**
	 * @name The human-readable name for this package 
	 * @slug The ForgeBox or unique slug for this package (no spaces or special chars)
	 * @version The version for this package, please use semantic versioning - 0.0.0
	 * @private Would you like to mark your package as private, which prevents it to submit it to ForgeBox
	 * @shortDescription A short description for the package
	 * @ignoreList Add commonly ignored files to the package's ignore list
	 * @wizard Run the init wizard, defaults to false
	 **/
	function run( 
		name="My Package", 
		slug="my-package",
		version="0.0.0",
		boolean private=false,
		shortDescription="A sweet package",
		boolean ignoreList=true,
		boolean wizard=false
	){
		// Check for wizard argument
		if( arguments.wizard ){
			runCommand( 'package init-wizard' );
			return;
		}
				
		// Clean this up so it doesn't get written as a property
		structDelete( arguments, "wizard" );
		
		// This will make each directory canonical and absolute
		var directory = getCWD();
		
		// Read current box.json if it exists, otherwise, get a new one
		var boxJSON = PackageService.readPackageDescriptorTemplate( directory );

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
			print.magentaLine( '- Set #arg# = #arguments[ arg ]#' );
		}
			
		// Write the file back out
		PackageService.writePackageDescriptor( boxJSON, directory );
		
		// Info message
		print.yellowLine( 'Package Initialized & Created ' & directory & 'box.json' ).toConsole();
	}
}