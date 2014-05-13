/**
 * Stop the a CFML server
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="stop" excludeFromHelp=false {

	/**
	 * Stop a server instance
	 *
	 * @directory.hint web root for the server
	 * @name.hint short name for the server
	 * @force.hint force start if status != stopped
	 **/
	function run(String directory="", String name="", Boolean force=false)  {
		var manager = new commandbox.system.ServerManager(shell);
		var webroot = directory is "" ? shell.pwd() : directory;
		var serverInfo = manager.getServerInfo(fileSystemUtil.resolveDirectory( webroot ));
		manager.stop(serverInfo);
	}

}