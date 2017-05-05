/**
 * Description of command
 **/
component {
	
	/**
	 * 
	 **/
	function run(  ) {
		
		// Clear screen
		command( 'cls' ).run();
		
		// Start watcher
		watch()
			.paths( '**.cfc' )
			.inDirectory( getCWD() )
			.onChange( function() {
				command( 'cls' ).run();
				command( 'testbox run' ).run();
			} )
			.start();
	}

}