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
	property name="coreClassLoader";

	// DI
	property name="shell" inject="shell";
	property name="logger" inject="logbox:logger:{this}";

	function init() {
		variables.os = createObject( "java", "java.lang.System" ).getProperty( "os.name" ).toLowerCase();
		variables.userHome = createObject( 'java', 'java.lang.System' ).getProperty( 'user.home' );
		
        variables.Channels = createObject( "java", "java.nio.channels.Channels" );
        variables.StandardOpenOption = createObject( "java", "java.nio.file.StandardOpenOption" );
        variables.FileChannel = createObject( "java", "java.nio.channels.FileChannel" );
        variables.ByteBuffer = createObject( "java", "java.nio.ByteBuffer" );
		
		return this;
	}

	/**
	* This resolves an absolute or relative path using the rules of the operating system and CLI.
	* It doesn't follow CF mappings and will also always return a trailing slash if pointing to 
	* an existing directory.
	* 
	* Resolve the incoming path from the file system
	* @path.hint The directory to resolve
	* @basePath.hint An expanded base path to resolve the path against. Defaults to CWD.
	*/
	function resolvePath( required string path, basePath=shell.pwd() ) {

		// The Java class will strip trailing slashses, but these are meaningful in globbing patterns
		var trailingSlash = ( path.len() > 1 && ( path.endsWith( '/' ) || path.endsWith( '\' ) ) );
		// java will remove trailing periods when canonicalizing a path.  I'm not sure that's correct.
		var trailingPeriod = ( path.len() > 1 && path.endsWith( '.' ) && !path.endsWith( '..' ) );
		
		// Load our path into a Java file object so we can use some of its nice utility methods
		var oPath = createObject( 'java', 'java.io.File' ).init( path );

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

		// This tells us if it's a relative path
		// Note, at this point we don't actually know if it actually even exists yet
		} else if( !oPath.isAbsolute() ) {

			// If it's relative, we assume it's relative to the current working directory and make it absolute
			oPath = createObject( 'java', 'java.io.File' ).init( arguments.basePath & '/' & path );
		}
		
		// Add back trailing slash if we had it
		var finalPath = oPath.toString() & ( trailingSlash ? server.separator.file : '' );
		
		// This will standardize the name and calculate stuff like ../../
		finalPath = getCanonicalPath( finalPath )
		
		// have to add back the period after canonicalizing since Java removes it!
		return finalPath & ( trailingPeriod && !finalPath.endsWith( '.' ) ? '.' : '' );

	}

	/**
	* I wrote my own version of this because the getCanonicalPath() runs isDirectory() and exists()
	* checks inside of it which SLOW DOWN when ran tens of thousands of times at once!
	* This function differs from getCanonicalPath() in that it won't append a trailing slash
	* if the path points to an actual folder.  
	* 
	* @path The path to Canonicalize
	*/
	string function calculateCanonicalPath( required string path ) {
		// Trailing slashses are meaningful in globbing patterns
		var trailingSlash = ( path.len() > 1 && ( path.endsWith( '/' ) || path.endsWith( '\' ) ) );
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
		var tmpPath = newPathArr.toList( server.separator.file ) & ( trailingSlash ? server.separator.file : '' );
		
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
    	
    	    	
    	// If one of the folders has a period, we've got to do something special.
    	// C:/users/brad.development/foo.cfc turns into /C__users_brad_development/foo.cfc
    	if( getDirectoryFromPath( arguments.absolutePath ) contains '.' ) {
			var leadingSlash = arguments.absolutePath.startsWith( '/' );
			var UNC = arguments.absolutePath.startsWith( '\\' );
    		var mappingPath = getDirectoryFromPath( arguments.absolutePath );
    		mappingPath = mappingPath.replace( '\', '/', 'all' );
    		mappingPath = mappingPath.listChangeDelims( '/', '/' );

    		var mappingName = mappingPath.replace( ':', '_', 'all' );
    		mappingName = mappingName.replace( '.', '_', 'all' );
    		mappingName = mappingName.replace( '/', '_', 'all' );
    		mappingName = '/' & mappingName;

			// *nix needs this
			if( leadingSlash ) {
				mappingPath = '/' & mappingPath;
			}

			// UNC network paths
			if( UNC ) {	
				var mapping = locateUNCMapping( mappingPath );
				return mapping & '/' & getFileFromPath( arguments.absolutePath );
			} else {
				createMapping( mappingName, mappingPath );
				return mappingName & '/' & getFileFromPath( arguments.absolutePath );
			}
		}
    	
    	// *nix needs to include first folder due to Lucee bug.
    	// So /usr/brad/foo.cfc becomes /usr
    	if( !isWindows() ) {
	    	var firstFolder = listFirst( arguments.absolutePath, '/' );
	    	var path = listRest( arguments.absolutePath, '/' );
	    	var mapping = locateUnixDriveMapping( firstFolder );
	    	return mapping & '/' & path;
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
    * Accepts a Unix root folder and returns a CF Mapping
    * Creates the mapping if it doesn't exist
    */
    string function locateUnixDriveMapping( required string rootFolder ) {
    	var mappingName = '/' & arguments.rootFolder & '_root';
    	var mappingPath = '/' & arguments.rootFolder & '/';
    	createMapping( mappingName, mappingPath );
   		return mappingName;
    }

    /**
    * Accepts a Windows UNC network share and returns a CF Mapping
    * Creates the mapping if it doesn't exist
    */
    string function locateUNCMapping( required string UNCShare  ) {
    	var mappingName = '/' & arguments.UNCShare.replace( '/', '_' ).replace( '.', '_', 'all' ) & '_UNC';
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
	
	/*
	* Loads up Java classes into the class loader that loaded the CLI for immediate use. 
	* You can pass either an array or list of:
	* - directories
	* - Jar files
	* - Class files
	*
	* Note, loaded jars/classes cannot be unloaded and will remain in memory until the CLI exits.
	* On Windows, the jar/class files will also be locked on the file system.  Directories are scanned
	* recursively for for files and everything found will be loaded.
	* 
	* @paths List or array of absolute paths of a jar/class files or directories of them you would like loaded
	*/
	function classLoad( any paths ) {
		
		// Allow list or arrays
		if( isSimpleValue( paths ) ) {
			paths = paths.listToArray();
		}

		// For each path....
		paths.each( function( path ) {

			// Is file
			if( fileExists( path ) ) {
				_classLoad( path );
			// Is directory
			} else if( directoryExists( path ) ) {
				directoryList( path, true, 'array', '*.jar|*.class' )
					.each( function( file ) {
						_classLoad( file );
					} );
			// Is ????
			} else {
				throw( message='The path [#path#] doesn''t exist on your file system.', detail='Make sure you expand any paths you send in.', type="commandException" );
			}

		} );
	}
	
	/*
	* Loads up a jar or class file into the core Lucee classloader.  Note, jars cannot be unloaded and their classes
	* will remain in memory until the CLI exits.  On Windows, the jar files will also be locked on the file system.
	* 
	* @path The absolute path of a jar or class file you would like loaded
	*/
	function _classLoad( string path ) {
		path = normalizeSlashes( path );
		var jURL = createObject( 'java', 'java.io.File' ).init( path ).toURI().toURL();
		var cl = getCoreClassLoader();
		
		// Don't add it if it's already there.
		for( var lib in cl.getURLs() ) {
			if( lib.File contains jURL.getFile() ) {
				return;
			}
		}
		
		var method = cl.getClass().getDeclaredMethod("addURL", [ jURL.getClass() ] );
		method.setAccessible(true);
		method.invoke( cl, [ jURL ] );		
	}
	
	/*
	* Get the Lucee core class loader
	*/
	function getCoreClassLoader( string path ) {
		
		if( isNull( coreClassLoader ) ) {
			coreClassLoader = createObject( 'java', 'cliloader.LoaderCLIMain' ).getClassLoader();
		}
		return coreClassLoader;		
	}
	
	/*
	* Read a file while locking the file system
	*/
	function lockingFileRead( required string path ) {
		// CFLock to prevent two threads on the same JVM from trying to lock the same file. 
		// That will throw an overlappinglock exception since the file lock is JVM-wide
		lock name=path type="exclusive" {
			try {
		        var file = createObject( "java", "java.io.File" ).init( path );		
				var fch=FileChannel.open( file.toPath(), [ StandardOpenOption.CREATE, StandardOpenOption.WRITE, StandardOpenOption.READ ] );
		
		        // This method blocks until it can retrieve the lock.
		        var fileLock = fch.lock();
		
				// Use a reader to collect the characters into a string builder
				var sb = createObject( "java", "java.lang.StringBuilder" ).init();
				var reader = Channels.newReader( fch, 'UTF-8' );
				while( ( var char = reader.read() ) != -1 ) {
					sb.append( chr( char ) );
				}
		        
		    // This stuff always gotta' run.
			} finally {
		        if( !isNull( fileLock ) && fileLock.isValid() ) {
		            fileLock.release();
		        }
		
		        if( !isNull( fch ) ) {
		        	fch.close();
		        }			
			}	
		}
		return sb.toString();
		
	}
	
	/*
	* write a file while locking the file system
	*/
	function lockingFileWrite( required string path, required string contents ) {
		// CFLock to prevent two threads on the same JVM from trying to lock the same file. 
		// That will throw an overlappinglock exception since the file lock is JVM-wide
		lock name=path type="exclusive" {
			try {
				
		        var file = createObject( "java", "java.io.File" ).init( path );		
				var fch=FileChannel.open( file.toPath(), [ StandardOpenOption.CREATE, StandardOpenOption.WRITE, StandardOpenOption.READ ] );
		
		        // This method blocks until it can retrieve the lock.
		        var fileLock = fch.lock();
		
		        fch.write( ByteBuffer.wrap( contents.getBytes() ) );
		        // Trim off any excess
		        fch.truncate( fch.position() );
		        
		    // This stuff always gotta' run.
			} finally {
		        if( !isNull( fileLock ) && fileLock.isValid() ) {
		            fileLock.release();
		        }
		
		        if( !isNull( fch ) ) {
		        	fch.close();
		        }			
			}	
		}
	}

}
