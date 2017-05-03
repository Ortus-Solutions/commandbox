/**
 * Description of command
 **/
component {
	
	/**
	 * 
	 **/
	function run(  ) {
		watch()
			.paths( '**.cfc' )
			.inDirectory( getCWD() )
			.onChange( function() {
				command( 'testbox run' )
					.run();
			} )
			.start();
	}

}