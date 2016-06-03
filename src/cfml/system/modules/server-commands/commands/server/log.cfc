/**
 * Show log for embedded server.  Run command from the web root of the server, or use the short name.
 * .
 * {code:bash}
 * server log
 * server log name=serverName
 * {code}
 **/
component {

	property name="serverService" inject="ServerService";

	/**
	 * Show server log
	 *
	 * @name.hint the short name of the server
	 * @name.optionsUDF serverNameComplete
	 * @directory.hint web root for the server
	 * @serverConfigFile The path to the server's JSON file.
	 **/
	function run(
		string name,
		string directory,
		String serverConfigFile
		 ){
		if( !isNull( arguments.directory ) ) {
			arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
		} 
		if( !isNull( arguments.serverConfigFile ) ) {
			arguments.serverConfigFile = fileSystemUtil.resolvePath( arguments.serverConfigFile );
		}		
		var serverDetails = serverService.resolveServerDetails( arguments );
		var serverInfo = serverDetails.serverInfo;

		// Verify server info
		if( serverDetails.serverIsNew ){
			error( "The server you requested was not found.", "You can use the 'server list' command to get all the available servers." );
		}
		
		var logfile = serverInfo.logdir & "/server.out.txt";
		if( fileExists( logfile) ){
			return fileRead( logfile );
		} else {
			print.boldRedLine( "No log file found for '#serverInfo.webroot#'!" )
				.line( "#logFile#" );
		}
	}

	
	function serverNameComplete() {
		return serverService.getServerNames();
	}
	
}
