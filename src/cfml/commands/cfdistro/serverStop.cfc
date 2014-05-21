/**
 * start server
 * ex: cfdistro war destination=/directory/to/store/in
 **/
component extends="commandbox.system.BaseCommand" aliases="" {

	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
		thisdir = getDirectoryFromPath(getMetadata(this).path);
		home = thisdir & "/home";
		buildprops = {
			"cfdistro.repo.local.path":shell.getArtifactsDir(),
			"basedir":shell.pwd(),
			"server.jvm.args":"-Xms256M -Xmx326M -XX:PermSize=128M -XX:MaxPermSize=128M  -Djava.net.preferIPv4Stack=true",
			"mappings.list":"/:#shell.pwd()#"
		}
		return this;
	}

	function run(String war="")  {
		if(war == ""){
			war = shell.pwd() & "/war";
		}
		buildprops["war.target.dir"] = war;
		var params = {};
		params.properties = buildprops;
		params.antfile = getDirectoryFromPath(getMetadata(this).path) & "/home/build.xml";
		params.target = "server.stop";
		params.outstream = createObject("java","java.lang.System").out;
		var antresults = new home.tag.cfc.Ant().run(argumentCollection=params);
		return antresults.errorText & antresults.outText;
	}

}