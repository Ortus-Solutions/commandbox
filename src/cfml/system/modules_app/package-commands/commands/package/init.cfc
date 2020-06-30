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
	property name="configService" inject="configService";
	property name="endpointService" inject="endpointService";

	/**
	 * @name The human-readable name for this package
	 * @slug The ForgeBox or unique slug for this package (no spaces or special chars)
	 * @version The version for this package, please use semantic versioning - 0.0.0
	 * @private Mark your package as private, so that if it is published to ForgeBox, only you can see it.
	 * @shortDescription A short description for the package
	 * @ignoreList Add commonly ignored files to the package's ignore list
	 * @wizard Run the init wizard, defaults to false
	 * @endpointName  Name of custom forgebox endpoint to use
	 * @location Where the package is located
	 * @type Type of pacakge (modules, etc)
	 **/
	function run(
		name="My Package",
		slug="my-package",
		version="0.0.0",
		boolean private=false,
		shortDescription="A sweet package",
		boolean ignoreList=true,
		string location='ForgeboxStorage',
		string type='modules',
		string endpointName,
		boolean wizard=false
	){
		
		// Check for wizard argument
		if( arguments.wizard ){
			runCommand( 'package init-wizard' );
			return;
		}

		// Clean this up so it doesn't get written as a property
		structDelete( arguments, "wizard" );
		var endpointName = arguments.endpointName;
		structDelete( arguments, "endpointName" );
		
		endpointName = endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );
		
		try {		
			var oEndpoint = endpointService.getEndpoint( endpointName );
		} catch( EndpointNotFound var e ) {
			error( e.message, e.detail ?: '' );
		}
		
		var forgebox = oEndpoint.getForgebox();
		var APIToken = oEndpoint.getAPIToken();

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

		if( structKeyExists( arguments, 'slug' ) && arguments.private ){
			if( ! len( APIToken ) ){
				print.redLine( "You've opted to create a private package, but you're not logged into ForgeBox." );
				if( confirm( 'Would you like to stop and log into ForgeBox now? ' ) ) {
					print.greenBoldLine( 'Run the "forgebox login" command to sign into your ForgeBox account and then run "init" again.' );
					return;
				} else {
					print.redLine( "You will need to update your package slug before you can publish it." );
					print.redLine( "Use the format [#arguments.slug#@USERNAME] and replace 'username' with your actual user." );
				}
			} else {

				var APITokens = oEndpoint.getAPITokens();
				var usernames = structKeyArray( APITokens );
				var foundToken = usernames.filter( function( name ){
					return APITokens[ name ] == APIToken;
				} );
				if( ! foundToken.len() ){
					print.redLine( "We're sorry, we're having problems locating your ForgeBox account.  Please `forgebox login` and try again." );
					print.redLine( "You will need to update your package slug before you can publish it." );
					print.redLine( "Use the format [#arguments.slug#@USERNAME] and replace 'username' with your actual user." );
				} else {
					arguments.slug = "#arguments.slug#@#foundToken[ 1 ]#";	
				}
			}			
		}

		// Ignore List
		if( arguments.ignoreList ){
			arguments[ "ignore" ] = serializeJSON( [ '**/.*', '/test/', '/tests/' ] );
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
			print.cyanLine( '- Set #arg# = #arguments[ arg ]#' );
		}

		// Write the file back out
		PackageService.writePackageDescriptor( boxJSON, directory );

		// Info message
		print.yellowLine( 'Package Initialized & Created ' & directory & 'box.json' ).toConsole();
	}
}
