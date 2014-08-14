/**
 * Upgrades CommandBox to the latest stable version.
 * .
 * {code:bash}
 * upgrade
 * {code}
 * .
 * Use the "latest" parameter to download the bleeding edge version
 * .
 * {code:bash}
 * upgrade --latest
 * {code}
 * .
 * Use the "force" parameter to re-install even if the version installed matches that on the server
 * .
 * {code:bash}
 * upgrade --force
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	// DI
	property name="artifactDir" 			inject="artifactDir@constants";
	property name="homedir" 				inject="homedir@constants";
	property name="ortusArtifactsURL" 		inject="ortusArtifactsURL@constants";
	property name="progressableDownloader"	inject="ProgressableDownloader";
	property name="progressBar" 			inject="ProgressBar";
	
	/**
	 * @latest.hint Will download bleeding edge if true, last stable version if false
	 * @force.hint Force the update even if the version on the server is the same as locally
	 **/
	function run( boolean latest=false, boolean force=false ) {
		var temp = shell.getTempDir();
		http url="#ortusArtifactsURL#ortussolutions/commandbox/box-repo.json" file="#temp#/box-repo.json";
		var repoData = deserializeJSON( fileRead( '#temp#/box-repo.json' ) );
		
		// If latest, compare build number
		if( arguments.latest ) {
			var repoVersion = '#repoData.versioning.latestVersion#.#repoData.versioning.latestBuildID#';
			var repoVersionShort = repoData.versioning.latestVersion;
			var commandBoxVersion = shell.getVersion();
		// Stable version just tracks major.minor.patch
		} else {
			var repoVersion = repoData.versioning.stableVersion;
			var repoVersionShort = repoData.versioning.stableVersion;
			var commandBoxVersion = listDeleteAt( shell.getVersion(), 4, '.' );			
		}
		
		// If the local install is old, or we're forcing.
		if( repoVersion != commandBoxVersion || force ) {
			
			var fileURL = '#ortusArtifactsURL#ortussolutions/commandbox/#repoVersionShort#/commandbox-cfml-#repoVersionShort#.zip';
			var filePath = '#temp#/commandbox-cfml-#repoVersion#.zip';
			print.greenLine( "Downloading #fileUrl#..." ).toConsole();
			
			// Download the update
			progressableDownloader.download(
				fileURL,
				filePath,
				function( status ) {
					progressBar.update( argumentCollection = status );
				}
			);
					
			print.greenLine( "Unzipping #filePath#..." ).toConsole();
			
			zip
				action="unzip"
				file="#filePath#"
				destination="#variables.homedir#/cfml"
				overwrite=true;
	
			print.greenLine( "Installed #repoVersion#" );
						
			runCommand( 'pause' );
			
			// Reload the shell
			runCommand( 'reload' );
	
				
		} else {
			print.greenLine( "Your version of CommandBox is already current (#repoVersion#)." );
		}
	}


}