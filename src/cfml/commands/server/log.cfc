/**
 * Show log for embedded server.  Run command from the web root of the server, or use the short name.
 * .
 * {code}
 * server log
 * server log name=serverName
 * {code}
 **/
component extends="commandbox.system.BaseCommand" excludeFromHelp=false {

	property name="serverService" inject="ServerService";

	/**
	 * Show server log
	 *
	 * @directory.hint web root for the server
	 * @name.hint short name for the server
	 **/
	function run( String directory="", String name="" ){

		// Discover by shortname or webroot
		var serverInfo = serverService.getServerInfoByDiscovery( arguments.directory, arguments.name );

		// Verify server info
		if( structIsEmpty( serverInfo ) ){
			error( "The server you requested to log was not found (webroot=#arguments.directory#, name=#arguments.name#)." );
			print.line( "You can use the 'server status showAll=true' command to get all the available servers." );
			return;
		}

		var logfile = serverInfo.logdir & "/server.out.txt";
		if( fileExists( logfile) ){
			return fileRead( logfile );
		} else {
			print.boldRedLine( "No log file found for '#webroot#'!" )
				.line( "#logFile#" );
		}
	}

}