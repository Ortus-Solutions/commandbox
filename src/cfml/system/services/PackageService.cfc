/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle working with the box.json file
*/
component accessors="true" singleton {

	// DI
	property name="CR" 					inject="CR@constants";
	property name="tempDir" 			inject="tempDir@constants";
	property name="formatterUtil"		inject="formatter";
	property name="artifactService" 	inject="ArtifactService";
	property name="consoleLogger"		inject="logbox:logger:console";
	property name="fileSystemUtil"		inject="FileSystem";
	property name="pathPatternMatcher" 	inject="pathPatternMatcher";
	property name='shell' 				inject='Shell';
	// This should be removed once the install command starts resolving registries automatically
	property name="forgeBox" 			inject="ForgeBox";

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
	**/
	function installPackage(
			required string ID,
			string directory,
			boolean save=false,
			boolean saveDev=false,
			boolean production=false,
			string currentWorkingDirectory,
			boolean verbose=false,
			boolean force=false
	){
					
		///////////////////////////////////////////////////////////////////////
		// TODO: Instead of assuming this is ForgeBox, look up the appropriate
		//       regsitry to handle the package a deal with a dynamic adapter 
		//       object at runtime with generic methods
		///////////////////////////////////////////////////////////////////////
		
		// If there is a packge to isntall,isntall it
		if( len( arguments.ID ) ) {
			
			consoleLogger.info( '.');
			consoleLogger.info( 'Installing package: #arguments.ID#');
			
			try {
				// Info
				consoleLogger.warn( "Verifying package '#arguments.ID#' in ForgeBox, please wait..." );
				// We might have gotten this above
				var entryData = forgebox.getEntry( arguments.ID );
				// Verbose info
				if( arguments.verbose ){
					consoleLogger.debug( "Package data retrieved: ", entryData );
				}
				
				// entrylink,createdate,lname,isactive,installinstructions,typename,version,hits,coldboxversion,sourceurl,slug,homeurl,typeslug,
				// downloads,entryid,fname,changelog,updatedate,downloadurl,title,entryrating,summary,username,description,email
								
				if( !val( entryData.isActive ) ) {
					consoleLogger.error( 'The ForgeBox entry [#entryData.title#] is inactive.' );
					return;
				}
				
				if( !len( entryData.downloadurl ) ) {
					consoleLogger.error( 'No download URL provided in ForgeBox.  Manual install only.' );
					return;
				}
		
				var packageType = entryData.typeSlug;
				
				// Advice we found it
				consoleLogger.info( "Verified entry in ForgeBox: '#arguments.ID#'" );
		
				var packageName = arguments.ID;
				var version = entryData.version;
				
				// If the local artifact doesn't exist, download and create it
				if( !artifactService.artifactExists( packageName, version ) ) {
						
					consoleLogger.info( "Starting download of: '#entryData.slug#'..." );
					
					// Store the package locally in the temp dir
					var packageTempPath = forgebox.install( entryData.slug, tempDir );
					
					// Store it locally in the artfact cache
					artifactService.createArtifact( packageName, version, packageTempPath );
					
					// Clean up the temp file
					fileDelete( packageTempPath );
									
					consoleLogger.info( "Done." );
					
				} else {
					consoleLogger.info( "Package found in local artifacts!");
				}
				
				
			} catch( forgebox var e ) {
				// This can include "expected" errors such as "slug not found"
				consoleLogger.error( '#e.message##CR##e.detail#' );
				return;
			}
			
		
			//////////////////////////////////////
			// TODO: End of ForgeBox-specific code
			//////////////////////////////////////
					
			// Assert: at this point, the package is downloaded and exists in the local artifact cache
		
			// Install the package
			var thisArtifactPath = artifactService.getArtifactPath( packageName, version );

			// Has file size?
			if( getFileInfo( thisArtifactPath ).size <= 0 ) {
				throw( 'Cannot install file as it has a file size of 0.', thisArtifactPath );
			}
			
			var artifactDescriptor = artifactService.getArtifactDescriptor( packageName, version );
			var ignorePatterns = ( isArray( artifactDescriptor.ignore ) ? artifactDescriptor.ignore : [] );
			
			// Use Forgebox type returned by API, if not exists, use box.json type if it exists
			if( !len( packageType ) && len( artifactDescriptor.type ) ) {
				packageType = artifactDescriptor.type;
			}
					
			var installDirectory = '';
			
			// If the user gave us a directory, use it above all else
			if( structKeyExists( arguments, 'directory' ) ) {
				installDirectory = arguments.directory;
			}
			
			// Else, use directory in box.json if it exists
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
					installDirectory = expandPath( '/commandbox-home/commands' );
					artifactDescriptor.createPackageDirectory = false;
					arguments.save = false;
					arguments.saveDev = false;
					ignorePatterns.append( '/box.json' );
				// If this is a module
				} else if( packageType == 'modules' ) {
					installDirectory = arguments.currentWorkingDirectory & '/modules';
				// If this is a plugin
				} else if( packageType == 'plugins' ) {
					installDirectory = arguments.currentWorkingDirectory & '/plugins';
					// Plugins just get dumped in
					artifactDescriptor.createPackageDirectory = false;
					// Don't trash the plugins folder with this
					ignorePatterns.append( '/box.json' );
				// If this is an interceptor
				} else if( packageType == 'interceptors' ) {
					installDirectory = arguments.currentWorkingDirectory & '/interceptors';
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

			// Normalize slashes
			var tmpPath = "#variables.tempDir#/#packageName#";
			tmpPath = fileSystemUtil.resolvePath( tmpPath );

			var packageDirectory = packageName;

			// Some packages may just want to be dumped in their destination without being contained in a subfolder
			if( artifactDescriptor.createPackageDirectory ) {
				installDirectory &= '/#packageDirectory#';
			}

			// Check to see if package has already been installed. Skip unless forced.
			if ( directoryExists( installDirectory) && !arguments.force) {
				consoleLogger.warn("The package #packageName# is already installed. Skipping installation. Use --force option to force install.");
				return;
			}

			// Create installation directory if neccesary
			if( !directoryExists( installDirectory ) ) {
				directoryCreate( installDirectory );
			}

			consoleLogger.info( "Uncompressing...");

			// Unzip to temp directory
			// TODO, this should eventaully be part of the zip file adapter
			zip action="unzip" file="#thisArtifactPath#" destination="#tmpPath#" overwrite="true";

			// Override package directory?
			if( len( artifactDescriptor.packageDirectory ) ) {
				packageDirectory = artifactDescriptor.packageDirectory;					
			}
			
			// If the zip file has a directory named after the package, that's our actual package root.
			var innerTmpPath = '#tmpPath#/#packageDirectory#';
			if( directoryExists( innerTmpPath ) ) {
				// Move the box.json if it exists into the inner folder
				fromBoxJSONPath = '#tmpPath#/box.json';
				toBoxJSONPath = '#innerTmpPath#/box.json'; 
				if( fileExists( fromBoxJSONPath ) ) {
					fileMove( fromBoxJSONPath, toBoxJSONPath );
				}
				// Repoint ourselves to the inner folder
				tmpPath = innerTmpPath;
			}

	
			var results = {
				copied = [],
				ignored = []
			};
				
			// Copy with ignores from descriptor
			// TODO, this should eventaully be part of the folder adapter
			directoryCopy( tmpPath, installDirectory, true, function( path ){
				// This will normalize the slashes to match
				arguments.path = fileSystemUtil.resolvePath( arguments.path );
				if( directoryExists( arguments.path ) ) {
					arguments.path &= server.separator.file;
				}
				
				// cleanup path so we just get from the archive down
				var thisPath = replacenocase( arguments.path, tmpPath, "" );
							
				// Ignore paths that match one of our ignore patterns
				var ignored = pathPatternMatcher.matchPatterns( ignorePatterns, thisPath );
				
				// What do we do with this file
				if( ignored ) {
					results.ignored.append( thisPath );
					return false;
				} else {
					results.copied.append( thisPath );
					return true;
				}
							
			});
	
			// cleanup unzip
			directoryDelete( tmpPath, true );
			
			
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
		
			// Should we save this as a dependancy
			// and was the installed package put in a sub dir?
			if( ( arguments.save || arguments.saveDev ) ) {
				// Add it!
				addDependency( currentWorkingDirectory, packageName, version, installDirectory, artifactDescriptor.createPackageDirectory,  arguments.saveDev );
				// Tell the user...
				consoleLogger.info( "box.json updated with #( arguments.saveDev ? 'dev ': '' )#dependency." );
			}
		
			consoleLogger.info( "Eureka, '#arguments.ID#' has been installed!" );
	
			// Get the dependencies of the package we just installed
			var boxJSON = artifactService.getArtifactDescriptor( packageName, version );
	
		// If no package ID was specified, just get the dependencies for the current directory
		} else {
			
			// If there is a box.json...
			if( isPackage( arguments.currentWorkingDirectory ) ) {
				// read it...
				var boxJSON = readPackageDescriptor( arguments.currentWorkingDirectory );
			}
			
		}

		if ( !structKeyExists(variables, "boxJSON") ) {
			consoleLogger.warn("Ouch! We can't find your box.json file. Try running box init to create a new box.json file.");
			return;
		}

		// and grab all the dependencies
		var dependencies = boxJSON.dependencies;
		
		// If we're not in production mode...
		if( !arguments.production ) {
			// Add in the devDependencies
			dependencies.append( boxJSON.devDependencies );
		}

		// Loop over this packages dependencies
		for( var dependency in dependencies ) {
			
			// TODO: Logic here to determine if a satisfying version of this package
			//       is already installed here or at a higher level.  if so, skip it.
			
			params = {
				ID = dependency,
				// Only save the first level
				save = false,
				saveDev = false,
				production = arguments.production,
				// TODO: To allow nested modules, change this to the previous 
				//       install directory so the dependency is nested within
				currentWorkingDirectory = arguments.currentWorkingDirectory
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
			boolean saveDev=false,
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
			var boxJSON = readPackageDescriptor( arguments.currentWorkingDirectory );
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
		if( !directoryExists( uninstallDirectory ) ) {
			consoleLogger.error( 'Package [#uninstallDirectory#] not found.' );
			return;
		}

		// Get the dependencies of the package we're about to uninstalled
		var boxJSON = readPackageDescriptor( uninstallDirectory );

		// and grab all the dependencies
		var dependencies = boxJSON.dependencies;
		
		// Add in the devDependencies
		dependencies.append( boxJSON.devDependencies );

		if( dependencies.count() ) {
			consoleLogger.debug( "Uninstalling dependencies first..." );
		}

		// Loop over this packages dependencies
		for( var dependency in dependencies ) {
			
			params = {
				ID = dependency,
				// Only save the first level
				save = false,
				saveDev = false,
				// TODO: To allow nested modules, change this to the previous 
				//       install directory so the dependency is nested within
				currentWorkingDirectory = arguments.currentWorkingDirectory
			};
						
			// If the user didn't specify this, don't pass it since it overrides the package's desired install location
			if( structKeyExists( arguments, 'directory' ) ) {
				params.directory = arguments.directory;
			}
			
			// Recursivley install them
			uninstallPackage( argumentCollection = params );	
		}
				
		// uninstall the package
		directoryDelete( uninstallDirectory, true );
		
		// Should we save this as a dependancy
		// and is the current working directory a package?
		if( ( arguments.save || arguments.saveDev )  
			&& isPackage( arguments.currentWorkingDirectory ) ) {
			// Add it!
			removeDependency( currentWorkingDirectory, packageName,  arguments.saveDev );
			// Tell the user...
			consoleLogger.info( "#( arguments.saveDev ? 'dev ': '' )#dependency removed from box.json." );
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
		boolean dev=false
		) {
		// Get box.json, create empty if it doesn't exist
		var boxJSON = readPackageDescriptor( arguments.currentWorkingDirectory );
		// Get reference to appropriate depenency struct
		var dependencies = ( arguments.dev ? boxJSON.devDependencies : boxJSON.dependencies );
		
		
		// Add/overwrite this dependency
		dependencies[ arguments.packageName ] = arguments.version;
		
		// Only packages installed in a dedicated directory of their own can be uninstalled
		// so don't save this if they were just dumped somewhere like the packge root amongst
		// other unrelated files and folders.
		if( arguments.installDirectoryIsDedicated ) {
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
	public function removeDependency( required string directory, required string packageName, boolean dev=false ) {
		// Get box.json, create empty if it doesn't exist
		var boxJSON = readPackageDescriptor( arguments.directory );
		// Get reference to appropriate depenency struct
		var dependencies = ( arguments.dev ? boxJSON.devDependencies : boxJSON.dependencies );
		var installPaths = boxJSON.installPaths;
		var saveMe = false;
		
		if( structKeyExists( dependencies, arguments.packageName ) ) {
			saveMe = true;
			structDelete( dependencies, arguments.packageName );
		}
				
		if( structKeyExists( installPaths, arguments.packageName ) ) {
			saveMe = true;
			structDelete( installPaths, arguments.packageName );
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
	* Get the box.json as data from the passed directory location, if not found
	* then we return an empty struct
	* @directory.hint The directory to search for the box.json
	*/
	struct function readPackageDescriptor( required directory ){
		
		// If the packge has a box.json in the root...
		if( isPackage( arguments.directory ) ) {
			
			// ...Read it.
			boxJSON = fileRead( getDescriptorPath( arguments.directory ) );
			
			// Validate the file is valid JSOn
			if( isJSON( boxJSON ) ) {
				// Merge this JSON with defaults
				return newPackageDescriptor( deserializeJSON( boxJSON ) );
			}
			
		}
		
		// Just return defaults
		return newPackageDescriptor();	
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


	// Dynamic completion for property name based on contents of box.json
	function completeProperty( required directory ) {
		var props = [];
		
		// Check and see if box.json exists
		if( isPackage( arguments.directory ) ) {
			boxJSON = readPackageDescriptor( arguments.directory );
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