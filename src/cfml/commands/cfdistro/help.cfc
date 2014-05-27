/**
 * cfdistro help
 **/
component extends="commandbox.system.BaseCommand" {

	function onDIComplete() {
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

	function run()  {
		var params = {};
		params.antfile = "";
		params.properties = buildprops;
		params.antfile = getDirectoryFromPath(getMetadata(this).path) & "/home/build.xml";
		params.target = "help";
		var antresults = new home.tag.cfc.Ant().run(argumentCollection=params);
		var results = antresults.outText.toString();
		antresults = javacast("null","");
		return results;
	}

}