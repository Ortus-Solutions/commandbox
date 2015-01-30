/**
 * Resstart an embedded CFML server.  Run command from the web root of the server or use
 * the 'directory' and/or 'name' arguments.
 * .
 * {code:bash}
 * server restart
 * server restart myapp
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="restart" excludeFromHelp=false {

	// DI
	property name="serverService" 	inject="ServerService";
	property name="packageService" 	inject="packageService";

	/**
	 * @name.hint the short name of the server to restart
	 * @name.optionsUDF serverNameComplete
	 * @directory.hint web root for the server
	 * @force.hint if passed, this will force restart the server
	 * @openbrowser.hint open a browser after restarting, defaults to false
	 **/
	function run(
		string name="",
		string directory="",
		boolean force=false,
		boolean openBrowser=false
	){
		// Discover by shortname or webroot and get server info
		var serverInfo = serverService.getServerInfoByDiscovery(
			directory 	= arguments.directory,
			name		= arguments.name
		);

		// Verify server info
		if( structIsEmpty( serverInfo ) ){
			error( "The server you requested to restart was not found (webroot=#arguments.directory#, name=#arguments.name#)." );
			print.line( "You can use the 'server list' command to get all the available servers." );
			return;
		}

		var stopCommand = "server stop '#serverInfo.name#'";
		var startCommand = "server start name='#serverInfo.name#' openBrowser=#arguments.openBrowser# port=#serverInfo.port# force=#arguments.force#";

		// stop server
		print.boldCyanLine( "Trying to stop server..." );
		print.yellowLine( '> ' & stopCommand );
		runCommand( stopCommand );
		
		// start up server
		print.line().boldCyanLine( "Trying to start server..." );
		print.yellowLine( '> ' & startCommand );
		runCommand( startCommand );
	}

	
	function serverNameComplete() {
		return serverService.getServerNames();
	}
}