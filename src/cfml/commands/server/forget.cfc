/**
 * Forget an embedded CFML server
 **/
component persistent="false" extends="commandbox.system.BaseCommand" excludeFromHelp=false {

	/**
	 * Forgets one or all servers
	 *
	 * @directory.hint web root for the server
	 * @name.hint short name for the server
	 * @all.hint forget all servers
	 * @force.hint force
	 **/
	function run(String directory="", String name="", Boolean all=false, Boolean force=false)  {
		var manager = new commandbox.system.services.ServerService(shell);
		var webroot = directory is "" ? shell.pwd() : directory;
		var serverInfo = manager.getServerInfo(fileSystemUtil.resolveDirectory( webroot ));
		manager.forget(serverInfo,all,force);
	}

}