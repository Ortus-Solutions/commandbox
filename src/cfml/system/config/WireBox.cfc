component extends="wirebox.system.ioc.config.Binder" {
	
	function configure() {

		wirebox.scanLocations = [
			'/commandbox/system'
		];
				
		var system = createObject( "java", "java.lang.System" );
		var homeDir = system.getProperty( 'user.home' ) & "/.CommandBox";
		var tempDir = homedir & "/temp";
		var userDir = system.getProperty( "user.dir" );
		var cr = system.getProperty( "line.separator" );
		 		
		map( 'system' ).toValue( system );
		map( 'homeDir' ).toValue( homeDir );
		map( 'tempDir' ).toValue( tempDir );
		map( 'userDir' ).toValue( userDir );
		map( 'cr' ).toValue( cr );
		
		mapDirectory( '/commandbox/system/services' );
		mapDirectory( '/commandbox/system/util' );
		
	}
	
}