/**
 * Lists all packages in the artifact cache
 *
 * artifacts list
 *
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	property name='artifactService' inject='artifactService'; 

	/**
	 * @slug.hint An optional slug to filter the results by
	 **/
	function run( slug='' ) {
		var results = artifactService.listArtifacts( arguments.slug );
		
		if( !results.count() ) {
			print.yellowLine( 'No artifacts found in cache.' );
			return;
		}
		
		print.line();
		for( var slug in results ) {
			for( var ver in results[ slug ] ) {
				print.line( slug & ' ' & ver );				
			}
			print.line();
		}
			
	}

}