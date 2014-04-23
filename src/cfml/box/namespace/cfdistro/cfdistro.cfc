/**
 * build utility
 **/
component output="false" persistent="false" trigger="" {

	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
		thisdir = getDirectoryFromPath(getMetadata(this).path);
		home = thisdir & "/home";
		buildprops = {
			"cfdistro.repo.local.path":shell.getHomeDir() & "/artifacts",
			"basedir":shell.pwd(),
			"server.jvm.args":"-Xms256M -Xmx326M -XX:PermSize=128M -XX:MaxPermSize=128M  -Djava.net.preferIPv4Stack=true",
			"mappings.list":"/:#shell.pwd()#"
		}
		return this;
	}

	/**
	 * download and install cfdistro
	 **/
	function install(String version="latest")  {
		http url="http://cfmlprojects.org/artifacts/cfdistro/latest/cfdistro.zip" file="#thisdir#/cfdistro.zip";
		zip action="unzip" file="#thisdir#/cfdistro.zip" destination="#home#";
		return "installed";
	}

	/**
	 * Generate war
	 * ex: war destination=/directory/to/store/in
	 **/
	function war(String destination="")  {
		if(destination == ""){
			destination = shell.pwd() & "/war";
		}
		buildprops["war.target.dir"] = destination;
		var params = {};
		params.properties = buildprops;
		params.antfile = getDirectoryFromPath(getMetadata(this).path) & "/home/build.xml";
		params.target = "build";
		params.outputstream = createObject("java","java.lang.System").out;
		var antresults = new home.tag.cfc.Ant().run(argumentCollection=params);
		return antresults.errorText & antresults.outText;
	}

	/**
	 * @command.name server-start
	 * start server
	 * ex: war destination=/directory/to/store/in
	 **/
	function serverStart(String war="")  {
		if(war == ""){
			war = shell.pwd() & "/war";
		}
		buildprops["war.target.dir"] = war;
		var params = {};
		params.properties = buildprops;
		params.antfile = getDirectoryFromPath(getMetadata(this).path) & "/home/build.xml";
		params.target = "server.start";
		params.outstream = createObject("java","java.lang.System").out;
		var antresults = new home.tag.cfc.Ant().run(argumentCollection=params);
		return antresults.errorText & antresults.outText;
	}

	/**
	 * Get dependency
	 **/
	function dependency(required artifactId, required groupId, required version, mapping="", exclusions="")  {
		var params = {};
		params.antfile = "";
		params.properties = buildprops;
		params.outputstream = createObject("java","java.lang.System").out;
		params.generatedContent = '<dependency groupId="#groupId#" artifactId="#artifactId#" version="#version#" mapping="#mapping#" />';
		var antresults = new home.tag.cfc.Ant().run(argumentCollection=params);
		return antresults.outText.toString();
	}

	/**
	 * cfdistro help
	 **/
	function help()  {
		var params = {};
		params.antfile = "";
		params.properties = buildprops;
//		params.outputstream = createObject("java","java.lang.System").out;
		params.antfile = getDirectoryFromPath(getMetadata(this).path) & "/home/build.xml";
		params.target = "help";
		var antresults = new home.tag.cfc.Ant().run(argumentCollection=params);
		var results = antresults.outText.toString();
		antresults = javacast("null","");
		return results;
	}

	/**
	 * cfdistro nothing
	 **/
	function nothing()  {
		var params = {};
		params.antfile = "";
		params.properties = buildprops;
		params.antfile = getDirectoryFromPath(getMetadata(this).path) & "/home/build.xml";
		params.target = "help";
		var antresults = new home.tag.cfc.Ant();
		var wee = antresults.nada();
		return wee;
	}

}