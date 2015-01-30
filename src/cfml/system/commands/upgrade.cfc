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
	property name="ortusPRDArtifactsURL" 	inject="ortusPRDArtifactsURL@constants";
	property name="progressableDownloader"	inject="ProgressableDownloader";
	property name="progressBar" 			inject="ProgressBar";
	property name="semanticVersion"			inject="semanticVersion";

	/**
	 * @latest.hint Will download bleeding edge if true, last stable version if false
	 * @force.hint Force the update even if the version on the server is the same as locally
	 **/
	function run( boolean latest=false, boolean force=false ) {
		// tmp dir location
		var temp = shell.getTempDir();
		// Determine artifacts location used
		var thisArtifactsURL = arguments.latest ? variables.ortusArtifactsURL : variables.ortusPRDArtifactsURL;

		// download the box-repo from the artifacts URL
		print.greenLine( "Getting #arguments.latest ? 'latest' : 'stable'# versioning information from #thisArtifactsURL#" ).toConsole();
		http url="#thisArtifactsURL#ortussolutions/commandbox/box-repo.json" file="#temp#/box-repo.json";

		// read and deserialize the repo
		var repoData = deserializeJSON( fileRead( '#temp#/box-repo.json' ) );

		// BE version tracks major.minor.patch+buildID
		if( arguments.latest ) {
			var repoVersion 	= '#repoData.versioning.latestVersion#+#repoData.versioning.latestBuildID#';
			var isNewVersion 	= semanticVersion.isNew( current=shell.getVersion(), target=repoVersion, checkBuildID=true );
		// Stable version just tracks major.minor.patch
		} else {
			var repoVersion 	= repoData.versioning.stableVersion;
			var isNewVersion 	= semanticVersion.isNew( current=shell.getVersion(), target=repoVersion, checkBuildID=false );
		}

		// If the local install is old, or we're forcing.
		if( isNewVersion || force ) {
			// Inform User about update
			print.boldCyanLine( "Ohh Goody Goody, an update has been found (#repoVersion#) for your installation (#shell.getVersion()#)!" )
				.toConsole();

			// Confirm installation
			if( !confirm( "Do you wish to apply this update? [y/n]" ) ){
				return;
			}

			// prepare locations
			var fileURL 	= '#thisArtifactsURL#ortussolutions/commandbox/#repoVersionShort#/commandbox-cfml-#repoVersionShort#.zip';
			var filePath 	= '#temp#/commandbox-cfml-#repoVersion#.zip';

			// Download the update
			print.greenLine( "Downloading #fileUrl#..." ).toConsole();
			progressableDownloader.download(
				fileURL,
				filePath,
				function( status ) {
					progressBar.update( argumentCollection = status );
				}
			);

			// Tell user what's going on
			print.greenLine( "Unzipping #filePath#..." ).toConsole();
			zip
				action="unzip"
				file="#filePath#"
				destination="#variables.homedir#/cfml"
				overwrite=true;

			print.greenLine( "Update applied successfully, installed v#repoVersion#" );
			// Wait for input
			runCommand( 'pause' );
			// Reload the shell
			runCommand( 'reload' );

		} else {
			print.yellowLine( "Your version of CommandBox (#shell.getVersion()#) is already current (#repoVersion#)." );
		}
	}


}