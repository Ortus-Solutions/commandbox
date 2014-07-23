/**
 * Upgrades the shell libraries to the latest version
 *
 * upgrade
 *
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	// DI
	property name="artifactDir" inject="artifactDir@constants";
	property name="homedir" 	inject="homedir@constants";

	function run(Boolean force=false) {
		var temp = shell.getTempDir();
		http url="http://cfmlprojects.org/artifacts/com/ortussolutions/box.cli/maven-metadata.xml" file="#temp#/maven-metadata.xml";
		var mavenData = xmlParse("#temp#/maven-metadata.xml");
		var latest = xmlSearch(mavendata,"/metadata/versioning/versions/version[last()]/text()");
		latest = latest[1].xmlValue;
		if(latest!=shell.getVersion() || force) {
			dependency( artifactId='box.cli', groupId='com.ortussolutions', version=latest, classifier='cfml' );
		}
		var filePath = "#variables.artifactDir#/com/ortussolutions/box.cli/#latest#/box.cli-#latest#-cfml.zip";
		if( fileExists( filePath ) ) {

			print.greenLine( "Unzipping #filePath#..." );
			zip
				action="unzip"
				file="#filePath#"
				destination="#variables.homedir#/cfml"
				overwrite=true;
		}

		// Reload the shell
		runCommand( 'reload' );

		print.greenLine( "Installed #latest#" );
	}

	private function dependency(required artifactId, required groupId, required version, type="zip", classifier="", mapping="", exclusions="")  {
		var params = {};

		var slashGroupId = replace( groupId, ".", "/", "all" );
		var artifactPath = "/#slashGroupId#/#artifactId#/#version#/#artifactId#-#version#-#classifier#.#type#";
		var mavenMetaPath = "/#slashGroupId#/#artifactId#/maven-metadata.xml";
		var remoteRepo = "http://cfmlprojects.org/artifacts";
		var remoteURL = remoteRepo & artifactPath;
		directoryCreate( "#variables.artifactDir#/#slashGroupId#/#artifactId#/#version#/", true, true );
		getHTTPFileVerified( "#remoteRepo##mavenMetaPath#","#variables.artifactDir##mavenMetaPath#" );
		getHTTPFileVerified( "#remoteRepo##artifactPath#","#variables.artifactDir##artifactPath#" );

		print.greenLine( "Resolved dependency #groupId#:#artifactId#:#version#:#classifier#:#type#..." );
	}

	private function getHTTPFileVerified(required fileUrl, required filePath) {
		if(fileExists("#filePath#.md5") && fileExists(filePath)) {
			var fileHash = lcase(hash(fileReadBinary(filePath),"md5"));
			var goodHash = lcase(fileRead(filePath & ".md5"));
			if( fileHash == goodHash) {
				return filePath;
			}
		}

		print.greenLine( "Downloading #fileUrl#..." );
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

}