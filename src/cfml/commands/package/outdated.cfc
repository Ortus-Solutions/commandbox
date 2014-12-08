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
	 * @verbose.hint Outputs additional informaiton about each package
	 * @json.hint Outputs results as JSON 
	 **/
	function run( boolean verbose=false, boolean JSON=false ) {
		// package check
		if( !packageService.isPackage( getCWD() ) ) {
			return error( '#getCWD()# is not a package!' );
		}
		// build dependency tree
		var tree = packageService.buildDependencyHierarchy( getCWD() );

		// echo output
		print.yellowLine( "Resolving Dependencies, please wait..." ).toConsole();

		// Global outdated check bit
		var outdatedDependencies = 0;
		// Outdated check closure
		var outdatedCheck 	= function(slug, value){
			// Verify in ForgeBox
			var fbData 		= forgebox.getEntry( arguments.slug );
			// Verify if we are outdated, internally isNew() parses the incoming strings
			if( semanticVersion.isNew( current=value.version, target=fbData.version ) ){
				value.isOutdated 	= true;
				value.newVersion 	= fbData.version;
				outdatedDependencies++;
			} else {
				value.isOutdated = false;
				value.newVersion = "";
			}

			// verbose output
			if( verbose ){
				print.yellowLine( "* #arguments.slug# (#value.version#) -> ForgeBox Version: (#fbdata.version#)" )
					.boldRedLine( value.isOutdated ? " ** #arguments.slug# is Outdated" : "" )
					.toConsole();
			}

			// Do we have more dependencies, go down the tree in parallel
			if( structCount( value.dependencies ) ){
				structEach( value.dependencies, outdatedCheck , true );
			}
		};

		// Verify dependency graph in parallel
		structEach( tree.dependencies, outdatedCheck , true );
		
		// JSON output
		if( arguments.JSON ) {
			print.line( formatterUtil.formatJson( serializeJSON( tree ) ) );
			return;			
		}

		// normal output
		if( outdatedDependencies gt 0 ){
			print.green( 'Found ' )
				.boldGreen( '(#outdatedDependencies#)' )
				.green( ' Outdated Dependencies for ' )
				.boldCyanLine( "#tree.name# (#tree.version#)" )
				.line();
			printDependencies( parent=tree, verbose=arguments.verbose );
			print.line().cyanLine( "Run the 'update' command to update the outdated dependencies to their latest version." );
		} else {
			print.green( 'There are no outdated dependencies for ' ).boldCyanLine( "#tree.name# (#tree.version#)" );
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