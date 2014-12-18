/**
 * Updates all of the packages in your project that have new versions available.  Run this command from the root of the package.
 * .
 * {code:bash}
 * update
 * {code}
 * .
 * You can also pull a list of all outdated packages with the "outdated" command
 * and update them one at a time by passing one or more slugs in a comma-delimted list.
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
component extends="commandbox.system.BaseCommand" aliases="update" excludeFromHelp=false {
	
	processingdirective pageEncoding='UTF-8';
	
	// DI
	property name="packageService" 	inject="PackageService";	
	property name="forgeBox" 		inject="ForgeBox";
	property name="semanticVersion" inject="semanticVersion";
	
	/**  
	* Update all or one outdated dependencies 
	* @slug A comma-delimmited list of slugs to update. Pass nothing to update all packages.
	* @verbose Outputs additional information about each package
	* @force Forces an update without confirmations
	**/
	function run( string slug="", boolean verbose=false, boolean force=false ) {
		
		// package check
		if( !packageService.isPackage( getCWD() ) ) {
			return error( '#getCWD()# is not a package!' );
		}
		
		// echo output
		print.yellowLine( "Resolving Dependencies, please wait..." ).toConsole();

		// build dependency tree
		var aOutdated = packageService.getOutdatedDependencies( directory=getCWD(), print=print, verbose=arguments.verbose );

		// inflate slugs if found, else default to outdated found above
		if( len( arguments.slug ) ){
			aOutdated = listToArray( arguments.slug );
		}

		// Advice initial notice
		if( aOutdated.len() ){
			print.green( 'Found ' )
				.boldGreen( '(#aOutdated.len()#)' )
				.green( ' Outdated Dependenc#( aOutdated.len()  == 1 ? 'y' : 'ies' )# ' )
				.line()
				.toConsole();
			printDependencies( data=aOutdated, verbose=arguments.verbose );
			if( !arguments.force && !confirm( "Would you like to update the dependencies? (yes/no)" ) ){
				return;
			}
		} else {
			print.boldYellowLine( 'There are no outdated dependencies!' );
			return;
		}

		// iterate and update
		for( var dependency in aOutdated ){
			print.magentaLine( "Starting update of #dependency.slug# ").toConsole();
			// remove cache for package
			runCommand( "artifacts remove package=#dependency.slug# --force" );
			// install it
			runCommand( "install slug=#dependency.slug# verbose=#arguments.verbose# --force" );
		}
		
	}

	/**
	* Pretty print dependencies
	*/
	private function printDependencies( required array data, boolean verbose ) {
		
		for( var dependency in arguments.data ){
			// print it out
			print[ ( dependency.dev ? 'boldYellow' : 'bold' ) ]( '* #dependency.slug# (#dependency.version#)' )
				.boldRedLine( ' ─> new version: #dependency.newVersion#' )
				.toConsole();
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

}