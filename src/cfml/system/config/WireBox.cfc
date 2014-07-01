component extends="wirebox.system.ioc.config.Binder" {
	
	function configure() {

		// auto scan locations
		wirebox.scanLocations = [
			'/commandbox/system'
		];

		// scope registration
		wirebox.scopeRegistration = {
			enabled = true,
			scope   = "application",
			key		= "wireBox"
		};

		// LogBox 
		wirebox.logBoxConfig = "commandbox.system.config.LogBox";
		
		// Map CONSTANTS
		var system			= createObject( "java", "java.lang.System" );
		var homeDir			= system.getProperty( 'user.home' ) & "/.CommandBox";
		var tempDir			= homedir & "/temp";
		var artifactDir		= homedir & "/artifacts";
		var userDir			= system.getProperty( "user.dir" );
		var historyFile		= homedir & "/.history";
		var REPLHistoryFile = homedir & "/.history-repl";
		var cr				= system.getProperty( "line.separator" );
		
		map( 'system' ).toValue( system );
		map( 'homeDir' ).toValue( homeDir );
		map( 'tempDir' ).toValue( tempDir );
		map( 'userDir' ).toValue( userDir );
		map( 'artifactDir' ).toValue( artifactDir );
		map( 'historyFile' ).toValue( historyFile );
		map( 'REPLHistoryFile' ).toValue( REPLHistoryFile );
		map( 'cr' ).toValue( cr );

		// Map Java Classes
		map( 'historyFile@java' ).toJava( "jline.console.history.FileHistory" )
			.initWith( createObject( "java", "java.io.File" ).init( historyFile ) );
		map( 'REPLhistoryFile@java' ).toJava( "jline.console.history.FileHistory" )
			.initWith( createObject( "java", "java.io.File" ).init( REPLHistoryFile ) );
		
		// Map Directories
		mapDirectory( '/commandbox/system/services' );
		mapDirectory( '/commandbox/system/util' );
		
	}
	
}