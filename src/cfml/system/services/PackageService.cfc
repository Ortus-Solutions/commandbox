/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle working with the box.json file
*/
component accessors="true" singleton {

	// DI
	property name='CR' 					inject='CR@constants';
	property name='formatterUtil'		inject='formatter';
	property name='artifactService' 	inject='ArtifactService';
	// Using provider since javaService registers itself as an interceptor and I get errors from that happening before
	// the interceptor service is read so I need to delay the registration
	property name='javaService'     	inject='provider:JavaService';
	property name='fileSystemUtil'		inject='FileSystem';
	property name='pathPatternMatcher' 	inject='provider:pathPatternMatcher@globber';
	property name='shell' 				inject='Shell';
	property name='logger'				inject='logbox:logger:{this}';
	property name='semanticVersion'		inject='provider:semanticVersion@semver';
	property name='endpointService'		inject='EndpointService';
	property name='consoleLogger'		inject='logbox:logger:console';
	property name='interceptorService'	inject='interceptorService';
	property name='JSONService'			inject='JSONService';
	property name='systemSettings'		inject='SystemSettings';
	property name='wirebox'				inject='wirebox';
	property name='tempDir' 			inject='tempDir@constants';
	property name='serverService'		inject='serverService';
	property name='moduleService'		inject='moduleService';


	/**
	* Constructor
	*/
	function init(){
		return this;
	}

	/**
	* Checks to see if a box.json exists in a given directory
	* @directory The directory to examine
	*/
	boolean public function isPackage( required string directory ) {
		// If the package has a box.json in the root...
		return fileExists( getDescriptorPath( arguments.directory ) );
	}

	/**
	* Returns the path to the package descriptor
	* @directory The directory that is the root of the package
	*/
	public function getDescriptorPath( required string directory ) {
		return directory & '/box.json';
	}

	/**
	* Installs a package and its dependencies,  obeying ignores in the box.json file.  Returns a struct containing a "copied" array
	* and an "ignored" array containing the relative paths inside the package that were copied and ignored.
	*
	* @slug.ID Identifier of the package to install. If no ID is passed, all dependencies in the CDW  will be installed.
	* @slug.optionsUDF slugComplete
	* @directory The directory to install in. This will override the packages box.json install dir if provided.
	* @save Save the installed package as a dependency in box.json (if it exists)
	* @saveDev Save the installed package as a dev dependency in box.json (if it exists)
	* @production When calling this command with no slug to install all dependencies, set this to true to ignore devDependencies.
	* @currentWorkingDirectory Root of the application (used for finding box.json)
	* @verbose If set, it will produce much more verbose information about the package installation
	* @force When set to true, it will force dependencies to be installed whether they already exist or not
	* @packagePathRequestingInstallation If installing smart dependencies packages (like ColdBox modules) that are capable of being nested, this is our current level
	*
	* @returns True if no errors encountered, false if things went boom.
	**/
	boolean function installPackage(
			required string ID,
			string directory,
			boolean save=false,
			boolean saveDev=false,
			boolean production,
			string currentWorkingDirectory=shell.pwd(),
			boolean verbose=false,
			boolean force=false,
			string packagePathRequestingInstallation = arguments.currentWorkingDirectory,
			string defaultName=''
	){
		// Java service registers itself as an interceptor on creation so I need to force the provider to create the service before installing anything.
		javaService.$get();

		var shellWillReload = false;
		var job = wirebox.getInstance( 'interactiveJob' );
		interceptorService.announceInterception( 'preInstall', { installArgs=arguments, packagePathRequestingInstallation=packagePathRequestingInstallation } );

		// If there is a package to install, install it
		if( len( arguments.ID ) ) {

			// By default, a specific package install doesn't include dev dependencies
			arguments.production = arguments.production ?: true;

			var endpointData = endpointService.resolveEndpoint( arguments.ID, arguments.currentWorkingDirectory );

			job.start(  'Installing package [#endpointData.ID#]', ( shell.getTermHeight() < 20 ? 1 : 5 ) );

			if( verbose ) {
				job.setDumpLog( verbose );
			}

			var tmpPath = endpointData.endpoint.resolvePackage( endpointData.package, arguments.verbose );

			// Support box.json in the root OR in a subfolder (NPM-style!)
			tmpPath = findPackageRoot( tmpPath );

			// The code below expects these variables
			if( isPackage( tmpPath ) ) {
				var boxJSON = readPackageDescriptor( tmpPath );
				var packageType = boxJSON.type;
				var packageName = boxJSON.slug;
				var version = boxJSON.version;
			} else {
				job.addErrorLog( "box.json is missing so this isn't really a package! I'll install it anyway, but I'm not happy about it" );
				job.addWarnLog( "I'm just guessing what the package name, version and type are.  Please ask the package owner to add a box.json." );
				var packageType = 'project';
				var packageName = endpointData.endpoint.getDefaultName( endpointData.package );
				var version = '1.0.0';
			}

			// Todo, consider making this part of the interface so other endpoint types can also report back
			// if their installation ID contains a semantic version range
			if( isInstanceOf(endpointData.endpoint, 'forgebox') ) {
				var requestedVersionSemver = endpointData.endpoint.parseVersion( arguments.ID );
			} else {
				var requestedVersionSemver = version;
			}

			// If the dependency struct in box.json has a name, use it.  This is mostly for
			// HTTP, Jar, and Lex endpoints to be able to override their package name.
			if( defaultName.len() && packageName != defaultName ) {
				job.addWarnLog( "Package named [#defaultName#] from your box.json." );
				packageName = defaultName;
			}


			/******************************************************************************************************************/
			// Old Modules Build Check: If the zip file has a directory named after the package, that's our actual package root.
			// Remove once build process in ForgeBox and ContentBox are updated
			/******************************************************************************************************************/
			// If the root of the zip has a box.json, read the package name out first.
			var tmpName = packageName;
			if( isPackage( tmpPath ) ) {
				var packageDirectory = readPackageDescriptor( tmpPath ).packageDirectory;
				if( len( packageDirectory ) ) {
					tmpName = packageDirectory;
				}
			}
			var innerTmpPath = '#tmpPath#/#tmpName#';
			if( directoryExists( innerTmpPath ) ) {
				// Move the box.json if it exists into the inner folder
				var fromBoxJSONPath = '#tmpPath#/box.json';
				var toBoxJSONPath = '#innerTmpPath#/box.json';
				if( fileExists( fromBoxJSONPath ) ) {
					fileMove( fromBoxJSONPath, toBoxJSONPath );
				}
				// Repoint ourselves to the inner folder
				tmpPath = innerTmpPath;
			}
			/******************************************************************************************************************/

			// Now that we have resolved the directory where our package lives, read the box.json out of it.
			var artifactDescriptor = readPackageDescriptor( tmpPath );
			var ignorePatterns = ( isArray( artifactDescriptor.ignore ) ? artifactDescriptor.ignore : [] );


			// Assert: At this point we know what we're installing and we've acquired it, but we don't know where it will install to yet.

			// Determine if a satisfying version of this package is already installed here or at a higher level.  if so, skip it.
			// Modules are the only kind of packages that can be nested in a hierarchy, so the check only applies here.
			// We're also going to assume that they are in a "modules" folder.
			// This check also only applies if we're at least one level deep into modules.
			if( isPackageModule( packageType ) && currentWorkingDirectory != packagePathRequestingInstallation) {

				// We'll update this variable as we climb back up the directory structure
				var movingTarget = packagePathRequestingInstallation;
				// match "/modules/{myPackage}" at the end of a path
				var regex = '[/\\]modules[/\\][^/\\]*$';

				// Can we keep backing up?
				while( reFindNoCase( regex, movingTarget ) ) {

					// Back out of this  folder
					movingTarget = reReplaceNoCase( movingTarget, regex, '' );

					// If we didn't reach a package, I'm not sure what happened, but we can't really continue
					if( !isPackage( movingTarget ) ) {
						break;
					}

					// What does this package need installed?
					targetBoxJSON = readPackageDescriptor( movingTarget );

					// This ancestor package has a candidate installed that might satisfy our dependency
					if( structKeyExists( targetBoxJSON.installPaths, packageName ) ) {
						var candidateInstallPath = fileSystemUtil.resolvePath( targetBoxJSON.installPaths[ packageName ], movingTarget );
						if( isPackage( candidateInstallPath ) ) {
							var candidateBoxJSON = readPackageDescriptor( candidateInstallPath );
							// Does the package that we found satisfy what we need?
							if( semanticVersion.satisfies( candidateBoxJSON.version, requestedVersionSemver ) ) {
								job.addWarnLog( '#packageName# (#requestedVersionSemver#) is already satisfied by #candidateInstallPath# (#candidateBoxJSON.version#).  Skipping installation.' );
								job.complete( verbose );

								interceptorService.announceInterception( 'postInstall', { installArgs=arguments, installDirectory=candidateInstallPath } );

								return true;
							}
						}
					}

					// If we've reached the root dir, just quit
					if( movingTarget == currentWorkingDirectory) {
						break;
					}

				}

			}

			var installDirectory = '';

			// If the user gave us a directory, use it above all else
			if( structKeyExists( arguments, 'directory' ) ) {
				installDirectory = arguments.directory;

				// If this is an initial install (not a dependency) into a folder somewhere inside the CommandBox home,
				// make sure we save correctly to CommandBox's user module box.json.
				var commandBoxCFMLHome = fileSystemUtil.normalizeSlashes( expandPath( '/commandbox' ) );
				installDirectory = fileSystemUtil.normalizeSlashes( installDirectory );

				// If we're already in the CommandBox (a submodule of a commandbox module, most likely)
				if( installDirectory contains commandBoxCFMLHome ) {
					// Override the install directories to the CommandBox CFML root
					arguments.currentWorkingDirectory = installDirectory.listDeleteAt( installDirectory.listLen( '/\' ), '/\' );
					arguments.packagePathRequestingInstallation = arguments.currentWorkingDirectory;
				}

			}

			// Initialize as empty.  We try to populate this with the option that has the highest precedence first but stop once it has a value set.
			var packageDirectory = '';

			// Next, see if the containing project has an install path configured for this dependency already.
			var containerBoxJSON = readPackageDescriptor( arguments.packagePathRequestingInstallation );
			if( !len( installDirectory ) && structKeyExists( containerBoxJSON.installPaths, packageName ) ) {
				// Get the resolved installation path for this package
				installDirectory = fileSystemUtil.resolvePath( containerBoxJSON.installPaths[ packageName ], arguments.packagePathRequestingInstallation );

				// Use the last folder as the package directory in case the user wanted to override the default package name
				packageDirectory = listLast( installDirectory, '/\' );

				// Back up to the "container" folder.  The package directory will be added back below
				installDirectory = listDeleteAt( installDirectory, listLen( installDirectory, '/\' ), '/\' );
			}

			// Else, use directory in the target package's box.json if it exists
			if( !len( installDirectory ) && len( artifactDescriptor.directory ) ) {
				// Strip any leading slashes off of the install directory
				if( artifactDescriptor.directory.startsWith( '/' ) || artifactDescriptor.directory.startsWith( '\' ) ) {
					// Make sure it's not just a single slash
					if( artifactDescriptor.directory.len() > 2 ) {
						artifactDescriptor.directory = right( artifactDescriptor.directory, len( artifactDescriptor.directory ) - 1 );
					} else {
						artifactDescriptor.directory = '';
					}
				}
				installDirectory = arguments.currentWorkingDirectory & '/' & artifactDescriptor.directory;
			}

			// Gather all the interesting things this interceptor might need to know.
			var interceptData = {
				installArgs = arguments,
				installDirectory = installDirectory,
				containerBoxJSON = containerBoxJSON,
				artifactDescriptor = artifactDescriptor,
				ignorePatterns = ignorePatterns,
				endpointData = endpointData,
				artifactPath = tmpPath,
				packagePathRequestingInstallation = packagePathRequestingInstallation,
				job = job,
				skipInstall = false
			};
			interceptorService.announceInterception( 'onInstall', interceptData );
			// Make sure these get set back into their original variables in case the interceptor changed them.
			installDirectory = interceptData.installDirectory;
			ignorePatterns = interceptData.ignorePatterns;
			tmpPath = interceptData.artifactPath;

			// Set variable to allow interceptor-based skipping of package install
			var skipInstall = interceptData.skipInstall;

			// Else, use package type convention
			if( !len( installDirectory ) && len( packageType ) ) {
				// If this is a CommandBox command
				if( packageType == 'commandbox-commands' ) {
					// Setup installation directory and arguments as per type
					installDirectory = expandPath( '/commandbox-home/commands' );
					// Default creation of package to false if not defined by command descriptor
					artifactDescriptor.createPackageDirectory = artifactDescriptor.createPackageDirectory ?: false;
					// Default saving options and patterns
					arguments.save = false;
					arguments.saveDev = false;
					ignorePatterns.append( '/box.json' );
					// Flag the shell to reload after this command is finished.
					shellWillReload = true;
				// If this is a module
				} else if( packageType == 'modules' ) {
					installDirectory = arguments.packagePathRequestingInstallation & '/modules';
				// ContentBox Widget
				} else if( packageType == 'contentbox-widgets' ) {
					installDirectory = arguments.packagePathRequestingInstallation & '/modules/contentbox/widgets';
					// widgets just get dumped in
					artifactDescriptor.createPackageDirectory = false;
					// Don't trash the widgets folder with this
					ignorePatterns.append( '/box.json' );
				// ContentBox themes/layouts
				} else if( packageType == 'contentbox-themes' || packageType == 'contentbox-layouts' ) {
					installDirectory = arguments.packagePathRequestingInstallation & '/modules/contentbox/themes';
				// ContentBox Modules
				} else if( packageType == 'contentbox-modules' ) {
					installDirectory = arguments.packagePathRequestingInstallation & '/modules/contentbox/modules_user';
				// CommandBox Modules
				} else if( packageType == 'commandbox-modules' ) {
					var commandBoxCFMLHome = fileSystemUtil.normalizeSlashes( expandPath( '/commandbox' ) );
					arguments.packagePathRequestingInstallation = fileSystemUtil.normalizeSlashes( arguments.packagePathRequestingInstallation );

					// If we're already in the CommandBox (a submodule of a commandbox module, most likely)
					if( arguments.packagePathRequestingInstallation contains commandBoxCFMLHome ) {
						// Then just nest as normal.
						installDirectory = arguments.packagePathRequestingInstallation & '/modules';
					} else {
						// Override the install directories to the CommandBox CFML root
						arguments.currentWorkingDirectory = commandBoxCFMLHome;
						arguments.packagePathRequestingInstallation = commandBoxCFMLHome;
						installDirectory = expandPath( '/commandbox/modules' );
					}

				// If this is a plugin
				} else if( packageType == 'plugins' ) {
					installDirectory = arguments.packagePathRequestingInstallation & '/plugins';
					// Plugins just get dumped in
					artifactDescriptor.createPackageDirectory = false;
					// Don't trash the plugins folder with this
					ignorePatterns.append( '/box.json' );
				// If this is an interceptor
				} else if( packageType == 'interceptors' ) {
					installDirectory = arguments.packagePathRequestingInstallation & '/interceptors';
					// interceptors just get dumped in
					artifactDescriptor.createPackageDirectory = false;
					// Don't trash the plugins folder with this
					ignorePatterns.append( '/box.json' );
				// This is a jar.
				} else if( packageType == 'jars' ) {
					installDirectory = arguments.packagePathRequestingInstallation & '/lib';
				} else if( packageType == 'lucee-extensions' ) {
					// This is making several assumption, but if the directory of the installation is a Lucee server, then
					// assume the user wants this lex to be dropped in their server context's deploy folder.  To override this
					// behavior, specify a custom install directory in your box.json or in the "install" params.
					var serverDetails = serverService.resolveServerDetails( { directory = arguments.packagePathRequestingInstallation } );
					var serverInfo = serverDetails.serverInfo;

					if( !serverDetails.serverIsNew && serverInfo.engineName contains 'lucee' && len( serverInfo.serverConfigDir ) ) {
						var serverDeployFolder = serverInfo.serverConfigDir & '/lucee-server/deploy/';
						// Handle paths relative to the server home dir
						if( serverDeployFolder.uCase().startsWith('/WEB-INF' ) ) {
							serverDeployFolder = serverInfo.serverHomeDirectory & serverDeployFolder;
						}
						if( !directoryExists( serverDeployFolder ) ) {
							directoryCreate( serverDeployFolder, true, true );
						}
						job.addWarnLog( "Current dir seems to be a Lucee server." );
						job.addWarnLog( "Defaulting lex Install to [#serverDeployFolder#]" );
						installDirectory = serverDeployFolder;
						artifactDescriptor.createPackageDirectory = false;
						ignorePatterns.append( '/box.json' );
					} else {
						job.addWarnLog( "This package is a Lucee Extension, but no server was found in [#arguments.packagePathRequestingInstallation#]" );
						if( !serverDetails.serverIsNew && !(serverInfo.engineName contains 'lucee') ) {
							job.addWarnLog( "We did find a server, but the engine is [#serverInfo.engineName#] instead of 'lucee'" );
						}

					}

				}
			}


			// If this package is being installed anywhere south of the CommandBox system folder,
			// flag the shell to reload after this command is finished.
			if( fileSystemUtil.normalizeSlashes( installDirectory ).startsWith( fileSystemUtil.normalizeSlashes( expandPath( '/commandbox' ) ) ) ) {
				shellWillReload = true;
			}

			// I give up, just stick it in the CWD
			if( !len( installDirectory ) ) {
				installDirectory = arguments.currentWorkingDirectory;
			}

			// Override package directory in descriptor?
			if( len( artifactDescriptor.packageDirectory ) && !packageDirectory.len() ) {
				packageDirectory = artifactDescriptor.packageDirectory;
			}

			// Still empty?  Use a default value of the package name
			if( !packageDirectory.len() ) {
				packageDirectory = packageName;
			}

			// Some packages may just want to be dumped in their destination without being contained in a subfolder
			// If the box.json had an explicit override for the install directory, then we're just going to use it directly
			if( artifactDescriptor.createPackageDirectory || structKeyExists( containerBoxJSON.installPaths, packageName ) ) {
				installDirectory &= '/#packageDirectory#';
			// If we're dumping in the root and the install dir is already another package then ignore box.json or it will overwrite the existing one
			// If the directory wasn't already a package, still save so our box.json gets install paths added
			} else if( isPackage( installDirectory ) && readPackageDescriptor( installDirectory ).slug != packageName ) {
				ignorePatterns.append( '/box.json' );
			}

			// Assert: At this point, all paths are finalized and we are ready to install.

			// Should we save this as a dependency. Save the install even though the package may already be there
			if( ( arguments.save || arguments.saveDev ) ) {
				// Add it!
				if( addDependency( packagePathRequestingInstallation, packageName, version, installDirectory, artifactDescriptor.createPackageDirectory,  arguments.saveDev, endpointData ) ) {
					// Tell the user...
					job.addLog( "#packagePathRequestingInstallation#/box.json updated with #( arguments.saveDev ? 'dev ': '' )#dependency." );
				}
			}

			// Check to see if package has already been installed.  This check can only be performed for packages that get installed in their own directory.
			// OR if the install dir has a box.json that is the package being installed.
			if( directoryExists( installDirectory ) && ( artifactDescriptor.createPackageDirectory || readPackageDescriptor( installDirectory ).slug == packageName ) ){
				var uninstallFirst = false;

				// Make sure the currently installed version is older than what's being requested.  If there's a new version, install it anyway.
				var alreadyInstalledBoxJSON = readPackageDescriptor( installDirectory );
				if( !skipInstall && isPackage( installDirectory ) && semanticVersion.isNew( alreadyInstalledBoxJSON.version, version  )  ) {
					job.addLog( "Package already installed but its version [#alreadyInstalledBoxJSON.version#] is older than the new version being installed [#version#].  Forcing a reinstall." );
					uninstallFirst = true;
				// If a newer version exists than what was asked for, blow it away so we can get a clean downgrade.
				 } else if( !skipInstall && isPackage( installDirectory ) && semanticVersion.isNew( version, alreadyInstalledBoxJSON.version )  ) {
					job.addLog( "Package already installed but its version [#alreadyInstalledBoxJSON.version#] is newer than the version being installed [#version#].  Forcing a reinstall." );
					uninstallFirst = true;
				// Allow if forced.
				} else if( !skipInstall && arguments.force ) {
					job.addLog( "Package already installed but you forced a reinstall." );
					uninstallFirst = true;
				// Check for empty directories that sometimes get left behind, but really shouldn't count as the package actually being there.
				} else if( !skipInstall && !directorylist( installDirectory ).len() ) {
					job.addLog( "Package directory exists, but is empty so we're going to assume it's not really installed." );
					uninstallFirst = true;
				} else {
					// cleanup tmp
					tempDir = fileSystemUtil.resolvePath( tempDir );
					tmpPath = fileSystemUtil.resolvePath( tmpPath );
					if( tmpPath contains tempDir ) {
						var pathInsideTmp = tmpPath.replaceNoCase( tempDir, '' );
						// Delete the top most directory inside the temp folder
						directoryDelete( tempDir & '/' & pathInsideTmp.listFirst( '/\' ), true );
					}
					if( skipInstall ) {
						job.addWarnLog( "Skipping installation of package #packageName#." );
					} else {
						job.addWarnLog( "The package #packageName# is already installed at #installDirectory#. Skipping installation. Use --force option to force install." );
					}
					job.complete( verbose );

					interceptorService.announceInterception( 'postInstall', { installArgs=arguments, installDirectory=installDirectory } );

					return true;
				}

				if( uninstallFirst && artifactDescriptor.createPackageDirectory ) {
					job.addWarnLog( "Uninstalling first to get a fresh slate..." );

					var params = {
						id : packageName,
						save : false,
						directory : installDirectory,
						currentWorkingDirectory : currentWorkingDirectory,
						packagePathRequestingUninstallation : packagePathRequestingInstallation
					};

					uninstallPackage( argumentCollection=params );
				}

			}

			// Create installation directory if necessary
			if( !directoryExists( installDirectory ) ) {
				directoryCreate( installDirectory );
			}
			// Prepare results struct
			var results = {
				copied = [],
				ignored = []
			};

			// This will normalize the slashes to match
			tmpPath = fileSystemUtil.resolvePath( tmpPath );
			var thisPathPatternMatcher = pathPatternMatcher.$get();

			// Copy Assets now to destination
			directoryCopy( tmpPath, installDirectory, true, function( path ){
				// This will normalize the slashes to match
				arguments.path = fileSystemUtil.resolvePath( arguments.path );
				// Directories need to end in a trailing slash
				if( directoryExists( arguments.path ) ) {
					arguments.path &= server.separator.file;
				}
				// cleanup path so we just get from the archive down
				var thisPath = replacenocase( arguments.path, tmpPath, "" );
				// Ignore paths that match one of our ignore patterns
				var ignored = thisPathPatternMatcher.matchPatterns( ignorePatterns, thisPath );
				// What do we do with this file/directory
				if( ignored ) {
					results.ignored.append( thisPath );
					return false;
				} else {
					results.copied.append( thisPath );
					return true;
				}
			});

			// Stupid annoying fix For *nix file systems because Lucee LOSES the executable bit on files when zipping or copying them
			// I'm detecting JRE/JDK installations and attempting to make the files executable again.
			if( !fileSystemUtil.isWindows() && artifactDescriptor.createPackageDirectory && fileExists( installDirectory & '/bin/java' ) ) {
				job.addWarnLog( 'Fixing *nix file permissions on java' );

				directoryList( installDirectory , true ).each( function( path ) {
					fileSetAccessMode( path, 755 );
				} );

			}

			// Catch this to gracefully handle where the OS or another program
			// has the folder locked.
			try {
				// cleanup unzip
				tempDir = fileSystemUtil.resolvePath( tempDir );
				if( tmpPath contains tempDir ) {
					var pathInsideTmp = tmpPath.replaceNoCase( tempDir, '' );
					// Delete the top most directory inside the temp folder
					directoryDelete( tempDir & '/' & pathInsideTmp.listFirst( '/\' ), true );
				}
			} catch( any e ) {
				job.addErrorLog( e.message );
				job.addErrorLog( 'The folder is possibly locked by another program.' );
				logger.error( '#e.message# #e.detail#' , e.stackTrace );
			}


			// Summary output
			job.addLog( "Installing to: #installDirectory#" );
			job.addLog( "-> #results.copied.len()# File(s) Installed" );
			job.addLog( "-> #results.ignored.len()# File(s) ignored" );

			job.addSuccessLog( "Eureka, '#arguments.ID#' has been installed!" );

		// If no package ID was specified, just get the dependencies for the current directory
		} else {
			// read it...
			var artifactDescriptor = readPackageDescriptor( arguments.currentWorkingDirectory );
			var installDirectory = arguments.currentWorkingDirectory;

			// By default, a general package install includes dev dependencies
			arguments.production = arguments.production ?: false;
			job.start( 'Installing ALL dependencies' );
		}

		// and grab all the dependencies
		var dependencies = artifactDescriptor.dependencies;

		// If we're not in production mode...
		if( !arguments.production ) {
			// Add in the devDependencies
			dependencies.append( artifactDescriptor.devDependencies );
		}

		// Loop over this package's dependencies
		for( var dependency in dependencies ) {
			var isDev = structKeyExists( artifactDescriptor.devDependencies, dependency );
			var isSaving = ( arguments.save || arguments.saveDev );

			var detail = dependencies[ dependency ];
			//  full ID with endpoint and package like file:/opt/files/foo.zip
			if( detail contains ':' ) {
				var ID = detail;
			// Default ForgeBox endpoint of foo@1.0.0
			} else {
				var ID = dependency & '@' & detail;
			}

			var params = {
				ID = ID,
				force = arguments.force,
				verbose = arguments.verbose,
				// Nested dependencies are already in the box.json, but the save will update the installPaths
				save = ( isSaving && !isDev ),
				saveDev = ( isSaving && isDev ),
				// Nested packages never get dev dependencies
				production = true,
				currentWorkingDirectory = arguments.currentWorkingDirectory, // Original dir
				packagePathRequestingInstallation = installDirectory, // directory for smart dependencies to use
				defaultName = dependency
			};

			// Recursively install them
			installPackage( argumentCollection = params );
		}

		if( !len( arguments.ID ) && dependencies.isEmpty() ) {
			job.addLog( "No dependencies found to install, but it's the thought that counts, right?" );
		}

		if( shellWillReload && artifactDescriptor.createPackageDirectory && fileExists( installDirectory & '/ModuleConfig.cfc' ) ) {
			consoleLogger.warn( 'Activating your new module for instant use...' );
			moduleService.registerAndActivateModule( installDirectory.listLast( '/\' ), fileSystemUtil.makePathRelative( installDirectory ).listToArray( '/\' ).slice( 1, -1 ).toList( '.' ) );
		}

		interceptorService.announceInterception( 'postInstall', { installArgs=arguments, installDirectory=installDirectory } );
		job.complete( verbose );

		return true;
	}

	// DRY
	boolean function isPackageModule( required string packageType ) {
		// Is the package type that of a module?
		return ( listFindNoCase( 'modules,contentbox-modules,commandbox-modules', arguments.packageType ) > 0) ;
	}


	/******************************************************************************************************************/
	// If the root of the current package doesn't have a box.json, check if there is a subdirectory that contains
	// a box.json.  This would be the NPM-style standard where a zip contains a package in a sub folder.
	/******************************************************************************************************************/
	function findPackageRoot( packagePath ) {
		var JSONPath = '#packagePath#/box.json';
		if( !fileExists( JSONPath ) ) {
			// Check for a package in a sub folder
			var list = directoryList( absolute_path=packagePath, listInfo='query' );
			// Look at each path inside
			for( var row in list ) {
				// Specifically directories...
				if( row.type == 'dir' ) {
					var thisDir = listLast( row.name, '/\' );
					var subPath = '#packagePath#/#thisDir#';
					var subJSONPath = '#subPath#/box.json';
					// If one of them has a box.json in it...
					if( fileExists( subJSONPath ) ) {
						// Repoint ourselves to the inner folder
						packagePath = subPath;
						break;
					}
				}
			}
		}
		return packagePath;
	}

	/**
	* Uninstalls a package and its dependencies
	* @ID Identifier of the package to uninstall.
	* @directory The directory to install in. This will override the packages box.json install dir if provided.
	* @save Remove package as a dependency in box.json (if it exists)
	* @saveDev Remove package as a dev dependency in box.json (if it exists)
	* @currentWorkingDirectory Root of the application (used for finding box.json)
	**/
	function uninstallPackage(
			required string ID,
			string directory,
			boolean save=false,
			required string currentWorkingDirectory,
			string packagePathRequestingUninstallation = arguments.currentWorkingDirectory,
			boolean verbose = false
	){

		var job = wirebox.getInstance( 'interactiveJob' );
		var packageName = arguments.ID;

		job.start( 'Uninstalling package: #packageName#' );
		if( verbose ) {
			job.setDumpLog( verbose );
		}

		var uninstallDirectory = '';

		// If a directory is passed in, use it
		if( structKeyExists( arguments, 'directory' ) ) {
			var uninstallDirectory = arguments.directory;
		// Otherwise, are we a package
		} else if( isPackage( arguments.currentWorkingDirectory ) ) {
			// Read the box.json
			var boxjson = readPackageDescriptor( arguments.currentWorkingDirectory );
			var installPaths = boxJSON.installPaths;

			// Is there an install path for this?
			if( structKeyExists( installPaths, packageName ) ) {
				uninstallDirectory = fileSystemUtil.resolvePath( installPaths[ packageName ], arguments.currentWorkingDirectory );
			}
		}

		// Wait to run this until we've decided where the package lives that's being uninstalled.
		interceptorService.announceInterception( 'preUninstall', { uninstallArgs=arguments, uninstallDirectory=uninstallDirectory } );

		// See if the package exists here
		if( len( uninstallDirectory ) && directoryExists( uninstallDirectory ) ) {

			// Get the dependencies of the package we're about to uninstalled
			var boxJSON = readPackageDescriptor( uninstallDirectory );
			// and grab all the dependencies
			var dependencies = boxJSON.dependencies;
			var type = boxJSON.type;
			var installpaths = boxJSON.installPaths;
			// Add in the devDependencies
			dependencies.append( boxJSON.devDependencies );

		} else {
			// If the package isn't on disk, no dependencies
			var dependencies = {};
			var installpaths = {};
			var type = '';
		}

		// ColdBox modules are stored in a hierarchy so just removing the top one removes then all
		// For all other packages, the dependencies are probably just in the root
		if( !isPackageModule( type ) ) {

			if( dependencies.count() ) {
				job.addLog( "Uninstalling dependencies first..." );
			}

			// Loop over this packages dependencies
			for( var dependency in dependencies ) {

				var params = {
					ID = dependency,
					// Only save the first level
					save = false,
					currentWorkingDirectory = uninstallDirectory,
					packagePathRequestingUninstallation=arguments.packagePathRequestingUninstallation
				};

				// If we know where the dependency is installed, save ourselves some trouble of guessing
				if( installpaths.keyExists( dependency ) ) {
					params.directory = fileSystemUtil.resolvePath( installpaths[ dependency ], uninstallDirectory );
				}

				// Recursively install them
				uninstallPackage( argumentCollection = params );
			}

		} // end is not module

		// uninstall the package
		if( len( uninstallDirectory ) && directoryExists( uninstallDirectory ) ) {


			// If this package is being uninstalled anywhere south of the CommandBox system folder, unload the module first
			if( fileSystemUtil.normalizeSlashes( uninstallDirectory ).startsWith( fileSystemUtil.normalizeSlashes( expandPath( '/commandbox' ) ) ) && fileExists( uninstallDirectory & '/ModuleConfig.cfc' ) ) {
				consoleLogger.warn( 'Unloading module...' );
				try {
					moduleService.unloadAndUnregisterModule( uninstallDirectory.listLast( '/\' ) );
					// Heavy-handed workaround for the fact that the module service does not unload
					// WireBox mappings for this module so they stay in memory
					wirebox.getCacheBox().getCache( 'metadataCache' ).clearAll();
				} catch( any e ) {
					job.addErrorLog( 'Error Unloading module: ' & e.message & ' ' & e.detail );
					logger.error( '#e.message# #e.detail#' , e.stackTrace );
				}
			}

			// Catch this to gracefully handle where the OS or another program
			// has the folder locked.
			try {
				directoryDelete( uninstallDirectory, true );
			} catch( any e ) {
				job.addLog( e.message );
				job.addLog( 'The folder is possibly locked by another program.' );
				logger.error( '#e.message# #e.detail#' , e.stackTrace );
			}

			job.addLog( "'#packageName#' has been uninstalled" );

		} else if( !len( uninstallDirectory ) ) {
			job.addLog( "Package [#packageName#] skipped, it doesn't appear to be installed." );

		} else {
			job.addWarnLog( 'Package [#uninstallDirectory#] not found.' );
		}


		// Should we save this as a dependency
		// and is the current working directory a package?
		if( arguments.save && isPackage( arguments.currentWorkingDirectory ) ) {
			// Add it!
			removeDependency( currentWorkingDirectory, packageName );
			// Tell the user...
			job.addLog( "Dependency removed from box.json." );
		}

		interceptorService.announceInterception( 'postUninstall', { uninstallArgs=arguments } );
		job.complete();
	}

	/**
	* Adds a dependency to a package
	* @currentWorkingDirectory The directory that is the root of the package
	* @packageName Package to add a a dependency
	* @version Version of the dependency
	* @installDirectory The location that the package is installed to including the container folder.
	* @installDirectoryIsDedicated True if the package was placed in a dedicated folder
	* @dev True if this is a development dependency, false if it is a production dependency
	*
	* @returns boolean True if box.json was updated, false if update wasn't necessary (keys already existed with correct values)
	*/
	public function addDependency(
		required string currentWorkingDirectory,
		required string packageName,
		required string version,
		string installDirectory='',
		boolean installDirectoryIsDedicated = true,
		boolean dev=false,
		struct endpointData
		) {
		// Get box.json, create empty if it doesn't exist
		var boxJSONRaw = readPackageDescriptorRaw( arguments.currentWorkingDirectory );
		// Reading the non-raw version purely for the purpose of comparisons with the env vars replaced.
		var boxJSON = readPackageDescriptor( arguments.currentWorkingDirectory );

		// Get reference to appropriate dependency struct
		// Save as dev if we have that flag OR if this is already saved as a dev dep
		if( arguments.dev || !isNull( boxJSONRaw.devDependencies[ arguments.packageName ] ) ) {
			boxJSONRaw[ 'devDependencies' ] = boxJSONRaw.devDependencies ?: {};
			boxJSON[ 'devDependencies' ] = boxJSON.devDependencies ?: {};

			// If this package is also saved as a normal dev, remove it from "dependencies"
			if( !isNull( boxJSONRaw.dependencies[ arguments.packageName ] ) ) {
				boxJSONRaw.dependencies.delete( arguments.packageName );
			}

			var dependenciesRaw = boxJSONRaw.devDependencies;
			var dependencies = boxJSON.devDependencies;
		} else {
			boxJSONRaw[ 'dependencies' ] = boxJSONRaw.dependencies ?: {};
			boxJSON[ 'dependencies' ] = boxJSON.dependencies ?: {};
			var dependenciesRaw = boxJSONRaw.dependencies;
			var dependencies = boxJSON.dependencies;
		}
		var updated = false;

		// If this is a ForgeBox-based endpoint, add the version as ^1.2.3 if the
		// user didn't specify a version, otherwise, just use what they typed
		if( isInstanceOf(endpointData.endpoint, 'forgebox') ) {
            var parsedVersion = parseVersion( endpointData.package );
			if( len( parsedVersion ) ) {
				var thisValue = parsedVersion;
			} else {
				// caret version range (^1.2.3) allows updates that don't bump the major version.
				var thisValue = '^' & arguments.version;
			}
			// If not the default forgebox endpoint, include the endpoint name and package name as
			// myEndpoing:mypackage@^1.2.3
			if( endpointData.endpointName != 'forgebox' ) {
				thisValue = '#endpointData.endpointName#:#arguments.packageName#@#thisValue#';
			}
		} else {
			var thisValue = endpointData.ID;
		}

		// Prevent unnecessary updates to the JSON file.
		// For the comparison, we look in the non-raw version of the box.json so env vars are replaced
		if( !dependencies.keyExists( arguments.packageName ) || dependencies[ arguments.packageName ] != thisValue ) {
			dependenciesRaw[ arguments.packageName ] = thisValue;
			updated = true;
		}

		// Only packages installed in a dedicated directory of their own can be uninstalled
		// so don't save this if they were just dumped somewhere like the package root amongst
		// other unrelated files and folders.
		if( arguments.installDirectoryIsDedicated ) {
			boxJSONRaw[ 'installPaths' ] = boxJSONRaw.installPaths ?: {};
			var installPaths = boxJSONRaw.installPaths;

			// normalize slashes and make them all "/"
			arguments.currentWorkingDirectory = fileSystemUtil.normalizeSlashes( fileSystemUtil.resolvePath( arguments.currentWorkingDirectory ) );
			arguments.installDirectory = fileSystemUtil.normalizeSlashes( fileSystemUtil.resolvePath( arguments.installDirectory ) );

			// If the folder doesn't exist yet, make sure we still have a trailing slash on the path.
			if( !installDirectory.endsWith( '/' ) ) {
				installDirectory &= '/';
			}

			// If the install location is contained within the package root...
			if( arguments.installDirectory contains arguments.currentWorkingDirectory ) {
				// Make it relative
				arguments.installDirectory = replaceNoCase( arguments.installDirectory, arguments.currentWorkingDirectory, '' );
				// Strip any leading slashes so Unix-based OS's don't think it's the drive root
				if( len( arguments.installDirectory ) && arguments.installDirectory.left( 1 ) == '/' ) {
					arguments.installDirectory = right( arguments.installDirectory, len( arguments.installDirectory ) - 1 );
				}
			}

			var existingInstallPath = '';
			if( installPaths.keyExists( arguments.packageName ) ) {
				existingInstallPath = fileSystemUtil.normalizeSlashes( fileSystemUtil.resolvePath( installPaths[ arguments.packageName ], arguments.currentWorkingDirectory ) );
				// If the install location is contained within the package root...
				if( existingInstallPath contains arguments.currentWorkingDirectory ) {
					// Make it relative
					existingInstallPath = replaceNoCase( existingInstallPath, arguments.currentWorkingDirectory, '' );
					// Strip any leading slashes so Unix-based OS's don't think it's the drive root
					if( len( existingInstallPath ) && existingInstallPath.left( 1 ) == '/' ) {
						existingInstallPath = right( existingInstallPath, len( existingInstallPath ) - 1 );
					}
				}
			}

			// Just in case-- an empty install dir would be useless.
			if( len( arguments.installDirectory ) ) {

				// Prevent unnecessary updates to the JSON file.
				if( !installPaths.keyExists( arguments.packageName )
					// Resolve the install path in box.json. If it's relative like ../lib but it's still equivalent to the actual install dir, then leave it alone. The user probably wants to keep it relative!
					|| existingInstallPath != arguments.installDirectory ) {
					installPaths[ arguments.packageName ] = arguments.installDirectory;
					updated = true;

				}

			}

		} // end installDirectoryIsDedicated

		// Write the box.json back out
		if( updated ) {
			writePackageDescriptor( boxJSONRaw, arguments.currentWorkingDirectory );
			return true;
		}
		return false;
	}

	/**
	* Removes a dependency from a package if it exists
	* @directory The directory that is the root of the package
	* @packageName Package to add a a dependency
	* @dev True if this is a development dependency, false if it is a production dependency
	*/
	public function removeDependency( required string directory, required string packageName ) {
		// Get box.json, create empty if it doesn't exist
		var boxJSON = readPackageDescriptorRaw( arguments.directory );


		var saveMe = false;

		if( structKeyExists( boxJSON, 'dependencies' ) && structKeyExists( boxJSON.dependencies, arguments.packageName ) ) {
			saveMe = true;
			structDelete( boxJSON.dependencies, arguments.packageName );
		}

		if( structKeyExists( boxJSON, 'devdependencies' ) && structKeyExists( boxJSON.devdependencies, arguments.packageName ) ) {
			saveMe = true;
			structDelete( boxJSON.devdependencies, arguments.packageName );
		}

		if( structKeyExists( boxJSON, 'installPaths' ) && structKeyExists( boxJSON.installPaths, arguments.packageName ) ) {
			saveMe = true;
			structDelete( boxJSON.installPaths, arguments.packageName );
		}

		// Only save if we modified the JSON
		if( saveMe ) {
			// Write the box.json back out
			writePackageDescriptor( boxJSON, arguments.directory );
		}
	}

	/**
	* Get the default package description, AKA box.json
	* @defaults A struct of default values to be merged into the empty, default document
	*/
	public function newPackageDescriptor( struct defaults={}, boolean omitDeprecated=false ) {

		// TODO: Get author info from default CommandBox config

		// Read the default JSON file and deserialize it.
		var boxJSON = DeserializeJSON( fileRead( expandPath( '/commandBox/system/config/box.json.txt' ) ) );

		// Remove deprecated (or just edge case) properties
		// from the box.json template as to not confuse people.
		if( arguments.omitDeprecated ) {

			// most packages shouldn't need to set these
			boxJSON.delete( 'directory' );
			boxJSON.delete( 'createPackageDirectory' );
			boxJSON.delete( 'packageDirectory' );

			// These aren't even used
			boxJSON.delete( 'engines' );
			boxJSON.delete( 'defaultEngine' );

			// This went out of style with server.json
			boxJSON.delete( 'defaultPort' );
		}

		// Replace things passed via parameters
		boxJSON = boxJSON.append( arguments.defaults );

		return boxJSON;

	}

	/**
	* Get the box.json as data from the passed directory location.
	* Any missing properties will be defaulted with our box.json template.
	* If you plan on writing the box.json back out to disk, use readPackageDescriptorRaw() instead.
	*
	* If you ask for system settings to be swapped out, do not write this box.json back to disk.
	* It's has possibly been modified to expand the props like ${foo} and will overwrite the actual place holders
	*
	* @directory The directory to search for the box.json
	*/
	struct function readPackageDescriptor( required directory, boolean expandSystemSettings=true ){
		// Merge this JSON with defaults
		var results = newPackageDescriptor( readPackageDescriptorRaw( arguments.directory ) );
		// Expand stuff like ${foo:bar}
		if( expandSystemSettings ) {
			systemSettings.expandDeepSystemSettings( results );
		}
		return results;

	}

	/**
	* Does everything readPackageDescriptor() does, but won't default deprecated box.json properties.
	* @directory The directory to search for the box.json
	*/
	struct function readPackageDescriptorTemplate( required directory ){
		// Merge this JSON with defaults
		return newPackageDescriptor( readPackageDescriptorRaw( arguments.directory ), true );
	}

	/**
	* Get the box.json as data from the passed directory location, if not found
	* then we return an empty struct.  This method will NOT default box.json properties
	* and will return JUST what was defined.  Make sure you use existence checks when
	* using the returned data structure
	* @directory The directory to search for the box.json
	*/
	struct function readPackageDescriptorRaw( required directory ){

		// If the package has a box.json in the root...
		if( isPackage( arguments.directory ) ) {

			// ...Read it.
			boxJSON = fileRead( getDescriptorPath( arguments.directory ) );

			// Validate the file is valid JSON
			if( isJSON( boxJSON ) ) {
				return deserializeJSON( boxJSON );
			} else {
				consoleLogger.warn( 'Warning: package has an invalid box.json file. [#arguments.directory#]' );
			}

		}
		// Just return defaults
		return {};
	}

	/**
	* Write the box.json data as a JSON file
	* @JSONData The JSON data to write to the file. Can be a struct, or the string JSON
	* @directory The directory to write the box.json
	*/
	function writePackageDescriptor( required any JSONData, required directory ){
		JSONService.writeJSONFile( getDescriptorPath( arguments.directory ), JSONData );
	}

	/**
	* Return an array of all outdated dependencies in a project.
	* @directory The directory of the package to start in
	* @print The print buffer used for command operation
	* @verbose Outputs additional information about each package as it is checked
	* @includeSlugs A commit-delimited list of slugs to include.  Empty means include everything.
	*
	* @return An array of structs of outdated dependencies
	*/
	array function getOutdatedDependencies( required directory, required print, boolean verbose=false, includeSlugs='' ){
		// build dependency tree
		arguments.directory = fileSystemUtil.normalizeSlashes( arguments.directory );
		arguments.directory = right( arguments.directory, 1 ) == "/" ?
			left( arguments.directory, len( arguments.directory ) - 1 ) :
			arguments.directory;
		var tree 	= buildDependencyHierarchy( arguments.directory );
		var fakeDir = arguments.directory & '/fake';

		// Global outdated check bit
		var aAllDependencies = [];

		// Outdated check closure
		var fOutdatedCheck 	= function( slug, value ){
			if( !len( includeSlugs ) || listFindNoCase( includeSlugs, arguments.slug ) ){

				// If a package is not installed (possibly a dev dependency in production mode), then we skip it
				if( !value.isInstalled ) {
					if( verbose ){
						print.yellowLine( "    * #arguments.slug# is not installed, skipping.." )
							.toConsole();
					}
					return;
				}

				// Contains an enpoint
				if( value.version contains ':' ) {
					var ID = value.version;
				} else {
					var ID = arguments.slug & '@' & value.version;
				}

				try {
					var endpointData = endpointService.resolveEndpoint( ID, fakeDir );
				} catch( EndpointNotFound var e ) {
					consoleLogger.error( e.message );
					return;
				}

				try {
					var updateData = endpointData.endpoint.getUpdate( endpointData.package, value.packageVersion, verbose );
				// endpointException exception type is used when the endpoint has an issue that needs displayed,
				// but I don't want to "blow up" the console with a full error.
				} catch( endpointException var e ) {
					consoleLogger.error( e.message & ' ' & e.detail );
					return;
				}

				try {
					var latestData = endpointData.endpoint.getUpdate( arguments.slug & "@stable", value.packageVersion, verbose );
				} catch( EndpointNotFound var e ) {
					consoleLogger.error( e.message );
					return;
				}

				value.directory = fileSystemUtil.normalizeSlashes( value.directory )
				var dependencyInfo = {
					'slug' 				: arguments.slug,
					'directory' 		: value.directory,
					'version' 			: value.version,
					'packageVersion'	: value.packageVersion,
					'newVersion' 		: updateData.version,
					'latestVersion'     : latestData.version,
					'shortDescription' 	: value.shortDescription,
					'name' 				: value.name,
					'dev' 				: value.dev,
					'isOutdated'        : updateData.isOutdated,
					'isLatest'          : !latestData.isOutdated,
					'location'          : replace( value.directory, directory, "" ) & "/" & slug,
					'endpointName'		: endpointData.endpointName,
					'depth'				: value.depth
				};

				aAllDependencies.append( dependencyInfo );

			}

			// Do we have more dependencies, go down the tree in parallel
			if( structCount( value.dependencies ) ){
				structEach( value.dependencies, fOutdatedCheck, true );
			}
		};

		// Verify outdated dependency graph in parallel
		structEach( tree.dependencies, fOutdatedCheck, true );

		return aAllDependencies;
	}

	/**
	* Builds a struct of structs that represents the dependency hierarchy
	* @directory The directory of the package to start in
	* @depth how deep to climb down the rabbit hole.  A value of 0 means infinite depth
	*/
	function buildDependencyHierarchy( required directory, depth=0 ){

		var boxJSON = readPackageDescriptor( arguments.directory );
		var tree = {
			'name' : boxJSON.name,
			'slug' : boxJSON.slug,
			'shortDescription' : boxJSON.shortDescription,
			'version': boxJSON.version,
			'packageVersion': boxJSON.version,
			'isInstalled': true,
			'directory': arguments.directory,
			'depth': 0
		};
		buildChildren( boxJSON, tree, arguments.directory, depth, 1 );
		return tree;
	}

	private function buildChildren( required struct boxJSON, required struct parent, required string basePath, depth=0, currentlevel ) {
		// If we've reached our depth stop here
		if( depth > 0 && currentLevel > depth ) {
			parent[ 'dependencies' ] = {};
			return;
		}
		parent[ 'dependencies' ] = processDependencies( boxJSON.dependencies, boxJSON.installPaths, false, arguments.basePath, depth, currentlevel );
		parent[ 'dependencies' ].append( processDependencies( boxJSON.devDependencies, boxJSON.installPaths, true, arguments.basePath, depth, currentlevel ) );
	}

	private function processDependencies( dependencies, installPaths, dev=false, basePath, depth=0, currentlevel ) {
		var thisDeps = {};

		for( var dependency in arguments.dependencies ) {
			thisDeps[ dependency ] = {
				'version' : arguments.dependencies[ dependency ],
				'dev' : arguments.dev,
				'name' : '',
				'shortDescription' : '',
				'packageVersion' : '',
				'isInstalled': false,
				'directory': '',
				'depth': currentlevel
			};

			if( structKeyExists( arguments.installPaths, dependency ) ) {

				var fullPackageInstallPath = fileSystemUtil.resolvePath( arguments.installPaths[ dependency ], arguments.basePath );

				if( directoryExists( fullPackageInstallPath ) ) {
					var boxJSON = readPackageDescriptor( fullPackageInstallPath );
					thisDeps[ dependency ][ 'name'  ] = boxJSON.name;
					thisDeps[ dependency ][ 'shortDescription'  ] = boxJSON.shortDescription;
					thisDeps[ dependency ][ 'packageVersion'  ] = boxJSON.version;
					thisDeps[ dependency ][ 'isInstalled'  ] = true;

					if( boxJSON.createPackageDirectory ) {
						// Back up to the "container" folder.  The package directory will be added back on installation
						thisDeps[ dependency ][ 'directory'  ] = listDeleteAt( fullPackageInstallPath, listLen( fullPackageInstallPath, '/\' ), '/\' );
					} else {
						thisDeps[ dependency ][ 'directory'  ] = fullPackageInstallPath;
					}

					// Down the rabbit hole
					buildChildren( boxJSON, thisDeps[ dependency ], fullPackageInstallPath, depth, currentlevel+1 );

				} else {
					thisDeps[ dependency ][ 'isInstalled'  ] = false;
				}

			}

			// If we don't have an install path for this package, we don't know about its dependencies
			thisDeps[ dependency ][ 'dependencies' ] = thisDeps[ dependency ][ 'dependencies' ] ?: {};

		}

		return thisDeps;
	}

	/**
	* Dynamic completion for property name based on contents of box.json
	* @directory The package root
	* @all Pass false to ONLY suggest existing property names.  True will suggest all possible box.json properties.
	* @asSet Pass true to add = to the end of the options
	*/
	function completeProperty( required directory, all=false, asSet=false ) {
		var props = [];

		// Check and see if box.json exists
		if( isPackage( arguments.directory ) ) {
			if( arguments.all ) {
				var boxJSON = readPackageDescriptor( arguments.directory );
			} else {
				var boxJSON = readPackageDescriptorRaw( arguments.directory );
			}
			props = JSONService.addProp( props, '', '', boxJSON );
		}
		if( asSet ) {
			props = props.map( function( i ){ return i &= '='; } );
		}
		return props;
	}

	/**
	* Nice wrapper to run a package script
	*
	* @scriptName Name of the package script to run
	* @directory The package root
	* @ignoreMissing Set true to ignore missing package scripts, false to throw an exception
	* @interceptData An optional struct of data if this package script is being fired as part of an interceptor announcement.  Will be loaded into env vars
	*/
	function runScript( required string scriptName, string directory=shell.pwd(), boolean ignoreMissing=true, interceptData={} ) {
			// Read the box.json from this package (if it exists)
			var boxJSON = readPackageDescriptorRaw( arguments.directory );
			// If there is a scripts object with a matching key for this interceptor....
			if( boxJSON.keyExists( 'scripts' ) && isStruct( boxJSON.scripts ) && boxJSON.scripts.keyExists( arguments.scriptName ) ) {

				// Skip this if we're not in a command so we don't litter the default env var namespace
				if( systemSettings.getAllEnvironments().len() > 1 ) {
					systemSettings.setDeepSystemSettings( interceptData );
				}

				// Run preXXX package script
				runScript( 'pre#arguments.scriptName#', arguments.directory, true );

				systemSettings.expandDeepSystemSettings( boxJSON );
				var thisScript = boxJSON.scripts[ arguments.scriptName ];
				consoleLogger.debug( '.' );
				consoleLogger.warn( 'Running package script [#arguments.scriptName#].' );
				consoleLogger.debug( '> ' & thisScript );

				// Normally the shell retains the previous exit code, but in this case
				// it's important for us to know if the scripts return a failing exit code without throwing an exception
				shell.setExitCode( 0 );

				// ... then run the script! (in the context of the package's working directory)
				var previousCWD = shell.pwd();
				shell.cd( arguments.directory );
				shell.callCommand( thisScript );
				shell.cd( previousCWD );

				// If the script ran "exit"
				if( !shell.getKeepRunning() ) {
					// Just kidding, the shell can stay....
					shell.setKeepRunning( true );
				}

				if( shell.getExitCode() != 0 ) {
					throw( message='Package script returned failing exit code (#shell.getExitCode()#)', detail='Failing script: #arguments.scriptName#', type="commandException", errorCode=shell.getExitCode() );
				}

				// Run postXXX package script
				runScript( 'post#arguments.scriptName#', arguments.directory, true );

			} else if( !arguments.ignoreMissing ) {
				consoleLogger.error( 'The script [#arguments.scriptName#] does not exist in this package.' );
			}
	}

	/**
	* Parses just the slug portion out of an endpoint ID
	* @package The full endpointID like foo@1.0.0
	*/
	private function parseSlug( required string package ) {
		var matches = REFindNoCase( "^([\w\-\.]+(?:\@(?!stable\b)(?!be\b)(?!x\b)[a-zA-Z][\w\-]*)?)(?:\@(.+))?$", package, 1, true );
		if ( arrayLen( matches.len ) < 2 ) {
			throw(
				type = "endpointException",
				message = "Invalid slug detected.  Slugs can only contain letters, numbers, underscores, and hyphens. They may also contain an @ sign for private packages"
			);
		}
		return mid( package, matches.pos[ 2 ], matches.len[ 2 ] );
	}

    /**
	* Parses just the version portion out of an endpoint ID
	* @package The full endpointID like foo@1.0.0
	*/
	private function parseVersion( required string package ) {
		var version = '';
		// foo@1.0.0
		var matches = REFindNoCase( "^([\w\-\.]+(?:\@(?!stable\b)(?!be\b)(?!x\b)[a-zA-Z][\w\-]*)?)(?:\@(.+))?$", package, 1, true );
		if ( matches.pos.len() >= 3 && matches.pos[ 3 ] != 0 ) {
			// Note this can also be a semver range like 1.2.x, >2.0.0, or 1.0.4-2.x
			// For now I'm assuming it's a specific version
			version = mid( package, matches.pos[ 3 ], matches.len[ 3 ] );
		}
		return version;
	}
}
