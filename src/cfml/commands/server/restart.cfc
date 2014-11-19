/**
 * Resstart an embedded CFML server.  Run command from the web root of the server or use
 * the 'directory' and/or 'name' arguments.
 * .
 * {code:bash}
 * server restart
 * server restart name="myapp"
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="restart" excludeFromHelp=false {

	// DI
	property name="serverService" 	inject="ServerService";
	property name="packageService" 	inject="packageService";

	/**
	 * Restart a server instance
	 *
	 * @directory.hint web root for the server
	 * @name.hint the short name of the server to restart
	 * @force.hint if passed, this will force restart the server
	 * @openbrowser.hint open a browser after restarting, defaults to false
	 **/
	function run(
		string directory="",
		string name="",
		boolean force=false,
		boolean openBrowser=false
	){
		// resolve path
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );

		// Discover by shortname or webroot and get server info
		var serverInfo = serverService.getServerInfoByDiscovery(
			directory 	= arguments.directory,
			name		= arguments.name
		);

		// Verify server info
		if( structIsEmpty( serverInfo ) ){
			error( "The server you requested to restart was not found (webroot=#arguments.directory#, name=#arguments.name#)." );
			print.line( "You can use the 'server status showAll=true' command to get all the available servers." );
			return;
		}

		// stop server
		print.boldCyanLine( "Trying to stop server..." );
		runCommand( "server stop" );
		// start up server
		print.line().boldCyanLine( "Trying to start server..." );
		runCommand( "server start openBrowser=#arguments.openBrowser# port=#serverInfo.port# force=#arguments.force#" );
	}

}