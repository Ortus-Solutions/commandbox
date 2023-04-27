/**
 * Lists all dependencies of a package recursively.  Run this command from the root of the package.
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
 * Limit how many levels deep the list shows.  See all top level packages like so:
 * .
 * {code:bash}
 * list depth=1
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
	property name="_print" inject="print";

	/**
	 * @verbose Outputs additional information about each package
	 * @json Outputs results as JSON
	 * @system List packages from the global CommandBox module's folder
	 * @depth how deep to climb down the rabbit hole.  A value of 0 means infinite depth
	 **/
	function run(
		boolean verbose=false,
		boolean JSON=false,
		boolean system=false,
		depth=0 ) {

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
		var tree = packageService.buildDependencyHierarchy( directory, depth );

		// JSON output
		if( arguments.JSON ) {
			print.line( tree );
			return;
		}
		// normal output
		print.green( 'Dependency Hierarchy for ' ).boldCyanLine( "#tree.name# (#tree.version#)" );
		print.tree( buildDependencies( tree, arguments.verbose ) );

	}

	// Massage dependency tree into just the bits we want for tree outout
	private function buildDependencies( required struct parent, boolean verbose ) {
		var deps = [:];
		for( var dependencyName in arguments.parent.dependencies ) {
			var dependency = arguments.parent.dependencies[ dependencyName ];
			var thisName = _print.bold( '#dependencyName# (#dependency.packageVersion#)', ( dependency.dev ? 'yellow' : '' ) );
			if( arguments.verbose ) {
				if( len( dependency.name ) ) {
					thisName &= chr(10) & _print.text( dependency.name, ( dependency.dev ? 'yellow' : '' ) );
				}
				if( len( dependency.shortDescription ) ) {
					thisName &= chr(10) & _print.text( dependency.shortDescription, ( dependency.dev ? 'yellow' : '' ) );
				}
			} // end verbose?
			deps[ thisName ] = buildDependencies( dependency, arguments.verbose );
		}
		return deps;
	}

}
