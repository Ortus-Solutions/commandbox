/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I contain helpful methods for dealing with file and directory paths
*
*/
component accessors="true" singleton {

	/**
	* The os
	*/
	property name="os";

	// DI
	property name="shell" inject="shell";
	property name="logger" inject="logbox:logger:{this}";

	function init() {
		variables.os = createObject( "java", "java.lang.System" ).getProperty( "os.name" ).toLowerCase();
		variables.userHome = createObject( 'java', 'java.lang.System' ).getProperty( 'user.home' );
		return this;
	}

	/**
	* Resolve the incoming path from the file system
	* @path.hint The directory to resolve
	* @basePath.hint An expanded base path to resolve the path against. Defaults to CWD.
	*/
	function resolvePath( required string path, basePath=shell.pwd() ) {

		// Load our path into a Java file object so we can use some of its nice utility methods
		var oPath = createObject( 'java', 'java.io.File' ).init( path );

		// This tells us if it's a relative path
		// Note, at this point we don't actually know if it actually even exists yet

		// If we're on windows and the path starts with a single / or \
		if( isWindows() && reFind( '^[\\/][^\\/]', path ) ) {

			// Concat it with the drive root in the base path so "/foo" becomes "C:/foo" (if the basepath is C:/etc)
			oPath = createObject( 'java', 'java.io.File' ).init( listFirst( arguments.basePath, '/\' ) & '/' & path );

		// If path is "~"
		// Note, we're supporting this on Windows as well as Linux because it seems useful
		} else if( path == '~' ) {

			var userHome = createObject( 'java', 'java.lang.System' ).getProperty( 'user.home' );
			oPath = createObject( 'java', 'java.io.File' ).init( userHome );

		// If path starts with "~/something" but not "~foo" (a valid folder name)
		} else if( reFind( '^~[\\\/]', path ) ) {

			oPath = createObject( 'java', 'java.io.File' ).init( userHome & right( path, len( path ) - 1 ) );

		} else if( !oPath.isAbsolute() ) {

			// If it's relative, we assume it's relative to the current working directory and make it absolute
			oPath = createObject( 'java', 'java.io.File' ).init( arguments.basePath & '/' & path );

		}

		// This will standardize the name and calculate stuff like ../../
		return calculateCanonicalPath( oPath.toString() );

	}

	/**
	* I wrote my own version of this because the getCanonicalPath() runs isDirectory() and exists()
	* checks inside of it which SLOW DOWN when ran tens of thousands of times at once!
	* 
	* @path The path to Canonicalize
	*/
	string function calculateCanonicalPath( required string path ) {
		var trailingSlash = path.endsWith( '/' );
		var pathArr = path.listToArray( '/\' );
			
		// Empty string for Unix
		if( path.left( 1 ) == '/' ) {
			var root = '';
		// Windows network share like //server-name
		} else if( path.left( 2 ) == '\\' ) {
			var root = '\\';
		// C:, D:, etc for Windows
		} else {
			var root = path.listFirst( '/\' );
			pathArr.deleteAt( 1 );
		}
		
		var newPathArr = [];
		// Loop over path
		for( var pathElem in pathArr ) {
			// For every ../ trim a folder off the accumulated path
			if( pathElem == '..' ) {
				if( newPathArr.len() ) {
					newPathArr.deleteAt( newPathArr.len() );
				}
			// "normal" folder names just get appended
			} else {
				newPathArr.append( pathElem );	
			}
		}
		
		// Re-attach the drive root and turn the array back into a slash-delimted path
		var tmpPath = newPathArr.toList( '/' ).reReplace( '[/\\]', server.separator.file, 'all' ) & ( trailingSlash ? server.separator.file : '' );
		
		if( root == '\\' ) {
			return root & tmpPath;
		} else {
			return root & server.separator.file & tmpPath;			
		}
		
	}

	/**
	* Tells you if a path is the drive root
	* @path The path to look at
	*/
	boolean function isDriveRoot( required string path ) {
		// Load our path into a Java file object so we can use some of its nice utility methods
		var oPath = createObject( 'java', 'java.io.File' ).init( path );
		// Drive roots don't have any name elements
		return ( oPath.toPath().getNameCount()==0 );
	}

	/**
	* Get the JRE Executable from the File System
	*/
	function getJREExecutable( javaHome ){
		// get java home
		var jreDirectory = arguments.javaHome ?: createObject( "java", "java.lang.System" ).getProperty( "java.home" );
		if( isNull( jreDirectory ) OR !len( jreDirectory ) ){
			throw(message="Java.home not found", type="IllegalStateException" );
		}
		// detect OS
		var fileExtension = findNoCase( "windows", server.os.name ) ? ".exe" : "";
		// build path to executable
		var javaPath = jreDirectory & "/" & "bin" & "/java#fileExtension#";
		// build command
		var javaCommand =  createObject( "java", "java.io.File").init( javaPath ).getCanonicalPath();

		return javaCommand;
	}

	// OS detector
	boolean function isWindows(){ return variables.os.contains( "win" ); }
    boolean function isLinux(){ return variables.os.contains( "linux" ); }
    boolean function isMac(){ return variables.os.contains( "mac" ); };

    /**
    * Get a native java.io.File object
    */
    function getJavaFile( required file ){
    	return createObject( "java", "java.io.File" ).init( arguments.file );
    }

    /**
    * Operating system open files or directories natively
    * @file.hint the file/directory to open
    */
    boolean function openNatively( required file ){
    	var desktop 	= createObject( "java", "java.awt.Desktop" );
    	var target 		= getJavaFile( arguments.file );

    	// open using awt class, if it fails, we are in headless mode.
    	try {
	    	if( desktop.isDesktopSupported() and target.isFile() ){
	    		desktop.getDesktop().edit( target );
	    		return true;
	    	}
    	} catch( any e ) {
    		// Silently log this and we'll try a different method below
    		if( e.message contains 'No application is associated with the specified file' ) {
				logger.error( '#e.message# #e.detail#' );
    		} else {
				logger.error( '#e.message# #e.detail#' , e.stackTrace );
    		}
    	}

    	// if we get here, then we don't support desktop awt class, most likely in headless mode.
    	var runtime = createObject( "java", "java.lang.Runtime" ).getRuntime();
    	if( isWindows() and target.isFile() ){
    		runtime.exec( [ "rundll32", "url.dll,FileProtocolHandler", target.getCanonicalPath() ] );
		}
		else if( isWindows() and target.isDirectory() ){
			var processBuilder = createObject( "java", "java.lang.ProcessBuilder" )
				.init( [ "explorer.exe", target.getCanonicalPath() ] )
				.start();
		}
		// Linux based or mac
		else {
			runtime.exec( [ "/usr/bin/open", target.getCanonicalPath() ] );
		}
		return true;
    }

    /**
    * Operating system browser opener
    * @uri.hint the URI to open
    */
    boolean function openBrowser( required URI ){
    	var desktop = createObject( "java", "java.awt.Desktop" );

    	if( !findNoCase( "http", arguments.URI ) ){
    		arguments.URI = "http://#arguments.uri#";
    	}

    	// open using awt class, if it fails, we are in headless mode.
    	if( desktop.isDesktopSupported() ){
    		desktop.getDesktop().browse( createObject( "java", "java.net.URI" ).init( arguments.URI ) );
    		return true;
    	}

    	// if we get here, then we don't support desktop awt class, most likely in headless mode.
    	var runtime = createObject( "java", "java.lang.Runtime" ).getRuntime();
    	if( isWindows() ){
    		// Windows Approach
    		runtime.exec( [ "rundll32", "url.dll,FileProtocolHandler", arguments.URI ] );
		} else if ( isMac() ) {
			// Mac Approach
			runtime.exec( [ "open", arguments.URI ] );
		} else {
			// Default to Linux
			var browsers = [ "mozilla", "firefox", "opera", "konqueror", "epiphany" ];
			for( var thisBrowser in browsers ){
				// try to open them
				if( runtime.exec( "which #thisBrowser#" ).waitFor() == 0 ){
					// found it, open
					runtime.exec( "#thisBrowser# " & arguments.URI );
					return true;
				}
			}
			// if we get here we could not open it.
			return false;
		}

		return true;
    }

    /**
    * Accepts an absolute path and returns a relative path
    * Does NOT apply any canonicalization
    */
    string function makePathRelative( required string absolutePath ) {
    	if( !isWindows() ) {
    		// TODO: Unix paths with a period in a folder name are likely still a problem.
    		return arguments.absolutePath;
    	}
    	
		// UNC network path.
		if( arguments.absolutePath.left( 2 ) == '\\' ) {
			// Strip the \\
			arguments.absolutePath = arguments.absolutePath.right( -2 );
			if( arguments.absolutePath.listLen( '/\' ) < 2 ) {
				throw( 'Can''t make relative path for [#absolutePath#].  A mapping must point ot a share name, not the root of the server name.' );
			}
			
			// server/share
	    	var UNCShare = listFirst( arguments.absolutePath, '/\' ) & '/' & listGetAt( arguments.absolutePath, 2, '/\' );
	    	// everything after server/share
	    	var path = arguments.absolutePath.listDeleteAt( 1, '/\' ).listDeleteAt( 1, '/\' );
	    	var mapping = locateUNCMapping( UNCShare );
	    	return mapping & '/' & path;
    	
    	// If one of the folders has a period, we've got to do something special.
    	// C:/users/brad.development/foo.cfc turns into /C__users_brad_development/foo.cfc
    	} else if( getDirectoryFromPath( arguments.absolutePath ) contains '.' ) {
    		var mappingPath = getDirectoryFromPath( arguments.absolutePath );
    		mappingPath = mappingPath.replace( '\', '/', 'all' );
    		mappingPath = mappingPath.listChangeDelims( '/', '/' );

    		var mappingName = mappingPath.replace( ':', '_', 'all' );
    		mappingName = mappingName.replace( '.', '_', 'all' );
    		mappingName = mappingName.replace( '/', '_', 'all' );
    		mappingName = '/' & mappingName;

    		createMapping( mappingName, mappingPath );
    		return mappingName & '/' & getFileFromPath( arguments.absolutePath );

    	// Otherwise, do the "normal" way that re-uses top level drive mappings
    	// C:/users/brad/foo.cfc turns into /C_Drive/users/brad/foo.cfc
    	} else {
	    	var driveLetter = listFirst( arguments.absolutePath, ':' );
	    	var path = listRest( arguments.absolutePath, ':' );
	    	var mapping = locateDriveMapping( driveLetter );
	    	return mapping & path;
    	}
    }

    /**
    * Accepts a Windows drive letter and returns a CF Mapping
    * Creates the mapping if it doesn't exist
    */
    string function locateDriveMapping( required string driveLetter  ) {
    	var mappingName = '/' & arguments.driveLetter & '_drive';
    	var mappingPath = arguments.driveLetter & ':/';
    	createMapping( mappingName, mappingPath );
   		return mappingName;
    }

    /**
    * Accepts a Windows UNC network share and returns a CF Mapping
    * Creates the mapping if it doesn't exist
    */
    string function locateUNCMapping( required string UNCShare  ) {
    	var mappingName = '/' & arguments.UNCShare.replace( '/', '_' ) & '_UNC';
    	var mappingPath = '\\' & arguments.UNCShare & '/';
    	createMapping( mappingName, mappingPath );
   		return mappingName;
    }
    
    function createMapping( mappingName, mappingPath ) {
    	var mappings = getApplicationSettings().mappings;
    	if( !structKeyExists( mappings, mappingName ) || mappings[ mappingName ] != mappingPath ) {
    		mappings[ mappingName ] = mappingPath;
    		application action='update' mappings='#mappings#';
   		}
    }
	
	/*
	* Turns all slashes in a path to forward slashes except for \\ in a Windows UNC network share
	*/
	function normalizeSlashes( string path ) {
		if( path.left( 2 ) == '\\' ) {
			return '\\' & path.replace( '\', '/', 'all' ).right( -2 );
		} else {
			return path.replace( '\', '/', 'all' );			
		}
	}

}
