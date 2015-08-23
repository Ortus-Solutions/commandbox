/**
 * Verifies versions of all dependencies of a package recursivley.  Run this command from the root of the package.
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
component extends="commandbox.system.BaseCommand" aliases="outdated" excludeFromHelp=false {
	
	processingdirective pageEncoding='UTF-8';
	
	// DI
	property name="packageService" 	inject="PackageService";
	property name="semanticVersion" inject="semanticVersion";
	
	/**  
	 * @verbose.hint Outputs additional information about each package
	 * @json.hint Outputs results as JSON 
	 **/
	function run( boolean verbose=false, boolean JSON=false ) {
				
		if( arguments.JSON ) {
			arguments.verbose = false;
		}
		
		// package check
		if( !packageService.isPackage( getCWD() ) ) {
			return error( '#getCWD()# is not a package!' );
		}
		
		// echo output
		if( !arguments.JSON ) {
			print.yellowLine( "Resolving Dependencies, please wait..." ).toConsole();
		}

		// build dependency tree
		var aOutdatedDependencies = packageService.getOutdatedDependencies( directory=getCWD(), print=print, verbose=arguments.verbose );

		// JSON output
		if( arguments.JSON ) {
			print.line( formatterUtil.formatJson( serializeJSON( aOutdatedDependencies ) ) );
			return;			
		}

		// normal output
		if( aOutdatedDependencies.len() gt 0 ){
			print.green( 'Found ' )
				.boldGreen( '(#aOutdatedDependencies.len()#)' )
				.green( ' Outdated Dependenc#( aOutdatedDependencies.len()  == 1 ? 'y' : 'ies' )# ' )
				.line();
			printDependencies( data=aOutdatedDependencies, verbose=arguments.verbose );
			print.line().cyanLine( "Run the 'update' command to update all the outdated dependencies to their latest version or use 'update {slug}' to update a specific dependency" );
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