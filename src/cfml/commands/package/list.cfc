/**
 * Lists all dependencies of a package recursivley.  Run this command from the root of the package.
 * This command lists the packages stored in each box.json even if they aren't installed.
 * Dev dependencies are shown in a lighter color
 * .
 * {code:bash}
 * package list description
 * {code}
 * .
 **/
component extends="commandbox.system.BaseCommand" aliases="list" excludeFromHelp=false {
	
	processingdirective pageEncoding='UTF-8';
	
	property name="packageService" inject="PackageService";	
	
	/**  
	 * @verbose.hint Outputs additional informaiton about each package
	 * @json.hint Outputs results as JSON 
	 **/
	function run( boolean verbose=false, boolean JSON=false ) {
		
		if( !packageService.isPackage( getCWD() ) ) {
			return error( '#getCWD()# is not a package!' );
		}
				
		var tree = packageService.buildDependencyHierarchy( getCWD() );
		
		if( arguments.JSON ) {
			print.line( formatterUtil.formatJson( serializeJSON( tree ) ) );
			return;			
		}
		
		print.boldLine( 'Dependency Hierarchy for #tree.name# (#tree.version#)' );
		printDependencies( tree );
		
	}

	private function printDependencies( required struct parent, prefix='' ) {
		var i = 0;
		var depCount = structCount( arguments.parent.dependencies );
		for( var dependencyName in arguments.parent.dependencies ) {
			var dependency = arguments.parent.dependencies[ dependencyName ];
			var childDepCount = structCount( dependency.dependencies );
			i++;
			var isLast = i == depCount;
			var branch = ( isLast ? '└' : '├' ) & '─' & ( childDepCount ? '┬' : '─' );
			print.text( prefix & branch & ' ' );
			var text = '#dependencyName# (#dependency.version#)';
			if( dependency.dev ) {
				print.line( text );
			} else {
				print.boldLine( text );
			}
			
			printDependencies( dependency, prefix & ( isLast ? '  ' : '│ ' ) );
		}
	}

}