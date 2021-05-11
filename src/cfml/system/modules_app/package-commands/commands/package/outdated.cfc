/**
 * Verifies versions of all dependencies of a package recursively.  Run this command from the root of the package.
 * Package installed from HTTP(S) and Git endpoints will always show as outdated.
 * .
 * {code:bash}
 * outdated
 * {code}
 * .
 * Get additional details with the --verbose flag
 * .
 * {code:bash}
 * outdated --verbose
 * {code}
 * .
 * Get output in JSON format with the --JSON flag.  JSON output always includes verbose details
 * .
 * {code:bash}
 * outdated --JSON
 * {code}
 **/
component aliases="outdated" {

	processingdirective pageEncoding='UTF-8';

	// DI
	property name="packageService" 	inject="PackageService";
	property name="semanticVersion" inject="semanticVersion@semver";

	/**
	 * @verbose.hint Output additional information about each package
	 * @json.hint Output results as JSON
	 * @system.hint Check the global CommandBox module's folder
	 **/
	function run(
		boolean verbose=false,
		boolean JSON=false,
		boolean system=false ) {

		if( arguments.JSON ) {
			arguments.verbose = false;
		}

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
		if( !arguments.JSON ) {
			print.yellowLine( "Resolving Dependencies, please wait..." ).toConsole();
		}

		// build dependency tree
		var aAllDependencies = packageService.getOutdatedDependencies( directory=directory, print=print, verbose=arguments.verbose );
		var aOutdatedDependencies = aAllDependencies.filter( (d)=>d.isOutdated );

		// JSON output
		if( arguments.JSON ) {
			print.line( aAllDependencies.filter( (d)=>d.isOutdated ) );
			return;
		}

		if( aAllDependencies.len() ) {
			print.table(
				aAllDependencies.map( ( d ) => {
					return [
						d.slug & ( d.endpointName contains 'forgebox' ? '@' & d.version : ' (#d.endpointName#)' ),
						d.packageVersion,
						{ 'value': d.newVersion, 'options': d.isOutdated ? 'boldWhiteOnRed' : 'white' },
						{ 'value': d.latestVersion, 'options': d.isLatest ? 'white' : 'boldWhiteOnOrange3' },
						d.location
						]
					} ),
					"",
					[ 'Package', 'Installed', 'Update', 'Latest', 'Location' ]
			);
			print.text( 'Key: ' ).boldWhiteOnRed( 'Update Available' ).text( '   ' ).boldWhiteOnOrange3line( 'Major Update Available' ).line();
		}

		// normal output
		if( aOutdatedDependencies.len() gt 0 ){

			print.line()
				.green( 'Found ' )
				.boldGreen( '(#aOutdatedDependencies.len()#)' )
				.green( ' Outdated Dependenc#( aOutdatedDependencies.len()  == 1 ? 'y' : 'ies' )# ' )
				.line();
			printDependencies( data=aOutdatedDependencies, verbose=arguments.verbose );
			print
				.line()
				.cyanLine( "Run the 'update' command to update all the outdated dependencies to their latest version." )
				.cyanLine( "Or use 'update {slug}' to update a specific dependency" );
		} else {
			print.blueLine( 'There are no outdated dependencies!' );
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
					print[ ( dependency.dev ? 'yellowLine' : 'line' ) ]( dependency.name );
				}
				if( len( dependency.shortDescription ) ) {
					print[ ( dependency.dev ? 'yellowLine' : 'line' ) ]( dependency.shortDescription );
				}
				print.line();
			} // end verbose?
		} // end for
	}

}
