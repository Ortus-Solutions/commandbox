/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle artifacts, which are basically just a cache of downloaded packages.
* 
* Artifacts are stored in this format:
* <artifactdir>/packageName/version/packageName.zip
*
* We are not currently using a group ID, but we may need to in the future
*
*/
component accessors="true" singleton {
	
	// DI
	property name='artifactDir' 	inject='artifactDir';
	property name='tempDir' 		inject='tempDir';
	property name='packageService' 	inject='PackageService';
	property name='shell' 			inject='Shell';
	property name='logger' 			inject='logbox:logger:{this}';
	
	/**
	* DI complete
	*/
	function onDIComplete() {
		
		// Create the artifacts directory if it doesn't exist
		if( !directoryExists( variables.artifactDir ) ) {
			directoryCreate( variables.artifactDir );
		}
		
	}
	
	/**
	* List the packages in the artifacts cache.
	* @package.hint Supply a package to see only versions of this package
	* @returns A struct of arrays where the struct key is the package package and the array contains the versions of that package in the cache.
	*/
	struct function listArtifacts( packageName='' ) {
		var result = {};
		var dirList = directoryList( path=variables.artifactDir, recurse=false, listInfo='query', sort='name asc' );
		
		for( var dir in dirList ) {
			if( dir.type == 'dir' && ( !arguments.packageName.len() || arguments.packageName == dir.name ) ) {
				var verList = directoryList( path=dir.directory & '\' & dir.name, recurse=false, listInfo='query', sort='name asc' );
				// Ignore package dirs with no actual versions in them
				if( verList.recordCount ) {
					result[ dir.name ] = [];
				}
				for( var ver in verList ) {
					if( ver.type == 'dir' ) {
						result[ dir.name ].append( ver.name );
					}
				}
			}
		}

		return result;
	}
	
	
	/**
	* Removes all artifacts from the cache and returns the number of wiped out directories
	*/ 
	numeric function cleanArtifacts() {
		var dirList = directoryList( path=variables.artifactDir, recurse=false );
		
		for( var dir in dirList ) {
			directoryDelete( dir, true );
		}
		
		return dirList.len();
	}
	
	/**
	* Removes an artifact or an artifact package, true if removed
	*/ 
	boolean function removeArtifact( required packageName ) {
		if( packageExists( arguments.packageName ) ){
			directoryDelete( getPackagePath( arguments.packageName ), true );
			return true;
		}

		return false;
	}

	/**
	* Returns true if a package exists in the artifact cache, false if not.
	* @packageName.hint The package name to look for
	*/ 
	boolean function packageExists( required packageName ){
		return directoryExists( getPackagePath( arguments.packageName ) );				
	}

	/**
	* Returns the filesystem path of the package path
	* @packageName.hint The package name to look for
	*/ 
	function getPackagePath( required packageName ){
		// This will likely change, so I'm only going to put the code here
		// I'm using the package name as the zip file for lack of anything better even though it's redundant with the first folder
		return variables.artifactDir & '/' & arguments.packageName;
	}	
	
	/**
	* Returns true if a package exists in the artifact cache, false if not.
	* @packageName.hint The package name to look for
	* @version.hint The version of the package to look for
	*/ 
	boolean function artifactExists( required packageName, required version ){
		return fileExists( getArtifactPath( argumentCollection = arguments ) );				
	}

	/**
	* Returns the filesystem path of the artifact zip file
	* @packageName.hint The package name to look for
	* @version.hint The version of the package to look for
	*/ 
	function getArtifactPath( required packageName, required version ) {
		// This will likely change, so I'm only going to put the code here
		// I'm using the package name as the zip file for lack of anything better even though it's redundant with the first folder
		return variables.artifactDir & '/' & arguments.packageName & '/' & arguments.version & '/' & arguments.packageName & '.zip';

	}	
	
	/**
	* Store a package in the artifact cache.
	* This expects that the package is already downloaded and stored somewhere on the local filesystem.
	* An error is thrown if the packageZip file doesn't exist or doesn't have a ".zip" extension.
	*
	* @packageName.hint The package name to look for
	* @version.hint The version of the package to look for
	* @packageZip.hint A file path to a local zip file that contains the package
	*/
	ArtifactService function createArtifact( required packageName, required version, required packageZip ) {
		
		// Validate the package path
		if( !fileExists( arguments.packageZip ) ) {
			throw( 'Cannot create artifact [#arguments.packageName#], the file doesn''t exist', arguments.packageZip );
		}
		
		// Validate the package is a zip
		if( right( arguments.packageZip, 4 ) != '.zip' ) {
			throw( 'Cannot create artifact [#arguments.packageName#], the file isn''t a zip', arguments.packageZip );
		}
		
		//  Where will this artifact live?
		var thisArtifactPath = getArtifactPath( arguments.packageName, arguments.version );
		
		// Create dir if it doesn't exist
		directorycreate( getDirectoryFromPath( thisArtifactPath ), true, true );
		
		// Here's your new home
		fileCopy( arguments.packageZip, thisArtifactPath );

		return this;
	}	
	
	/**
	* Returns the descriptor file (box.json) for a packge parsed as a struct.  
	* This data will be merged with a default document to guaruntee existence of standard variables and 
	* reduce the need for "exist" checks in our code 
	* @packageName.hint The package name to look for
	* @version.hint The version of the package to look for
	*/
	public struct function getArtifactDescriptor( required packageName, required version ) {
		var thisArtifactPath = getArtifactPath( arguments.packageName, arguments.version );
		var boxJSONPath = 'zip://' & thisArtifactPath & '!box.json';
		
		// If the packge has a box.json in the root...
		if( fileExists( boxJSONPath ) ) {
			
			// ...Read it.
			boxJSON = fileRead( boxJSONPath );
			
			// Validate the file is valid JSOn
			if( isJSON( boxJSON ) ) {
				// Merge this JSON with defaults
				return packageService.newPackageDescriptor( deserializeJSON( boxJSON ) );
			}
			
		}
		
		// Just return defaults
		return packageService.newPackageDescriptor();			
	
	}	
	
	/**
	* Installs a package, obeying ignors in the box.json file
	* @packageName.hint The package name to look for
	* @version.hint The version of the package to look for
	*/
	public function installArtifact( required packageName, required version, installDirectory ) {
		var thisArtifactPath = getArtifactPath( arguments.packageName, arguments.version );
		var tmpPath 	 = "#variables.tempDir#/#arguments.packageName#";
		// Has file size?
		if( getFileInfo( thisArtifactPath ).size <= 0 ) {
			throw( 'Cannot install file as it has a file size of 0.', thisArtifactPath );
		}
		
		var artifactDescriptor = getArtifactDescriptor( arguments.packageName, arguments.version );
		
		if( !structKeyExists( arguments, 'installDirectory' ) ) {
			arguments.installDirectory = shell.pwd() & '/' & artifactDescriptor.directory;  
		}
		
		// Unzip to temp directory
		zip action="unzip" file="#thisArtifactPath#" destination="#tmpPath#" overwrite="true";

		// Copy with ignores from descriptor
		directoryCopy( tmpPath, arguments.installDirectory, true, function( path ){
			// cleanup path so we just get from the archive down
			var thisPath = replacenocase( arguments.path, tmpPath & "/", "" );
			
			// skip root box.json
			if( thisPath eq "box.json" ){
				return false;
			}
			
			return true;
		});

		// cleanup unzip
		directoryDelete( tmpPath, true );
	}
		
}