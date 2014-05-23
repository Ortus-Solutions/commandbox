/**
 * Stop the a CFML server
 **/
component extends="commandbox.system.BaseCommand" aliases="stop" excludeFromHelp=false {

	// DI
	property name="serverService" inject="ServerService";
	
	/**
	 * Stop a server instance
	 *
	 * @directory.hint web root for the server
	 * @forget.hint if passed, this will also remove the directory information from disk
	 **/
	function run( String directory="", boolean forget=false ){
		var webroot 	= arguments.directory is "" ? shell.pwd() : arguments.directory;
		var serverInfo 	= serverService.getServerInfo( fileSystemUtil.resolveDirectory( webroot ) );
		
		var results = serverService.stop( serverInfo );
		if( results.error ){
			error( results.messages );
		} else {
			return results.messages;
		}
	}

}