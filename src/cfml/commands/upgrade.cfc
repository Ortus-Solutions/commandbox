/**
 * Upgrades the shell libraries to the latest version
 * 
 * upgrade
 * 
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	function run(Boolean force=false) {
		var temp = shell.getTempDir();
		http url="http://cfmlprojects.org/artifacts/org/coldbox/box.cli/maven-metadata.xml" file="#temp#/maven-metadata.xml";
		var mavenData = xmlParse("#temp#/maven-metadata.xml");
		var latest = xmlSearch(mavendata,"/metadata/versioning/versions/version[last()]/text()");
		latest = latest[1].xmlValue;
		if(latest!=shell.getVersion() || force) {
			runCommand( "cfdistro dependency artifactId=box.cli groupId=org.coldbox version=#latest# classifier=cfml" );
		}
		var filePath = "#shell.getArtifactsDir()#/org/coldbox/box.cli/#latest#/box.cli-#latest#-cfml.zip";
		if( fileExists( filePath ) ) {
			
			zip
				action="unzip"
				file="#filePath#"
				destination="#shell.getHomeDir()#/cfml";
		}
					 
		print.line( "installed #latest#" );
	}

}