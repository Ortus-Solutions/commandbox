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
	property name="CR" 					inject="CR@constants";
	property name="formatterUtil"		inject="formatter";
	property name="artifactService" 	inject="ArtifactService";
	property name="fileSystemUtil"		inject="FileSystem";
	property name="pathPatternMatcher" 	inject="pathPatternMatcher";
	property name='shell' 				inject='Shell';
	property name="logger"				inject="logbox:logger:{this}";
	property name="semanticVersion"		inject="semanticVersion";
	property name="endpointService"		inject="EndpointService";
	property name="consoleLogger"		inject="logbox:logger:console";
	
	/**
	* Constructor
	*/
	function init(){
		return this;
	}
	
	/**
	* Checks to see if a box.json exists in a given directory
	* @directory.hint The directory to examine
	*/	
	public function isPackage( required string directory ) {
		// If the packge has a box.json in the root...
		return fileExists( getDescriptorPath( arguments.directory ) );
	}
	
	/**
	* Returns the path to the package descriptor
	* @directory.hint The directory that is the root of the package
	*/	
	public function getDescriptorPath( required string directory ) {
		return directory & '/box.json';
	}
		
	/**
	* Installs a package and its dependencies,  obeying ignors in the box.json file.  Returns a struct containing a "copied" array
	* and an "ignored" array containing the relative paths inside the package that were copied and ignored.
	* 
	* @slug.ID Identifier of the packge to install. If no ID is passed, all dependencies in the CDW  will be installed.
	* @slug.optionsUDF slugComplete
	* @directory.hint The directory to install in. This will override the packages's box.json install dir if provided. 
	* @save.hint Save the installed package as a dependancy in box.json (if it exists)
	* @saveDev.hint Save the installed package as a dev dependancy in box.json (if it exists)
	* @production.hint When calling this command with no slug to install all dependencies, set this to true to ignore devDependencies.
	* @currentWorkingDirectory.hint Root of the application (used for finding box.json)
	* @verbose.hint If set, it will produce much more verbose information about the package installation
	* @force.hint When set to true, it will force dependencies to be installed whether they already exist or not
	* @packagePathRequestingInstallation.hint If installing smart dependencies packages (like ColdBox modules) that are capable of being nested, this is our current level
	**/
	function installPackage(
			required string ID,
			string directory,
			boolean save=false,
			boolean saveDev=false,
			boolean production=false,
			string currentWorkingDirectory,
			boolean verbose=false,
			boolean force=false,
			string packagePathRequestingInstallation = arguments.currentWorkingDirectory
	){
		
		// If there is a package to install, install it
		if( len( arguments.ID ) ) {
			
			// Verbose info
			if( arguments.verbose ){
				consoleLogger.debug( "Save:#arguments.save# SaveDev:#arguments.saveDev# Production:#arguments.production# Directory:#arguments.directory#" );
			}
			
			try {
				var endpointData = endpointService.resolveEndpoint( arguments.ID, arguments.currentWorkingDirectory );
			} catch( EndpointNotFound var e ) {
				consoleLogger.error( e.message );
				return;				
			}
			
			consoleLogger.info( '.');
			consoleLogger.info( 'Installing package [#endpointData.ID#]' );
			
			try {
				var tmpPath = endpointData.endpoint.resolvePackage( endpointData.package, arguments.verbose );	
				
			// endpointException exception type is used when the endpoint has an issue that needs displayed, 
			// but I don't want to "blow up" the console with a full error.	
			} catch( endpointException var e ) {
				consoleLogger.error( e.message & ' ' & e.detail );
				return;				
			}
			
			// Support box.json in the root OR in a subfolder (NPM-style!)
			tmpPath = findPackageRoot( tmpPath );
			
			// The code below expects these variables
			if( isPackage( tmpPath ) ) {
				var boxJSON = readPackageDescriptor( tmpPath );
				var packageType = boxJSON.type;
				var packageName = boxJSON.slug;
				var version = boxJSON.version;
			} else {
				consoleLogger.error( "box.json is missing so this isn't really a package! I'll install it anyway, but I'm not happy about it" );
				consoleLogger.warn( "I'm just guessing what the package name, version and type are.  Please ask the package owner to add a box.json." );
				var packageType = 'project';
				var packageName = endpointData.endpoint.getDefaultName( endpointData.package );
				var version = '1.0.0';
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
			
			// Now that we have resolved the directory where our packge lives, read the box.json out of it.
			var artifactDescriptor = readPackageDescriptor( tmpPath );
			var ignorePatterns = ( isArray( artifactDescriptor.ignore ) ? artifactDescriptor.ignore : [] );
			
			
			// Assert: At this point we know what we're installing and we've acquired it, but we don't know where it will install to yet.
									
			// Determine if a satisfying version of this package is already installed here or at a higher level.  if so, skip it.
			// Modules are the only kind of packages that can be nested in a hierarchy, so the check only applies here. 
			// We're also going to assume that they are in a "modules" folder.
			// This check also only applies if we're at least one level deep into modules.
			if( packageType == 'modules' && currentWorkingDirectory != packagePathRequestingInstallation) {
				
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
							if( semanticVersion.satisfies( candidateBoxJSON.version, version ) ) {
								consoleLogger.warn( '#packageName# (#version#) is already satisifed by #candidateInstallPath# (#candidateBoxJSON.version#).  Skipping installation.' );
								return;
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
			}
			
			// Next, see if the containing project has an install path configured for this dependency already.
			var containerBoxJSON = readPackageDescriptor( arguments.packagePathRequestingInstallation );
			if( !len( installDirectory ) && structKeyExists( containerBoxJSON.installPaths, packageName ) ) {
				// Get the resolved intallation path for this package
				installDirectory = fileSystemUtil.resolvePath( containerBoxJSON.installPaths[ packageName ], arguments.packagePathRequestingInstallation );
				// Back up to the "container" folder.  The packge directory will be added back below
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
					consoleLogger.warn( "Shell will be reloaded after installation." );
					shell.reload( false );
				// If this is a module
				} else if( packageType == 'modules' ) {
					installDirectory = arguments.packagePathRequestingInstallation & '/modules';
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
				}
			}
						
			// I give up, just stick it in the CWD
			if( !len( installDirectory ) ) {
				installDirectory = arguments.currentWorkingDirectory;
			}
			
			// Default directory to package name
			var packageDirectory = packageName;
			// Override package directory in descriptor?
			if( len( artifactDescriptor.packageDirectory ) ) {
				packageDirectory = artifactDescriptor.packageDirectory;
			}
			
			// Some packages may just want to be dumped in their destination without being contained in a subfolder
			if( artifactDescriptor.createPackageDirectory ) {
				installDirectory &= '/#packageDirectory#';
			// If we're dumping in the root and the install dir is already a package then ignore box.json or it will overwrite the existing one
			// If the directory wasn't already a package, still save so our box.json gets install paths added
			} else if( isPackage( installDirectory ) ) {
				ignorePatterns.append( '/box.json' );
			}			
			
			// Assert: At this point, all paths are finalized and we are ready to install.
						
			// Should we save this as a dependency. Save the install even though the package may already be there
			if( ( arguments.save || arguments.saveDev ) ) {
				// Add it!
				addDependency( packagePathRequestingInstallation, packageName, version, installDirectory, artifactDescriptor.createPackageDirectory,  arguments.saveDev, endpointData );
				// Tell the user...
				consoleLogger.info( "#packagePathRequestingInstallation#/box.json updated with #( arguments.saveDev ? 'dev ': '' )#dependency." );
			}			
						
			// Check to see if package has already been installed. Skip unless forced.
			// This check can only be performed for packages that get installed in their own directory.
			if ( artifactDescriptor.createPackageDirectory && directoryExists( installDirectory ) && !arguments.force ){
				// cleanup tmp
				if( endpointData.endpointName != 'folder' ) {
					directoryDelete( tmpPath, true );					
				}
				consoleLogger.warn("The package #packageName# is already installed at #installDirectory#. Skipping installation. Use --force option to force install.");
				return;
			}
						
			// Create installation directory if neccesary
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
				var ignored = pathPatternMatcher.matchPatterns( ignorePatterns, thisPath );
				// What do we do with this file/directory
				if( ignored ) {
					results.ignored.append( thisPath );
					return false;
				} else {
					results.copied.append( thisPath );
					return true;
				}
			});
				
			// Catch this to gracefully handle where the OS or another program 
			// has the folder locked.
			try {
				// cleanup unzip
				if( endpointData.endpointName != 'folder' ) {
					directoryDelete( tmpPath, true );					
				}				
			} catch( any e ) {
				consoleLogger.error( '#e.message##CR#The folder is possibly locked by another program.' );
				logger.error( '#e.message# #e.detail#' , e.stackTrace );
			}
	
			
			// Summary output
			consoleLogger.info( "Installing to: #installDirectory#" );		
			consoleLogger.debug( "-> #results.copied.len()# File(s) Installed" );
			
			// Verbose info
			if( arguments.verbose ){
				for( var file in results.copied ) {
					consoleLogger.debug( ".    #file#" );				
				}		
			}	
			
			// Ignored Summary
			consoleLogger.debug( "-> #results.ignored.len()# File(s) ignored" );
			if( arguments.verbose ){
				for( var file in results.ignored ) {
					consoleLogger.debug( ".    #file#" );					
				}
			}
				
			consoleLogger.info( "Eureka, '#arguments.ID#' has been installed!" );
									
		// If no package ID was specified, just get the dependencies for the current directory
		} else {
			// read it...
			var artifactDescriptor = readPackageDescriptor( arguments.currentWorkingDirectory );
			var installDirectory = arguments.currentWorkingDirectory;
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
				production = arguments.production,
				currentWorkingDirectory = arguments.currentWorkingDirectory, // Original dir
				packagePathRequestingInstallation = installDirectory // directory for smart dependencies to use
			};
						
			// If the user didn't specify this, don't pass it since it overrides the package's desired install location
			if( structKeyExists( arguments, 'directory' ) ) {
				params.directory = arguments.directory;
			}
			
			// Recursivley install them
			installPackage( argumentCollection = params );	
		}
			
		if( !len( arguments.ID ) && dependencies.isEmpty() ) {
			consoleLogger.info( "No dependencies found to install, but it's the thought that counts, right?" );
		}

	}
	
	
	/******************************************************************************************************************/
	// If the root of the current package doesn't have a box.json, check if there is a subdirectory that contains
	// a box.json.  This would be the NPM-style standard where a zip contains a package in a sub folder.
	/******************************************************************************************************************/
	function findPackageRoot( packagePath ) {
		var JSONPath = '#packagePath#/box.json';
		if( !fileExists( JSONPath ) ) {
			// Check for a packge in a sub folder
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
	* @slug.ID Identifier of the packge to uninstall.
	* @slug.optionsUDF slugComplete
	* @directory.hint The directory to install in. This will override the packages's box.json install dir if provided. 
	* @save.hint Remove package as a dependancy in box.json (if it exists)
	* @saveDev.hint Remove package as a dev dependancy in box.json (if it exists)
	* @currentWorkingDirectory.hint Root of the application (used for finding box.json)
	**/
	function uninstallPackage(
			required string ID,
			string directory,
			boolean save=false,
			required string currentWorkingDirectory
	){
					
		
		consoleLogger.info( '.');
		consoleLogger.info( 'Uninstalling package: #arguments.ID#');
		
		var packageName = arguments.ID;
			
		var uninstallDirectory = '';
	
		// If a directory is passed in, use it
		if( structKeyExists( arguments, 'directory' ) ) {
			var uninstallDirectory = arguments.directory
		// Otherwise, are we a package
		} else if( isPackage( arguments.currentWorkingDirectory ) ) {
			// Read the box.json
			var boxjson = readPackageDescriptor( arguments.currentWorkingDirectory );
			var installPaths = boxJSON.installPaths;
			
			// Is there an install path for this?
			if( structKeyExists( installPaths, packageName ) ) {
				uninstallDirectory = fileSystemUtil.resolvePath( installPaths[ packageName ] );
			}			
		}
		
		// If all else fails, just use the current directory
		if( !len( uninstallDirectory ) ) {
			consoleLogger.warn( "No install path found in box.json, looking in the current working directory.");
			uninstallDirectory = arguments.currentWorkingDirectory & '/' & packageName;
		}
				
		// See if the package exists here
		if( directoryExists( uninstallDirectory ) ) {
			
			// Get the dependencies of the package we're about to uninstalled
			var boxJSON = readPackageDescriptor( uninstallDirectory );
			// and grab all the dependencies
			var dependencies = boxJSON.dependencies;
			var type = boxJSON.type;
			// Add in the devDependencies
			dependencies.append( boxJSON.devDependencies );
			
		} else {
			// If the package isn't on disk, no dependencies
			var dependencies = {};
			var type = '';
		}

		// ColdBox modules are stored in a hierachy so just removing the top one removes then all
		// For all other packages, the depenencies are probably just in the root
		if( type != 'modules' ) {
	
			if( dependencies.count() ) {
				consoleLogger.debug( "Uninstalling dependencies first..." );
			}
	
			// Loop over this packages dependencies
			for( var dependency in dependencies ) {
				
				var params = {
					ID = dependency,
					// Only save the first level
					save = false,
					currentWorkingDirectory = arguments.currentWorkingDirectory
				};
							
				// If the user didn't specify this, don't pass it since it overrides the package's desired install location
				if( structKeyExists( arguments, 'directory' ) ) {
					params.directory = arguments.directory;
				}
				
				// Recursivley install them
				uninstallPackage( argumentCollection = params );	
			}
		
		} // end is not module
				
		// uninstall the package
		if( directoryExists( uninstallDirectory ) ) {
			
			// Catch this to gracefully handle where the OS or another program 
			// has the folder locked.
			try {
				directoryDelete( uninstallDirectory, true );				
			} catch( any e ) {
				consoleLogger.error( '#e.message##CR#The folder is possibly locked by another program.' );
				logger.error( '#e.message# #e.detail#' , e.stackTrace );
			}
			
		} else {
			consoleLogger.error( 'Package [#uninstallDirectory#] not found.' );			
		}

		
		// Should we save this as a dependancy
		// and is the current working directory a package?
		if( arguments.save && isPackage( arguments.currentWorkingDirectory ) ) {
			// Add it!
			removeDependency( currentWorkingDirectory, packageName );
			// Tell the user...
			consoleLogger.info( "Dependency removed from box.json." );
		}
	
		consoleLogger.info( "'#arguments.ID#' has been uninstalled" );

	}
	
	/**
	* Adds a dependency to a packge
	* @currentWorkingDirectory.hint The directory that is the root of the package
	* @packageName.hint Package to add a a dependency
	* @version.hint Version of the dependency
	* @installDirectory.hint The location that the package is installed to including the container folder.
	* @installDirectoryIsDedicated.hint True if the package was placed in a dedicated folder
	* @dev.hint True if this is a development depenency, false if it is a production dependency
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
		var boxJSON = readPackageDescriptorRaw( arguments.currentWorkingDirectory );
		
		// Get reference to appropriate dependency struct
		if( arguments.dev ) {
			param name='boxJSON.devDependencies' default='#{}#';
			var dependencies = boxJSON.devDependencies;
		} else {
			param name='boxJSON.dependencies' default='#{}#';
			var dependencies = boxJSON.dependencies;			
		}
		
		// Add/overwrite this dependency
		if( endpointData.endpointName == 'forgebox' ) {
			dependencies[ arguments.packageName ] = arguments.version;	
		} else {
			dependencies[ arguments.packageName ] = endpointData.ID;
		}
		
		// Only packages installed in a dedicated directory of their own can be uninstalled
		// so don't save this if they were just dumped somewhere like the package root amongst
		// other unrelated files and folders.
		if( arguments.installDirectoryIsDedicated ) {
			param name='boxJSON.installPaths' default='#{}#';
			var installPaths = boxJSON.installPaths;
					
			// normalize slashes
			arguments.currentWorkingDirectory = fileSystemUtil.resolvePath( arguments.currentWorkingDirectory );
			arguments.installDirectory = fileSystemUtil.resolvePath( arguments.installDirectory );
			
			// If the install location is contained within the package root...
			if( arguments.installDirectory contains arguments.currentWorkingDirectory ) {
				// Make it relative
				arguments.installDirectory = replaceNoCase( arguments.installDirectory, arguments.currentWorkingDirectory, '' );
				// Strip any leading slashes so Unix-based OS's don't think it's the drive root
				if( len( arguments.installDirectory ) && listFind( '\,/', left( arguments.installDirectory, 1 ) ) ) {
					arguments.installDirectory = right( arguments.installDirectory, len( arguments.installDirectory ) - 1 );
				}
			}
					
			// Just in case-- an empty install dir would be useless.
			if( len( arguments.installDirectory ) ) {
				installPaths[ arguments.packageName ] = arguments.installDirectory;			
			}
			
		} // end installDirectoryIsDedicated
					
		// Write the box.json back out
		writePackageDescriptor( boxJSON, arguments.currentWorkingDirectory );
	}
	
	/**
	* Removes a dependency from a packge if it exists
	* @directory.hint The directory that is the root of the package
	* @packageName.hint Package to add a a dependency
	* @dev.hint True if this is a development depenency, false if it is a production dependency
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
	* Gets a TestBox runner URL from box.json with an optional slug to look up.  If no slug is passed, the first runner will be used
	* @directory.hint The directory that is the root of the package
	* @slug.hint An optional runner slug to look for in the list of runners
	*/	
	public function getTestBoxRunner( required string directory, string slug='' ) {
		// Get box.json, create empty if it doesn't exist
		var boxJSON = readPackageDescriptor( arguments.directory );
		// Get reference to appropriate depenency struct
		var runners = boxJSON.testbox.runner;
		var runnerURL = '';

		// If there is a slug and runners is an array, look it up
		if ( len( arguments.slug ) && isArray( runners ) ){
			
			for( var thisRunner in runners ){
				// Does the string passed in match the slug of this runner?
				if( structKeyExists( thisRunner, arguments.runner ) ) {
					runnerURL = thisRunner[ arguments.runner ];
					break;						
				}
			}
			
			return runnerURL;
			
		}

		// Just get the first one we can find
		 
		// simple runner?
		if( isSimpleValue( runners ) ){
			return runners;
		}
		
		// Array of runners?
		if( isArray( runners ) ) {
			// get the first definition in the list to use
			var firstRunner = runners[ 1 ];
			return firstRunner[ listFirst( structKeyList( firstRunner ) ) ];
		}
		
		// We failed to find anything
		return '';
		
	}
	
	/**
	* Get the default package description, AKA box.json
	* @defaults.hint A struct of default values to be merged into the empty, default document
	*/	
	public function newPackageDescriptor( struct defaults={} ) {
		
		// TODO: Get author info from default CommandBox config
		
		// Read the default JSON file and deserialize it.  
		var boxJSON = DeserializeJSON( fileRead( '/commandBox/templates/box.json.txt' ) );
		
		// Replace things passed via parameters
		boxJSON = boxJSON.append( arguments.defaults );
		
		return boxJSON; 
		
	}

	/**
	* Get the box.json as data from the passed directory location.
	* Any missing properties will be defaulted with our box.json template.
	* If you plan on writing the box.json back out to disk, use readPackageDescriptorRaw() instead.
	* @directory.hint The directory to search for the box.json
	*/
	struct function readPackageDescriptor( required directory ){
		// Merge this JSON with defaults
		return newPackageDescriptor( readPackageDescriptorRaw( arguments.directory ) );
	}

	/**
	* Get the box.json as data from the passed directory location, if not found
	* then we return an empty struct.  This method will NOT default box.json properties
	* and will return JUST what was defined.  Make sure you use existence checks when 
	* using the returned data structure
	* @directory.hint The directory to search for the box.json
	*/
	struct function readPackageDescriptorRaw( required directory ){
		
		// If the packge has a box.json in the root...
		if( isPackage( arguments.directory ) ) {
			
			// ...Read it.
			boxJSON = fileRead( getDescriptorPath( arguments.directory ) );
			
			// Validate the file is valid JSOn
			if( isJSON( boxJSON ) ) {
				// Merge this JSON with defaults
				return deserializeJSON( boxJSON );
			}
			
		}
		
		// Just return defaults
		return {};	
	}

	/**
	* Write the box.json data as a JSON file
	* @JSONData.hint The JSON data to write to the file. Can be a struct, or the string JSON
	* @directory.hint The directory to write the box.json
	*/
	function writePackageDescriptor( required any JSONData, required directory ){
		
		if( !isSimpleValue( JSONData ) ) {
			JSONData = serializeJSON( JSONData );
		}

		fileWrite( getDescriptorPath( arguments.directory ), formatterUtil.formatJSON( JSONData ) );	
	}

	/**
	* Return an array of all outdated depdendencies in a project.
	* @directory.hint The directory of the package to start in
	* @print.hint The print buffer used for command operation
	* @verbose.hint Outputs additional information about each package as it is checked
	* @includeSlugs.hint A commit-delimited list of slugs to include.  Empty means include everything.
	* 
	* @return An array of structs of outdated dependencies
	*/
	array function getOutdatedDependencies( required directory, required print, boolean verbose=false, includeSlugs='' ){
		// build dependency tree
		var tree = buildDependencyHierarchy( arguments.directory );
		var fakeDir = arguments.directory & '/fake';
		var verbose = arguments.verbose;

		// Global outdated check bit
		var aOutdatedDependencies = [];
		// Outdated check closure
		var fOutdatedCheck 	= function( slug, value ){
			
			// Only check slugs we're supposed to
			if( !len( includeSlugs ) || listFindNoCase( includeSlugs, arguments.slug ) ) {
				
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
								
				if( updateData.isOutdated ){
					aOutdatedDependencies.append({ 
						slug 				: arguments.slug,
						version 			: value.version,
						packageVersion		: value.packageVersion,
						newVersion 			: updateData.version,
						shortDescription 	: value.shortDescription,
						name 				: value.name,
						dev 				: value.dev
					});
				}
				// verbose output
				if( verbose ){
					print.yellowLine( "* #arguments.slug# (#value.packageVersion#) -> #endpointData.endpointName# version: (#updateData.version#)" )
						.boldRedLine( updateData.isOutdated ? " ** #arguments.slug# is Outdated" : "" )
						.toConsole();
				}
				
			}
			
			// Do we have more dependencies, go down the tree in parallel
			if( structCount( value.dependencies ) ){
				structEach( value.dependencies, fOutdatedCheck );
			}
		};

		// Verify outdated dependency graph in parallel
		structEach( tree.dependencies, fOutdatedCheck );

		return aOutdatedDependencies;
	}

	/**
	* Builds a struct of structs that represents the dependency hierarchy
	* @directory.hint The directory of the package to start in
	*/
	function buildDependencyHierarchy( required directory ){

		var boxJSON = readPackageDescriptor( arguments.directory );
		var tree = {
			'name' : boxJSON.name,
			'slug' : boxJSON.slug,
			'shortDescription' : boxJSON.shortDescription,
			'version': boxJSON.version,
			'packageVersion': boxJSON.version
		};
		buildChildren( boxJSON, tree, arguments.directory);
		return tree;
	}

	private function buildChildren( required struct boxJSON, required struct parent, required string basePath ) {
		parent[ 'dependencies' ] = processDependencies( boxJSON.dependencies, boxJSON.installPaths, false, arguments.basePath );
		parent[ 'dependencies' ].append( processDependencies( boxJSON.devDependencies, boxJSON.installPaths, true, arguments.basePath ) );
	}
	
	private function processDependencies( dependencies, installPaths, dev=false, basePath ) {
		var thisDeps = {};
		
		for( var dependency in arguments.dependencies ) {
			thisDeps[ dependency ] = {
				'version' : arguments.dependencies[ dependency ],
				'dev' : arguments.dev,
				'name' : '',
				'shortDescription' : '',
				'packageVersion' : ''
			};
			   
			if( structKeyExists( arguments.installPaths, dependency ) ) {
				
				var fullPackageInstallPath = fileSystemUtil.resolvePath( arguments.installPaths[ dependency ], arguments.basePath );
				var boxJSON = readPackageDescriptor( fullPackageInstallPath );
				thisDeps[ dependency ][ 'name'  ] = boxJSON.name;
				thisDeps[ dependency ][ 'shortDescription'  ] = boxJSON.shortDescription;
				thisDeps[ dependency ][ 'packageVersion'  ] = boxJSON.version;
				
				// Down the rabbit hole
				buildChildren( boxJSON, thisDeps[ dependency ], fullPackageInstallPath );				
			} else {
				// If we don't have an install path for this package, we don't know about its dependencies
				thisDeps[ dependency ][ 'dependencies' ] = {};
			}
		}
		
		return thisDeps;
	}
	
	/**
	* Dynamic completion for property name based on contents of box.json
	* @directory.hint The package root
	* @all.hint Pass false to ONLY suggest existing property names.  True will suggest all possible box.json properties.
	*/ 	
	function completeProperty( required directory, all=false ) {
		var props = [];
		
		// Check and see if box.json exists
		if( isPackage( arguments.directory ) ) {
			if( arguments.all ) {
				var boxJSON = readPackageDescriptor( arguments.directory );
			} else {
				var boxJSON = readPackageDescriptorRaw( arguments.directory );
			}
			props = addProp( props, '', '', boxJSON );			
		}
		return props;		
	}
	
	// Recursive function to crawl box.json and create a string that represents each property.
	private function addProp( props, prop, safeProp, boxJSON ) {
		var propValue = ( len( prop ) ? evaluate( 'boxJSON#safeProp#' ) : boxJSON );
		
		if( isStruct( propValue ) ) {
			// Add all of this struct's keys
			for( var thisProp in propValue ) {
				var newProp = listAppend( prop, thisProp, '.' );
				var newSafeProp = "#safeProp#['#thisProp#']";
				props.append( newProp );
				props = addProp( props, newProp, newSafeProp, boxJSON );
			}			
		}
		
		if( isArray( propValue ) ) {
			// Add all of this array's indexes
			var i = 0;
			while( ++i <= propValue.len() ) {
				var newProp = '#prop#[#i#]';
				var newProp = '#safeProp#[#i#]';
				var newSafeProp = newProp;
				props.append( newProp );
				props = addProp( props, newProp, newSafeProp, boxJSON );
			}
		}
		
		return props;
	}

}