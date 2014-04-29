/**
 * build utility
 **/
component persistent="false" extends="cli.BaseCommand" {

/*	function init(shell) {
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
*/
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
	function dependency(required artifactId, required groupId, required version, type="zip", classifier="", mapping="", exclusions="")  {
		var params = {};
		if(mapping == "") {
			var slashGroupId = replace(groupId,".","/","all");
			var artifactPath = "/#slashGroupId#/#artifactId#/#version#/#artifactId#-#version#-#classifier#.#type#";
			var mavenMetaPath = "/#slashGroupId#/#artifactId#/maven-metadata.xml";
			var remoteRepo = "http://cfmlprojects.org/artifacts";
			var remoteURL = remoteRepo & artifactPath;
			directoryCreate("#shell.getArtifactsDir()#/#slashGroupId#/#artifactId#/#version#/",true);
			getHTTPFileVerified("#remoteRepo##mavenMetaPath#","#shell.getArtifactsDir()##mavenMetaPath#");
			getHTTPFileVerified("#remoteRepo##artifactPath#","#shell.getArtifactsDir()##artifactPath#");
			return "Resolved dependency #groupId#:#artifactId#:#version#:#classifier#:#type#";
		}
		params.antfile = "";
		params.properties = buildprops;
		//params.outputstream = createObject("java","java.lang.System").out;
		params.generatedContent = '<dependency groupId="#groupId#" artifactId="#artifactId#" version="#version#" classifier="#classifier#" mapping="#mapping#" type="#type#" />';
		var antresults = new home.tag.cfc.Ant().run(argumentCollection=params);
		return antresults.outText.toString();
	}

	private function getHTTPFileVerified(required fileUrl, required filePath) {
		if(fileExists("#filePath#.md5") && fileExists(filePath)) {
			var fileHash = lcase(hash(fileReadBinary(filePath),"md5"));
			var goodHash = lcase(fileRead(filePath & ".md5"));
			if( fileHash == goodHash) {
				return filePath;
			}
		}
		http url="#fileUrl#.md5" file="#filePath#.md5";
		http url="#fileUrl#.sha1" file="#filePath#.sha1";
		http url="#fileUrl#" file="#filePath#";
		var fileHash = lcase(hash(fileReadBinary(filePath),"md5"));
		var goodHash = lcase(fileRead(filePath & ".md5"));
		if( fileHash != goodHash) {
			throw(message="incorrect hash for #filePath#! (#fileHash# != #goodHash#)");
		}
		return filePath;
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