/**
 * Lists all packages in the artifact cache
 *
 * artifacts list
 *
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	property name='artifactService' inject='artifactService'; 

	/**
	 * @package.hint An optional package to filter the results by
	 **/
	function run( package='' ) {
		var results = artifactService.listArtifacts( arguments.package );
		
		if( !results.count() ) {
			print.yellowLine( 'No artifacts found in cache.' );
			return;
		}
		
		print.line();
		for( var package in results ) {
			for( var ver in results[ package ] ) {
				print.line( package & ' ' & ver );				
			}
			print.line();
		}
			
	}

}