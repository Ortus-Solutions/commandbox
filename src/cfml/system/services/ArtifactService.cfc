/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
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
	property name='artifactDir' 		inject='artifactDir@constants';
	property name='tempDir' 			inject='tempDir@constants';
	property name='packageService'	 	inject='PackageService';
	property name='logger' 				inject='logbox:logger:{this}';
	property name="semanticVersion"		inject="provider:semanticVersion@semver";
	property name="configService"		inject="ConfigService";

	/**
	* THIS CANNOT BE RUN ON DI COMPLETE due to a circular dependency with the ConfigSerivice
	*/
	function ensureArtifactsDirectory() {

		// Create the artifacts directory if it doesn't exist
		if( !directoryExists( getArtifactsDirectory() ) ) {
			directoryCreate( getArtifactsDirectory(), true, true );
		}

	}

	/**
	* List the packages in the artifacts cache.
	* @packageName Supply a package to see only versions of this package
	* @returns A struct of arrays where the struct key is the package and the array contains the versions of that package in the cache.
	*/
	struct function listArtifacts( packageName='' ) {
		ensureArtifactsDirectory();
		// Ordered struct
		var result = [:];

		var dirList = directoryList( path=getArtifactsDirectory(), recurse=false, listInfo='query', sort='name asc' );

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
	* Removes all artifacts from the cache and returns the array of removed artifacts
	*/
	array function cleanArtifacts( numeric daysOld=-1 ) {
		ensureArtifactsDirectory();

		var artifacts = listArtifacts().reduce( (artifacts,package,versions)=>{
			versions.each( (version)=>artifacts.append( { 'package' : package, 'version' : version } ) );
			return artifacts;
		}, [] )
		// Get artifact path for each file
		.map( (artifact)=>{
			artifact[ 'artifactPath' ] = getArtifactPath( artifact.package, artifact.version, false );
			return artifact;
		} )
		// Ensure files exist
		.filter( (artifact)=>fileExists( artifact.artifactPath ) )
		// get last modifed date for each file
		.map( (artifact)=>{
			artifact[ 'lastmodified' ] = ( daysOld == -1 ? '' : dateFormat( getFileInfo( artifact.artifactPath ).lastmodified, 'mm/dd/yyyy' ) );
			return artifact;
		} )
		// Filter matching files
		.filter( (artifact)=>daysOld == -1 || artifact.lastmodified <= dateAdd( 'd', -daysOld, now() ) );

		artifacts.each( (artifact)=>{
			removeArtifact( artifact.package, artifact.version );
		} );

		return artifacts;
	}

	/**
	* Removes an artifact or an artifact package, true if removed
	* @packageName The package name to look for
	* @version The version to look for
	*/
	boolean function removeArtifact( required packageName, version="" ) {
		ensureArtifactsDirectory();
		if( packageExists( arguments.packageName, arguments.version ) ){
			directoryDelete( getPackagePath( arguments.packageName, arguments.version ), true );
			// If there are no more verions, remove the package folder as well
			if( listArtifacts( packageName ).isEmpty() ) {
				var path = getArtifactsDirectory() & arguments.packageName;
				if( directoryExists( path ) ) {
					directoryDelete( path, true );
				}
			}
			return true;
		}

		return false;
	}

	/**
	* Returns true if a package exists in the artifact cache, false if not.
	* @packageName The package name to look for
	* @version The version to look for
	*/
	boolean function packageExists( required packageName, version="" ){
		ensureArtifactsDirectory();
		return directoryExists( getPackagePath( arguments.packageName, arguments.version ) );
	}

	/**
	* Returns the filesystem path of the package path
	* @packageName The package name to look for
	* @version The version to look for
	*/
	function getPackagePath( required packageName, version="" ){
		ensureArtifactsDirectory();
		// This will likely change, so I'm only going to put the code here.

		var path = getArtifactsDirectory() & arguments.packageName;
		// do we have a version?
		if( arguments.version.len() ){
			path &= "/" & arguments.version;
		}
		return path;
	}

	/**
	* Returns true if a package exists in the artifact cache, false if not.
	* @packageName The package name to look for
	* @version The version of the package to look for
	*/
	boolean function artifactExists( required packageName, required version ){
		ensureArtifactsDirectory();
		arguments.touch = false;
		return fileExists( getArtifactPath( argumentCollection = arguments ) );
	}

	/**
	* Returns the filesystem path of the artifact zip file
	* @packageName The package name to look for
	* @version The version of the package to look for
	*/
	function getArtifactPath( required packageName, required version, boolean touch=true ) {
		ensureArtifactsDirectory();
		var theFile = getPackagePath( arguments.packageName, arguments.version ) & '/' & arguments.packageName & '.zip';
		// This allows us to keep tabs on when artifacts are used
		if( touch ) {
			var oFile = createObject( "java", "java.io.File" ).init( theFile );
			if( oFile.exists() ){
				oFile.setLastModified( now().getTime() );
			}
		}
		// I'm using the package name as the zip file for lack of anything better even though it's redundant with the first folder
		return theFile;

	}

	/**
	* Store a package in the artifact cache.
	* This expects that the package is already downloaded and stored somewhere on the local filesystem.
	* An error is thrown if the packageZip file doesn't exist or doesn't have a ".zip" extension.
	*
	* @packageName The package name to look for
	* @version The version of the package to look for
	* @packagePath A file path to a local zip file that contains the package
	*/
	ArtifactService function createArtifact( required packageName, required version, required packagePath ) {
		ensureArtifactsDirectory();

		// If we were given a folder, defer to another method
		if( directoryExists( arguments.packagePath ) ) {
			return createArtifactFromFolder( arguments.packageName, arguments.version, arguments.packagePath );
		}

		// Validate the package path
		if( !fileExists( arguments.packagePath ) ) {
			throw( 'Cannot create artifact [#arguments.packageName#], the file doesn''t exist', arguments.packagePath );
		}

		// Validate the package is a zip
		if( right( arguments.packagePath, 4 ) != '.zip' ) {
			throw( 'Cannot create artifact [#arguments.packageName#], the file isn''t a zip', arguments.packagePath );
		}

		//  Where will this artifact live?
		var thisArtifactPath = getArtifactPath( arguments.packageName, arguments.version );

		// Create dir if it doesn't exist
		directorycreate( getDirectoryFromPath( thisArtifactPath ), true, true );

		// Here's your new home
		fileCopy( arguments.packagePath, thisArtifactPath );

		return this;
	}

	/**
	* Store a package in the artifact cache.
	* This expects that the package is already downloaded and stored somewhere on the local filesystem.
	*
	* @packageName The package name to look for
	* @version The version of the package to look for
	* @packageFolder A file path to a local folder that contains the package
	*/
	function createArtifactFromFolder( required packageName, required version, required packageFolder ) {
		ensureArtifactsDirectory();

		//  Where will this artifact live?
		var thisArtifactPath = getArtifactPath( arguments.packageName, arguments.version );

		// Create dir if it doesn't exist
		directorycreate( getDirectoryFromPath( thisArtifactPath ), true, true );

		zip action='zip' source=arguments.packageFolder file=thisArtifactPath;

		return this;
	}

	/**
	* Returns the descriptor file (box.json) for a package parsed as a struct.
	* This data will be merged with a default document to guarantee existence of standard variables and
	* reduce the need for "exist" checks in our code
	* @packageName The package name to look for
	* @version The version of the package to look for
	*/
	public struct function getArtifactDescriptor( required packageName, required version ) {
		ensureArtifactsDirectory();
		var thisArtifactPath = getArtifactPath( arguments.packageName, arguments.version );
		var boxJSONPath = 'zip://' & thisArtifactPath & '!box.json';

		// If the package has a box.json in the root...
		if( fileExists( boxJSONPath ) ) {

			// ...Read it.
			var boxJSON = fileRead( boxJSONPath );

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
	* Figures out the closest satisfying version that's available for a package in the local artifacts cache.
	* @slug Slug of package
	* @version Version range to satisfy
	*/
	function findSatisfyingVersion( required string slug, required string version ) {
		ensureArtifactsDirectory();
		var artifacts = listArtifacts( slug );

		// Check to see if we even have any versions for this artifact
		if( !artifacts.keyExists( slug ) ) {
			return '';
		}

		// Get the locally-stored versions
		var arrVersions = artifacts[ slug ];
		// Sort them
		arrVersions.sort( function( a, b ) { return semanticVersion.compare( b, a ) } );

		var found = false;
		for( var thisVersion in arrVersions ) {
			if( semanticVersion.satisfies( thisVersion, arguments.version ) ) {
				return thisVersion;
			}
		}

		// If we requested stable and all releases are pre-release, just grab the latest
		if( arguments.version == 'stable' && arrayLen( arrVersions ) ) {
			return arrVersions[ 1 ];
		} else {
			return '';
		}
	}

	string function getArtifactsDirectory() {
		var path = configService.getSetting( 'artifactsDirectory', variables.artifactDir );
		if( !path.endsWith( '/' ) || !path.endsWith( '\' ) ) {
			path &= '/';
		}
		return path;
	}
}
