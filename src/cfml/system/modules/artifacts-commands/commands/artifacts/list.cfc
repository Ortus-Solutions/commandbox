/**
 * List all packages in the CommandBox artifact cache.
 * .
 * {code:bash}
 * artifacts list
 * {code}
 * .
 * Use the "package" parameter to show results for a specific package.
 * {code:bash}
 * artifacts list coldbox-platform
 * {code}
 * 
 **/
component {
	
	// DI
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
		
		print.boldBlueLine( "Found #results.count()# artifact(s) (#artifactService.getArtifactDir()#)" );

		for( var package in results ) {
			print.boldCyanLine( package & " - #results[ package ].size()# version(s)" );
			for( var ver in results[ package ] ) {
				print.yellowLine( "  *#ver#" );				
			}
		}
			
	}

}