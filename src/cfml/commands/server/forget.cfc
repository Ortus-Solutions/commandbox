/**
 * Forget an embedded CFML server
 **/
component persistent="false" extends="commandbox.system.BaseCommand" excludeFromHelp=false {

	function run(String directory="", Boolean all=false, Boolean force=false)  {
		var manager = new commandbox.system.ServerManager(shell);
		var webroot = directory is "" ? shell.pwd() : directory;
		var serverInfo = manager.getServerInfo(fileSystemUtil.resolveDirectory( webroot ));
		manager.forget(serverInfo,all,force);
	}

}