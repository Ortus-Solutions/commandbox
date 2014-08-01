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
		
		// Setup constants
		var system					= createObject( "java", "java.lang.System" );
		var homeDir					= system.getProperty( 'user.home' ) & "/.CommandBox";
		var tempDir					= homedir & "/temp";
		var artifactDir				= homedir & "/artifacts";
		var userDir					= system.getProperty( "user.dir" );
		var commandHistoryFile		= homedir & "/.history-command";
		var REPLScriptHistoryFile 	= homedir & "/.history-repl-script";
		var REPLTagHistoryFile 		= homedir & "/.history-repl-tag";
		var cr						= system.getProperty( "line.separator" );
		var commandLocations		= [
			// This is where system commands are stored
			'/commandbox/system/commands',
			// This is where core namespace commands are stored
			'/commandbox/commands',
			// This is where user-installed commands are stored
			'/root/commands'
		];
		
		
		// map them
		map( 'system@constants' ).toValue( system );
		map( 'homeDir@constants' ).toValue( homeDir );
		map( 'tempDir@constants' ).toValue( tempDir );
		map( 'userDir@constants' ).toValue( userDir );
		map( 'artifactDir@constants' ).toValue( artifactDir );
		map( 'commandHistoryFile@constants' ).toValue( commandHistoryFile );
		map( 'REPLScriptHistoryFile@constants' ).toValue( REPLScriptHistoryFile );
		map( 'REPLTagHistoryFile@constants' ).toValue( REPLTagHistoryFile );
		map( 'cr@constants' ).toValue( cr );
		map( 'commandLocations@constants' ).toValue( commandLocations );		
		
		// Map Java Classes
		map( 'commandHistoryFile@java' ).toJava( "jline.console.history.FileHistory" )
			.initWith( createObject( "java", "java.io.File" ).init( commandHistoryFile ) )
			.asSingleton();
			
		map( 'REPLScriptHistoryFile@java' ).toJava( "jline.console.history.FileHistory" )
			.initWith( createObject( "java", "java.io.File" ).init( REPLScriptHistoryFile ) )
			.asSingleton();
			
		map( 'REPLTagHistoryFile@java' ).toJava( "jline.console.history.FileHistory" )
			.initWith( createObject( "java", "java.io.File" ).init( REPLTagHistoryFile ) )
			.asSingleton();
		
		// Map Directories
		mapDirectory( '/commandbox/system/services' );
		mapDirectory( '/commandbox/system/util' );
		
	}
	
}