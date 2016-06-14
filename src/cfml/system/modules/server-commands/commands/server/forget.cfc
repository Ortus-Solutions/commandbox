/**
 * Forget an embedded CFML server from persistent disk.  Run command from the web root of the server, or use the short name.
 * .
 * {code:bash}
 * server forget
 * server forget name=serverName
 * server forget --all
 * server forget --all --force
 * {code}
 **/
component {

	// di
	property name="serverService" inject="ServerService";

	/**
	 * Forgets one or all servers from persistent disk, removing all logs, configs, etc.
	 *
	 * @name.hint the short name of the server
	 * @name.optionsUDF serverNameComplete
	 * @directory.hint web root for the server
	 * @serverConfigFile The path to the server's JSON file.
	 * @all.hint Forget all servers
	 * @force.hint Skip the "are you sure" confirmation
	 **/
	function run(
		string name,
		string directory,
		String serverConfigFile,
		Boolean all=false,
		Boolean force=false
	){	
		if( !isNull( arguments.directory ) ) {
			arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
		} 
		if( !isNull( arguments.serverConfigFile ) ) {
			arguments.serverConfigFile = fileSystemUtil.resolvePath( arguments.serverConfigFile );
		}		
		var serverInfo = serverService.resolveServerDetails( arguments ).serverinfo;

		// Confirm deletion
		var askMessage = arguments.all ? "Really forget & delete all servers (servers=#arrayToList( serverService.getServerNames() )#) forever [y/n]?" :
									     "Really forget & delete server '#serverinfo.name#' forever [y/n]?";
									     
		if( arguments.force || confirm( askMessage ) ){
			print.line( serverService.forget( serverInfo, arguments.all ) );
		} else {
			print.orangeLine( "Cancelling forget command" );
		}

	}
	
	function serverNameComplete() {
		return serverService.getServerNames();
	}

}