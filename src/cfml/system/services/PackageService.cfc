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
	property name="CR" 				inject="CR@constants";
	property name="tempDir" 		inject="tempDir@constants";
	property name="formatterUtil"	inject="formatter";
	property name="artifactService" inject="ArtifactService";
	property name="consoleLogger"	inject="logbox:logger:console";
	// This should be removed once the install command starts resolving registries automatically
	property name="forgeBox" 		inject="ForgeBox";

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
	* Installs a package and its dependencies
	* @slug.ID Identifier of the packge to install. If no ID is passed, all dependencies in the CDW  will be installed.
	* @slug.optionsUDF slugComplete
	* @directory.hint The directory to install in. This will override the packages's box.json install dir if provided. 
	* @save.hint Save the installed package as a dependancy in box.json (if it exists)
	* @saveDev.hint Save the installed package as a dev dependancy in box.json (if it exists)
	* @production.hint When calling this command with no slug to install all dependencies, set this to true to ignore devDependencies.
	* @verbose.hint If set, it will produce much more verbose information about the package installation
	**/
	function installPackage(
			required string ID,
			string directory,
			boolean save=false,
			boolean saveDev=false,
			boolean production=false,
			string currentWorkingDirectory,
			boolean verbose=false
	){
					
		///////////////////////////////////////////////////////////////////////
		// TODO: Instead of assuming this is ForgeBox, look up the appropriate
		//       regsitry to handle the package a deal with a dynamic registry 
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
		
				// If this is a CommandBox command and there is no directory
				if( entryData.typeSlug == 'commandbox-commands' && !structKeyExists( arguments, 'directory' ) ) {
					// Put it in the user directory
					arguments.directory = expandPath( '/root/commands' );
				}
		
				// Advice we found it
				consoleLogger.info( "Verified entry in ForgeBox: '#arguments.ID#'" );
		
				var packageName = arguments.ID;
				var version = entryData.version;
				
				// If the local artifact doesn't exist, download and create it
				if( !artifactService.artifactExists( packageName, version ) ) {
						
					consoleLogger.info( "Starting download from: '#entryData.downloadURL#'..." );
						
					// Grab from the project's download URL and store locally in the temp dir
					var packageTempPath = forgebox.install( entryData.downloadurl, tempDir );
					
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
		
			var installParams = {
				packageName : packageName,
				version : version
			};
		
			// If the user didn't specify this, don't pass it since it overrides the package's desired install location
			if( structKeyExists( arguments, 'directory' ) ) {
				installParams.installDirectory = arguments.directory;
			}
			
			// Install the package
			var results = artifactService.installArtifact( argumentCollection = installParams );
			
			// Summary output
			consoleLogger.info( "Installing to: #results.installDirectory#" );		
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
			// and is the current working directory a package?
			if( ( arguments.save || arguments.saveDev )  
				&& isPackage( arguments.currentWorkingDirectory ) ) {
				// Add it!
				addDependency( currentWorkingDirectory, installParams.packageName, installParams.version,  arguments.saveDev );
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
	* Adds a dependency to a packge
	* @directory.hint The directory that is the root of the package
	* @packageName.hint Package to add a a dependency
	* @version.hint Version of the dependency
	* @dev.hint True if this is a development depenency, false if it is a production dependency
	*/	
	public function addDependency( required string directory, required string packageName, required string version,  boolean dev=false ) {
		// Get box.json, create empty if it doesn't exist
		var boxJSON = readPackageDescriptor( arguments.directory );
		// Get reference to appropriate depenency struct
		var dependencies = ( arguments.dev ? boxJSON.devDependencies : boxJSON.dependencies );
		
		// Add/overwrite this dependency
		dependencies[ arguments.packageName ] = arguments.version;
		
		// Write the box.json back out
		writePackageDescriptor( boxJSON, arguments.directory );
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
			props = addProp( props, '', boxJSON );			
		}
		return props;		
	}
	
	// Recursive function to crawl box.json and create a string that represents each property.
	private function addProp( props, prop, boxJSON ) {
		var propValue = ( len( prop ) ? evaluate( 'boxJSON.#prop#' ) : boxJSON );
		
		if( isStruct( propValue ) ) {
			// Add all of this struct's keys
			for( var thisProp in propValue ) {
				var newProp = listAppend( prop, thisProp, '.' );
				props.append( newProp );
				props = addProp( props, newProp, boxJSON );
			}			
		}
		
		if( isArray( propValue ) ) {
			// Add all of this array's indexes
			var i = 0;
			while( ++i <= propValue.len() ) {
				var newProp = '#prop#[#i#]';
				props.append( newProp );
				props = addProp( props, newProp, boxJSON );
			}
		}
		
		return props;
	}


}