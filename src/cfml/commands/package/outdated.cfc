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
	property name="forgeBox" 		inject="ForgeBox";
	property name="semanticVersion" inject="semanticVersion";
	
	/**  
	 * @verbose.hint Outputs additional information about each package
	 * @json.hint Outputs results as JSON 
	 **/
	function run( boolean verbose=false, boolean JSON=false ) {
		// package check
		if( !packageService.isPackage( getCWD() ) ) {
			return error( '#getCWD()# is not a package!' );
		}
		
		// echo output
		print.yellowLine( "Resolving Dependencies, please wait..." ).toConsole();

		// build dependency tree
		var sOutdatedData = packageService.buildOutdatedDependencyHierarchy( directory=getCWD(), print=print, verbose=arguments.verbose );

		// JSON output
		if( arguments.JSON ) {
			print.line( formatterUtil.formatJson( serializeJSON( sOutdatedData ) ) );
			return;			
		}

		// normal output
		if( sOutdatedData.count gt 0 ){
			print.green( 'Found ' )
				.boldGreen( '(#sOutdatedData.count#)' )
				.green( ' Outdated Dependenc#( sOutdatedData.count  == 1 ? 'y' : 'ies' )# for ' )
				.boldCyanLine( "#sOutdatedData.tree.name# (#sOutdatedData.tree.version#)" )
				.line();
			printDependencies( parent=sOutdatedData.tree, verbose=arguments.verbose );
			print.line().cyanLine( "Run the 'update' command to update all the outdated dependencies to their latest version or use 'update {slug}' to update a specific dependency" );
		} else {
			print.green( 'There are no outdated dependencies for ' ).boldCyanLine( "#sOutdatedData.tree.name# (#sOutdatedData.tree.version#)" );
		}
		
	}

	/**
	* Pretty print dependencies
	*/
	private function printDependencies( required struct parent, boolean verbose ) {
		var i = 0;
		var depCount = structCount( arguments.parent.dependencies );
		for( var dependencyName in arguments.parent.dependencies ) {
			var dependency 		= arguments.parent.dependencies[ dependencyName ];
			var childDepCount	= structCount( dependency.dependencies );
			i++;
			var isLast 		= ( i == depCount );
			
			// continue if not outdated
			if( !dependency.isOutdated ){ continue; }

			// print it out
			print[ ( dependency.dev ? 'boldYellow' : 'bold' ) ]( '* #dependencyName# (#dependency.version#)' )
				.boldRedLine( ' ─> new version: #dependency.newVersion#' );
						
			if( arguments.verbose ) {
				if( len( dependency.name ) ) {
					print[ ( dependency.dev ? 'yellowLine' : 'line' ) ]( dependency.name );	
				}
				if( len( dependency.shortDescription ) ) {
					print[ ( dependency.dev ? 'yellowLine' : 'line' ) ]( dependency.shortDescription );	
				}
				print.line();
			} // end verbose?
			
			printDependencies( dependency, arguments.verbose );
		}
	}

}