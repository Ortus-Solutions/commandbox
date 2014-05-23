/**
 * Stop the a CFML server
 **/
component extends="commandbox.system.BaseCommand" aliases="stop" excludeFromHelp=false {

	property name="serverService" inject="ServerService";
	
	/**
	 * Stop a server instance
	 *
	 * @directory.hint web root for the server
	 **/
	function run( String directory="" ){
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