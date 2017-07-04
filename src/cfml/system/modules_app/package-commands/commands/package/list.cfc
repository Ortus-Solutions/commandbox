/**
 * Lists all dependencies of a package recursivley.  Run this command from the root of the package.
 * This command lists the packages stored in each box.json even if they aren't installed.
 * Dev dependencies are shown in yellow
 * .
 * {code:bash}
 * list
 * {code}
 * .
 * Get additional details with the --verbose flag
 * .
 * {code:bash}
 * list --verbose
 * {code}
 * .
 * Get output in JSON format with the --JSON flag.  JSON output always includes verbose details
 * .
 * {code:bash}
 * list --JSON
 * {code}
 **/
component aliases="list" {

	processingdirective pageEncoding='UTF-8';

	property name="packageService" inject="PackageService";

	/**
	 * @verbose.hint Outputs additional informaiton about each package
	 * @json.hint Outputs results as JSON
	 * @system.hint When true, list packages from the global CommandBox module's folder
	 **/
	function run(
		boolean verbose=false,
		boolean JSON=false,
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
		// build dependency tree
		var tree = packageService.buildDependencyHierarchy( directory );

		// JSON output
		if( arguments.JSON ) {
			print.line( formatterUtil.formatJson( serializeJSON( tree ) ) );
			return;
		}
		// normal output
		print.green( 'Dependency Hierarchy for ' ).boldCyanLine( "#tree.name# (#tree.version#)" );
		printDependencies( tree, '', arguments.verbose );

	}

	/**
	* Pretty print dependencies
	*/
	private function printDependencies( required struct parent, string prefix, boolean verbose ) {
		var i = 0;
		var depCount = structCount( arguments.parent.dependencies );
		for( var dependencyName in arguments.parent.dependencies ) {
			var dependency = arguments.parent.dependencies[ dependencyName ];
			var childDepCount = structCount( dependency.dependencies );
			i++;
			var isLast = ( i == depCount );
			var branch = ( isLast ? '└' : '├' ) & '─' & ( childDepCount ? '┬' : '─' );
			var branchCont = ( isLast ? ' ' : '│' ) & ' ' & ( childDepCount ? '│' : ' ' );

			print.text( prefix & branch & ' ' );

			print[ ( dependency.dev ? 'boldYellowline' : 'boldLine' ) ]( '#dependencyName# (#dependency.packageVersion#)' );

			if( arguments.verbose ) {
				if( len( dependency.name ) ) {
					print.text( prefix & branchCont & ' ' );
					print[ ( dependency.dev ? 'yellowLine' : 'line' ) ]( dependency.name );
				}
				if( len( dependency.shortDescription ) ) {
					print.text( prefix & branchCont & ' ' );
					print[ ( dependency.dev ? 'yellowLine' : 'line' ) ]( dependency.shortDescription );
				}
			} // end verbose?

			printDependencies( dependency, prefix & ( isLast ? '  ' : '│ ' ), arguments.verbose );
		}
	}

}