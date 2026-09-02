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
component {

	// DI
	property name="artifactDir" 			inject="artifactDir@constants";
	property name="homedir" 				inject="homedir@constants";
	property name="ortusArtifactsURL" 		inject="ortusArtifactsURL@constants";
	property name="ortusPRDArtifactsURL" 	inject="ortusPRDArtifactsURL@constants";
	property name="semanticVersion"			inject="semanticVersion@semver";
	property name="ConfigService"			inject="ConfigService";
	property name="forgeBox"				inject="ForgeBox";
	property name="packageService"			inject="PackageService";

	/**
	 * @latest.hint Download bleeding edge version, instead of last stable version
	 * @force.hint Force the update even if the version on the server is the same as locally
	 **/
	function run( boolean latest, boolean force=false ) {
		if( configService.getSetting( 'offlineMode', false ) ) {
			error( 'Can''t check for updates, CommandBox is in offline mode.  Go online with [config set offlineMode=false].' );
		}

		if( isNull( arguments.latest ) ) {
			if( semanticVersion.isPreRelease( shell.getVersion() ) ) {
				print
					.yellowLine( 'Your version of CommandBox [#shell.getVersion()#] is a prerelease build, so defaulting to "latest".' )
					.line();
				arguments.latest = true;
			} else {
				arguments.latest = false;
			}
		}

		if( shell.getVersion() == "@build.version@" ) {
			print
				.yellowLine( "Upgrade is not supported for local dev symlinked installs of the commandbox repo." )
				.yellowLine( "This shell reports @build.version@, so please upgrade by updating your local source/build instead." )
				.toConsole();
			return;
		}

		var slug = "bx-cli";
		var APIToken = configService.getSetting( "endpoints.forgebox.APIToken", "" );
		var targetRange = arguments.latest ? "be" : "stable";
		var updateChannel = arguments.latest ? "latest" : "stable";

		print.greenLine( "Checking ForgeBox for #updateChannel# #slug# version..." ).toConsole();

		try {
			var entryData = forgeBox.getEntry( slug, APIToken );
		} catch( forgebox var e ) {
			error( e.message, e.detail ?: "Unable to read release data from ForgeBox." );
		}

		if( !entryData.isActive ) {
			error( "The ForgeBox entry [#slug#] is inactive." );
		}

		entryData.versions.sort( function( a, b ) { return semanticVersion.compare( b.version, a.version ) } );

		var targetVersionData = {};
		for( var thisVersion in entryData.versions ) {
			if( semanticVersion.satisfies( thisVersion.version, targetRange ) ) {
				targetVersionData = thisVersion;
				break;
			}
		}

		if( structIsEmpty( targetVersionData ) ) {
			if( targetRange == "stable" && arrayLen( entryData.versions ) ) {
				targetVersionData = entryData.versions[ 1 ];
			} else {
				error( "No #targetRange# version was found for [#slug#] in ForgeBox." );
			}
		}

		var targetVersion = targetVersionData.version;
		print.greenLine( "Found version for #updateChannel# channel: #targetVersion#" ).toConsole();

		var isNewVersion = semanticVersion.isNew( current=shell.getVersion(), target=targetVersion, checkBuildID=arguments.latest );

		if( !isNewVersion && !force ) {
			print.yellowLine( "Your version of CommandBox (#shell.getVersion()#) is already current (#targetVersion#)." );
			return;
		}

		if( force ) {
			print.boldCyanLine( "Preparing forced upgrade package for CommandBox #targetVersion#..." ).toConsole();
		} else {
			print.boldCyanLine( "Preparing upgrade package for CommandBox #shell.getVersion()# -> #targetVersion#..." ).toConsole();
			if( !confirm( "Do you wish to apply this update? [y/n]" ) ) {
				print.yellowLine( "Upgrade canceled." ).toConsole();
				return;
			}
		}

		var installID = "forgebox:#slug#@#targetVersion#";
		var fileVersion = targetVersion.reReplace( "[^0-9A-Za-z\._-]", "-", "all" );
		var installDir = "#shell.getTempDir()#bx-cli-#fileVersion#-#lCase( createUUID() )#";
		var upgradeApplied = false;

		try {
			directoryCreate( installDir, true, true );

			print.greenLine( "Staging upgrade package..." ).toConsole();
			if( !packageService.installPackage(
				ID = installID,
				directory = installDir,
				save = false,
				saveDev = false,
				currentWorkingDirectory = installDir,
				verbose = false,
				force = true
			) ) {
				error( "Unable to stage upgrade package [#installID#]." );
			}

			var moduleHome = createObject( "java", "java.lang.System" ).getProperty( "cfml.cli.moduleRoot", "" );
			if( !len( moduleHome ) ) {
				error( "Unable to determine bx-cli home from cfml.cli.moduleRoot." );
			}
			moduleHome = moduleHome.reReplace( "[/\\]+$", "" );
			if( !directoryExists( moduleHome ) ) {
				error( "bx-cli home does not exist: #moduleHome#" );
			}

			var stagedModuleHome = resolveStagedModuleHome( installDir );
			var stagedBoxJSON = deserializeJSON( fileRead( "#stagedModuleHome#/box.json" ) );
			var minimumBoxLangVersion = stagedBoxJSON.boxlang.minimumVersion ?: "";
			if( len( minimumBoxLangVersion ) ) {
				var currentBoxLangVersion = server.boxlang.version;
				if( semanticVersion.isNew( current=currentBoxLangVersion, target=minimumBoxLangVersion, checkBuildID=false ) ) {
					error(
						"This bx-cli upgrade requires BoxLang #minimumBoxLangVersion# or higher.",
						"Current BoxLang version is #currentBoxLangVersion#."
					);
				}
			}

			print.greenLine( "Installing module metadata..." ).toConsole();
			fileCopy( "#stagedModuleHome#/box.json", "#moduleHome#/box.json" );
			fileCopy( "#stagedModuleHome#/ModuleConfig.bx", "#moduleHome#/ModuleConfig.bx" );

			for( var folderName in [ "libs", "cli_modules", "src" ] ) {
				var sourceFolder = "#stagedModuleHome#/#folderName#";
				var targetFolder = "#moduleHome#/#folderName#";

				if( !directoryExists( sourceFolder ) ) {
					error( "Expected folder [#folderName#] not found in staged package: #sourceFolder#" );
				}

				if( directoryExists( targetFolder ) ) {
					print.greenLine( "Removing old #folderName#..." ).toConsole();
					directoryDelete( targetFolder, true );
				}

				print.greenLine( "Installing new #folderName#..." ).toConsole();
				directoryCopy( sourceFolder, targetFolder, true );
			}

			upgradeApplied = true;
		} finally {
			if( directoryExists( installDir ) ) {
				directoryDelete( installDir, true );
			}
		}

		if( upgradeApplied ) {
			print.greenLine( "Update applied successfully, installed v#targetVersion#" )
				.redLine( "CommandBox needs to exit to complete the installation." )
				.yellowLine( "This message will self-destruct in 10 seconds" )
				.toConsole();

			if( !force ) {
				sleep( 10000 );
			}

			abort;
		}

		return;
	}

	private string function resolveStagedModuleHome( required string installDir ) {
		var candidatePaths = [
			arguments.installDir,
			"#arguments.installDir#/bx-cli",
			"#arguments.installDir#/modules/bx-cli"
		];

		for( var candidatePath in candidatePaths ) {
			if( fileExists( "#candidatePath#/box.json" ) && fileExists( "#candidatePath#/ModuleConfig.bx" ) ) {
				return candidatePath;
			}
		}

		var boxJSONFiles = directoryList( arguments.installDir, true, "path", "box.json" );
		for( var boxJSONFile in boxJSONFiles ) {
			var candidatePath = reReplace( getDirectoryFromPath( boxJSONFile ), "[/\\]$", "" );
			if( fileExists( "#candidatePath#/ModuleConfig.bx" ) ) {
				return candidatePath;
			}
		}

		error( "Could not locate staged bx-cli module home in [#arguments.installDir#]." );
	}


}
