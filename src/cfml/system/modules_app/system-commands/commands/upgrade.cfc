/**
 * Upgrades CommandBox to the latest stable version.
 * .
 * {code:bash}
 * upgrade
 * {code}
 * .
 * Use the "latest" parameter to download the bleeding edge version
 * .x
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
component {

	// DI
	property name="artifactDir" 			inject="artifactDir@constants";
	property name="homedir" 				inject="homedir@constants";
	property name="ortusArtifactsURL" 		inject="ortusArtifactsURL@constants";
	property name="ortusPRDArtifactsURL" 	inject="ortusPRDArtifactsURL@constants";
	property name="progressableDownloader"	inject="ProgressableDownloader";
	property name="progressBar" 			inject="ProgressBar";
	property name="semanticVersion"			inject="semanticVersion@semver";
	property name="ConfigService"			inject="ConfigService";

	/**
	 * @latest.hint Will download bleeding edge if true, last stable version if false
	 * @force.hint Force the update even if the version on the server is the same as locally
	 **/
	function run( boolean latest=false, boolean force=false ) {
		
		if( !latest && semanticVersion.isPreRelease( shell.getVersion() ) ) {
			print
				.yellowLine( 'Your version of CommandBox [#shell.getVersion()#] is a prerelease build, so defaulting to "latest".' )
				.line(); 
			latest = true;
		}
		
		
		// tmp dir location
		var temp = shell.getTempDir();
		// Determine artifacts location used
		var thisArtifactsURL = arguments.latest ? variables.ortusArtifactsURL : variables.ortusPRDArtifactsURL;

		// download the box-repo from the artifacts URL
		print.greenLine( "Getting #arguments.latest ? 'latest' : 'stable'# versioning information from #thisArtifactsURL#" ).toConsole();
		var boxRepoURL = '#thisArtifactsURL#ortussolutions/commandbox/box-repo.json';
		var loaderRepoURL = '#thisArtifactsURL#ortussolutions/commandbox/box-loader.json';

		http
			url="#boxRepoURL#"
			file="#temp#/box-repo.json"
			throwOnError=false
			proxyServer="#ConfigService.getSetting( 'proxy.server', '' )#"
			proxyPort="#ConfigService.getSetting( 'proxy.port', 80 )#"
			proxyUser="#ConfigService.getSetting( 'proxy.user', '' )#"
			proxyPassword="#ConfigService.getSetting( 'proxy.password', '' )#"
			result="local.boxRepoResult";

		http
			url="#loaderRepoURL#"
			file="#temp#/box-loader.json"
			throwOnError=false
			proxyServer="#ConfigService.getSetting( 'proxy.server', '' )#"
			proxyPort="#ConfigService.getSetting( 'proxy.port', 80 )#"
			proxyUser="#ConfigService.getSetting( 'proxy.user', '' )#"
			proxyPassword="#ConfigService.getSetting( 'proxy.password', '' )#"
			result="local.loaderRepoResult";

		// Do some error checking
		if( !local.boxRepoResult.statusCode contains "200" || !fileExists( '#temp#/box-repo.json' ) ||
			!local.loaderRepoResult.statusCode contains "200" || !fileExists( '#temp#/box-loader.json' ) ) {
			error(
				"Sorry, we're having troubles accessing the interwebs now or the update site is down. Please try again later",
				"Box Repo: [#local.boxRepoResult.statusCode#] Loader Repo: [#local.loaderRepoResult.statusCode#]"
			);
		}

		var boxRepoJSON = fileRead( '#temp#/box-repo.json' );
		var loaderRepoJSON = fileRead( '#temp#/box-loader.json' );
		
		fileDelete( '#temp#/box-repo.json' );
		fileDelete( '#temp#/box-loader.json' );

		if( !isJSON( boxRepoJSON ) ) {
			return error( "Oops, we expected [#boxRepoURL#] to be JSON, but it wasn't.  #cr#I'm afraid we can't upgrade right now." );
		}
		if( !isJSON( loaderRepoJSON ) ) {
			return error( "Oops, we expected [#loaderRepoURL#] to be JSON, but it wasn't.  #cr#I'm afraid we can't upgrade right now." );
		}

		// read and deserialize the repo
		var repoData = deserializeJSON( boxRepoJSON );
		var loaderData = deserializeJSON( loaderRepoJSON );

		// Assemble the available version numbers based on whether we're checking the bleeding edge or stable repo
		if( arguments.latest ) {
			var repoVersionShort= repoData.versioning.latestVersion;
			var repoVersion 	= '#repoVersionShort#+#repoData.versioning.latestBuildID#';
			var loaderVersion 	= '#loaderData.versioning.latestVersion#+#loaderData.versioning.latestBuildID#';
		} else {
			// We don't store build numbers for stable versions in box-repo.json
			var repoVersionShort= repoData.versioning.stableVersion;
			var repoVersion 	= repoVersionShort;
			var loaderVersion 	= loaderData.versioning.stableVersion;
		}

		// Is there a new version of CommandBox.  New builds consistute new BE verions.
		var isNewVersion 	= semanticVersion.isNew( current=shell.getVersion(), target=repoVersion, checkBuildID=arguments.latest );
		// Is there a new version of the CLI Loader. Ignore build number since it's sort of fake (Just a copy of the CommandBox build number)
		var isNewLoaderVersion 	= semanticVersion.isNew( current=shell.getLoaderVersion(), target=LoaderVersion, checkBuildID=false );

		// If the local install is old, or we're forcing.
		if( isNewVersion || force ) {
			// Inform User about update
			print.boldCyanLine( "Ohh Goody Goody, an update has been found (#repoVersion#) for your installation (#shell.getVersion()#)!" )
				.toConsole();

			if( isNewLoaderVersion ) {
				// We can't handle this kind of update from CFML
				// so instruct the user to do a manual update with a new binary
				print.line()
					.boldYellowLine( "This update affects the core underpinnings of CommandBox so we can't automate it for you." )
					.boldYellowLine( "Please download the latest version of CommandBox and replace the binary on your OS." )
					.boldYellowLine( "CommandBox will finish the upgrade for you the first time it is run." )
					.line()
					.text( "Download URL: ").
						boldLine( arguments.latest ? '#thisArtifactsURL###/ortussolutions/commandbox/#repoVersionShort#/' : 'http://www.ortussolutions.com/products/commandbox/##download' )
					.line()
					.yellowLine( "(Your CLI Loader version is #shell.getLoaderVersion()# and the latest is #LoaderVersion#)" )
					.toConsole();
					return;
			}

			// Confirm installation
			if( !force && !confirm( "Do you wish to apply this update? [y/n]" ) ){
				return;
			}

			// prepare locations
			var fileURL 	= '#thisArtifactsURL#ortussolutions/commandbox/#repoversionshort#/commandbox-cfml-#repoVersionShort#.zip';
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

			wirebox.getCacheBox().getCache( 'metadataCache' ).clearAll();

			// Tell user what's going on
			print.greenLine( "Unzipping #filePath#..." ).toConsole();
			zip
				action="unzip"
				file="#filePath#"
				destination="#variables.homedir#/cfml"
				overwrite=true;

			// Notify the user
			print
				.greenLine( "Update applied successfully, installed v#repoVersion#" )
				.redLine( "CommandBox needs to exit to complete the installation." )
				.yellowLine( "This message will self-destruct in 10 seconds" )
				.toConsole();

			// Give them a chance to read it.
			sleep( 10000 );

			// Stop executing.  Since the unzipping possbily replaced .cfm files that were
			// also cached in memory, there's no good way we've found to be able to reload and keep going.
			abort;

		} else {
			print.yellowLine( "Your version of CommandBox (#shell.getVersion()#) is already current (#repoVersion#)." );
		}
	}


}
