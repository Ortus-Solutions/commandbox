/**
 * Forget an embedded CFML server
 **/
component extends="commandbox.system.BaseCommand" excludeFromHelp=false {

	property name="serverService" inject="ServerService";

	/**
	 * Forgets one or all servers
	 *
	 * @directory.hint web root for the server
	 * @name.hint short name for the server
	 * @all.hint forget all servers
	 * @force.hint force
	 **/
	function run(
		String directory="",
		String name="",
		Boolean all=false,
		Boolean force=false
	){
		var webroot 	= arguments.directory is "" ? shell.pwd() : arguments.directory;
		var serverInfo 	= serverService.getServerInfo( fileSystemUtil.resolveDirectory( webroot ) );

		print.line(serverService.forget( serverInfo, arguments.all, arguments.force ));
	}

}