/**
 * Verifies versions of all dependencies of a package recursivley.  Run this command from the root of the package.
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
	 * @verbose.hint Outputs additional information about each package
	 * @json.hint Outputs results as JSON
	 * @system.hint When true, check the global CommandBox module's folder
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
		var aOutdatedDependencies = packageService.getOutdatedDependencies( directory=directory, print=print, verbose=arguments.verbose );

		// JSON output
		if( arguments.JSON ) {
			print.line( formatterUtil.formatJson( aOutdatedDependencies ) );
			return;
		}

		// normal output
		if( aOutdatedDependencies.len() gt 0 ){
			print.green( 'Found ' )
				.boldGreen( '(#aOutdatedDependencies.len()#)' )
				.green( ' Outdated Dependenc#( aOutdatedDependencies.len()  == 1 ? 'y' : 'ies' )# ' )
				.line();
			printDependencies( data=aOutdatedDependencies, verbose=arguments.verbose );
			print
				.line()
				.cyanLine( "Run the 'update' command to update all the outdated dependencies to their latest version." )
				.cyanLine( "Or use 'update {slug}' to update a specific dependency" );
		} else {
			print.boldYellowLine( 'There are no outdated dependencies!' );
		}

	}

	/**
	* Pretty print dependencies
	*/
	private function printDependencies( required array data, boolean verbose ) {

		for( var dependency in arguments.data ){
			// print it out
			print[ ( dependency.dev ? 'boldYellow' : 'bold' ) ]( '* #dependency.slug# (#dependency.packageVersion#)' )
				.boldRedLine( ' ─> new version: #dependency.newVersion#' );
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
