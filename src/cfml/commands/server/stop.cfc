/**
 * Stop the a CFML server
 **/
component extends="commandbox.system.BaseCommand" aliases="stop" excludeFromHelp=false {

	property name="serverService" inject="ServerService";
	
	/**
	 * Stop a server instance
	 *
	 * @directory.hint web root for the server
	 * @name.hint short name for the server
	 * @force.hint force start if status != stopped
	 **/
	function run(
		String directory="",
		String name="",
		Boolean force=false
	){
		var webroot 	= arguments.directory is "" ? shell.pwd() : arguments.directory;
		var serverInfo 	= serverService.getServerInfo( fileSystemUtil.resolveDirectory( webroot ) );
		
		return serverService.stop( serverInfo );
	}

}