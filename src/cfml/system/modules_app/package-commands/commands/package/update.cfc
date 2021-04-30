/**
 * Updates all of the packages in your project that have new versions available.  Run this command from the root of the package.
 * Package installed from HTTP(S) and Git endpoints will always be updated.
 * .
 * {code:bash}
 * update
 * {code}
 * .
 * You can also pull a list of all outdated packages with the "outdated" command
 * and update them one at a time by passing one or more slugs in a comma-delimited list.
 * .
 * {code:bash}
 * update coldbox
 * update cbstorages,cborm,cbvalidation
 * {code}
 * .
 * Get additional details with the --verbose flag
 * .
 * {code:bash}
 * update --verbose
 * {code}
 * .
 * If you are automating this command, use the "force" flag to skip the confirmation prompt.
 * .
 * {code:bash}
 * update coldbox --force
 * {code}
 **/
component aliases="update" {

	processingdirective pageEncoding='UTF-8';

	// DI
	property name="packageService" 	inject="PackageService";

	/**
	* Update all or one outdated dependencies
	* @slug A comma-delimited list of slugs to update. Pass nothing to update all packages.
	* @slug.optionsUDF slugComplete
	* @verbose Output additional information about each package
	* @force Update without confirmations
	* @system.hint Update packages in the global CommandBox module's folder
	**/
	function run(
		string slug="",
		boolean verbose=false,
		boolean force=false,
		boolean system=false ) {

		if( arguments.system ) {
			var directory = expandPath( '/commandbox' );
		} else {
			var directory = getCWD();
		}

		// package check
		if( !packageService.isPackage( directory ) ) {
			return error( '#directory# is not a package!' );
		}

		// echo output
		print.yellowLine( "Resolving Dependencies, please wait..." ).toConsole();

		// build dependency tree
		 var aAllDependencies = packageService.getOutdatedDependencies(
		 	directory    = directory,
		 	print        = print,
		 	verbose      = arguments.verbose,
		 	includeSlugs = arguments.slug
		 );
		 
		 if( len( slug ) && !aAllDependencies.len() ) {
		 	error( message='Package(s) [#slug#] not found.', detail='Use "outdated" to see what packages are available to update.  Only pass the pacakge name to this command.' );
		 }
		 
		var dependenciesToUpdate = aAllDependencies.filter( (d)=>d.isOutdated ); 
		
		if( aAllDependencies.len() ) {
			print.table(
				[ 'Package', 'Installed', 'Update', 'Latest', 'Location' ],
				aAllDependencies.map( ( d ) => {
					return [
						d.slug & ( d.endpointName contains 'forgebox' ? '@' & d.version : ' (#d.endpointName#)' ),
						d.packageVersion,
						{ 'value': d.newVersion, 'options': d.isOutdated ? 'boldWhiteOnRed' : 'white' },
						{ 'value': d.latestVersion, 'options': d.isLatest ? 'white' : 'boldWhiteOnOrange3' },
						d.location
					]
				} )
			);
			print.text( 'Key: ' ).boldWhiteOnRed( 'Update Available' ).text( '   ' ).boldWhiteOnOrange3line( 'Major Update Available' ).line();
		}
		
		// Advice initial notice
		if( dependenciesToUpdate.len() ){			
			print.green( 'Found ' )
				.boldGreen( '(#dependenciesToUpdate.len()#)' )
				.green( ' Outdated Dependenc#( dependenciesToUpdate.len()  == 1 ? 'y' : 'ies' )# ' )
				.line()
				.toConsole();
			printDependencies( data=dependenciesToUpdate, verbose=arguments.verbose );
			if( !arguments.force && !confirm( "Would you like to update the dependencies? (yes/no)" ) ){
				return;
			}
		} else {
			print.blueLine( 'There are no outdated dependencies!' );
			return;
		}

		// iterate and update
		for( var dependency in dependenciesToUpdate ){

			// Contains an endpoint
			if( dependency.version contains ':' ) {
				var oldID = dependency.version;
				var newID = OldID;
			} else {
				var oldID = dependency.slug & '@' & dependency.Version;
				var newID = dependency.slug & '@' & dependency.newVersion;
			}

			// install it
			command( 'install' )
				.params(
					ID=newID,
					verbose=arguments.verbose,
					directory=dependency.directory )
				.flags( 'force', '!save' )
				.run( echo=arguments.verbose )
		}

	}

	/**
	* Pretty print dependencies
	*/
	private function printDependencies( required array data, boolean verbose ) {

		for( var dependency in arguments.data ){
			// print it out
			print.line( '* #dependency.slug#', ( dependency.dev ? 'boldYellow' : 'bold' ) );
			// verbose data
			if( arguments.verbose ) {
				if( len( dependency.name ) ) {
					print[ ( dependency.dev ? 'yellowLine' : 'line' ) ]( dependency.name ).toConsole();
				}
				if( len( dependency.shortDescription ) ) {
					print[ ( dependency.dev ? 'yellowLine' : 'line' ) ]( dependency.shortDescription ).toConsole();
				}
				print.line().toConsole();
			} // end verbose?
		} // end for
	}


	// Auto-complete list of slugs
	function slugComplete() {
		var results = [];
		var directory = getCWD();

		if( packageService.isPackage( directory ) ) {
			var BoxJSON = packageService.readPackageDescriptor( directory );
			results.append( BoxJSON.installPaths.keyArray(), true );
		}

		return results;
	}
}
