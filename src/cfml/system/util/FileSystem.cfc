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
	property name="shell"				inject="shell";
	property name="logger"				inject="logbox:logger:{this}";
	property name="tempDir"				inject="tempDir@constants";
	property name="configService"		inject="configService";

	function init() {
		variables.os = createObject( "java", "java.lang.System" ).getProperty( "os.name" ).toLowerCase();
		variables.userHome = createObject( 'java', 'java.lang.System' ).getProperty( 'user.home' );

        variables.Channels = createObject( "java", "java.nio.channels.Channels" );
        variables.StandardOpenOption = createObject( "java", "java.nio.file.StandardOpenOption" );
        variables.FileChannel = createObject( "java", "java.nio.channels.FileChannel" );
        variables.ByteBuffer = createObject( "java", "java.nio.ByteBuffer" );
        variables.CharBuffer = createObject( "java", "java.nio.CharBuffer" );
        variables.Charset = createObject( "java", "java.nio.charset.Charset" );
        variables.CodingErrorAction = createObject( "java", "java.nio.charset.CodingErrorAction" );
        variables.String = createObject( "java", "java.lang.String" );

		return this;
	}

	function getNativeShell() {
		return configService.getSetting( 'nativeShell', getDefaultNativeShell() );
	}
	
	function getDefaultNativeShell() {
         var shells = [ "/bin/bash","/usr/bin/bash",
            "/bin/pfbash", "/usr/bin/pfbash",
            "/bin/csh", "/usr/bin/csh",
            "/bin/pfcsh", "/usr/bin/pfcsh",
            "/bin/jsh", "/usr/bin/jsh",
            "/bin/ksh", "/usr/bin/ksh",
            "/bin/pfksh", "/usr/bin/pfksh",
            "/bin/ksh93", "/usr/bin/ksh93",
            "/bin/pfksh93", "/usr/bin/pfksh93",
            "/bin/pfsh", "/usr/bin/pfsh",
            "/bin/tcsh", "/usr/bin/tcsh",
            "/bin/pftcsh", "/usr/bin/pftcsh",
            "/usr/xpg4/bin/sh", "/usr/xp4/bin/pfsh",
            "/bin/zsh", "/usr/bin/zsh",
            "/bin/pfzsh", "/usr/bin/pfzsh",
            "/bin/sh", "/usr/bin/sh" ];
		
		if( isWindows() ) {
			var defaultShell = 'cmd';			
		} else {
			var defaultShell = '/bin/bash';
	        for( var shell in shells ) {
	            if( createObject( 'java', 'java.io.File' ).init( shell ).canExecute() ){
	                defaultShell = shell;
	                break;
	            }
	        }	
		}
        return defaultShell;
	}

	/**
	* This resolves an absolute or relative path using the rules of the operating system and CLI.
	* It doesn't follow CF mappings and will also always return a trailing slash if pointing to
	* an existing directory.
	*
	* Resolve the incoming path from the file system
	* @path.hint The directory to resolve
	* @basePath.hint An expanded base path to resolve the path against. Defaults to CWD.
	* @forceDirectory is for optimization. If you know the path is a directory for sure, pass true and we'll skip the directoryExists() check for performance
	*/
	function resolvePath( required string path, basePath=shell.pwd(), boolean forceDirectory=false ) {

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
		var finalPath = oPath.toString() & ( ( trailingSlash || forceDirectory ) ? server.separator.file : '' );

		// This will standardize the name and calculate stuff like ../../
		if( forceDirectory ) {
			finalPath = calculateCanonicalPath( finalPath );
		} else {
			finalPath = getCanonicalPath( finalPath );
		}

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
		} else if( isWindows() and target.isDirectory() ){
			var processBuilder = createObject( "java", "java.lang.ProcessBuilder" )
				.init( [ "explorer.exe", target.getCanonicalPath() ] )
				.start();
		} else if( isMac() ) {
		    // Mac
			runtime.exec( [ "/usr/bin/open", target.getCanonicalPath() ] );
		} else if( isLinux() ) {
            // Linux
            // If there is xdg-open around, we'll try to use it. This should at least work on Ubuntu-based desktop systems and can deal well with both directories and files.
            if( runtime.exec( "which xdg-open" ).waitFor() == 0 ) {
                runtime.exec( [ "/usr/bin/xdg-open", target.getCanonicalPath() ] );
            // Fallback to generic system editor for files
            } else if ( runtime.exec ("which editor" ).waitFor() == 0  and target.isFile() ) {
                runtime.exec( [ "/usr/bin/editor", target.getCanonicalPath() ] );
            }
            // Nothing else to do at this stage
		} else {
            // We don't even know the operating system
        }
		return true;
    }

    /**
    * Operating system browser opener
	* @uri.hint the URI to open
	* @browser.hint the browser to use
    */
    boolean function openBrowser( required URI, browser="" ){
		var rwbo = createObject( "java", "runwar.BrowserOpener" );
		// if binding to all IPs, swap out with localhost.
		if( URI.find( '0.0.0.0' ) ) {
			URI.replace( '0.0.0.0', '127.0.0.1' );
		}

    	if( !findNoCase( "http", arguments.URI ) ){
    		arguments.URI = "http://#arguments.uri#";
    	}

		if( !len( browser ) ) {
			browser = configService.getSetting( 'preferredBrowser', '' );
		}

		rwbo.openURL(arguments.URI, browser);
		
		return true;
	}

	array function browserList() {
		var browsers = ['firefox','chrome','opera'];
		if( isWindows() ){
			ArrayAppend(browsers, ['edge','ie'], true);
		}else if( isMac() ){
			ArrayAppend(browsers, ['edge','safari'], true);
		}else{
			ArrayAppend(browsers, ['konqueror','epiphany'], true);
		}
		return browsers;
	}	
	
	
    /**
    * Accepts an absolute path and returns a relative path
    * Does NOT apply any canonicalization
    */
    string function makePathRelative( required string absolutePath ) {


    	// If one of the folders has a period, we've got to do something special.
    	// C:/users/brad.development/foo/bar.cfc turns into /C__users_brad_development/foo/bar.cfc
    	if( getDirectoryFromPath( arguments.absolutePath ) contains '.' ) {
			var leadingSlash = arguments.absolutePath.startsWith( '/' );
			var UNC = arguments.absolutePath.startsWith( '\\' );
    		var leftOver = getDirectoryFromPath( arguments.absolutePath );
    		leftOver = leftOver.replace( '\', '/', 'all' );
    		leftOver = leftOver.listChangeDelims( '/', '/' );
    		var mappingPath = '';    		
    		var mappingName = '';
    		
    		// "eat up" the original path until we've consumed the folder containing the dot
    		while( leftOver contains '.' ) {
    			// Strip off the first folder and add it to the mapping name
    			var nextSegmentCleaned = leftOver.listFirst( '/' )
    				.replace( ':', '_', 'all' )
    				.replace( '.', '_', 'all' );
    			mappingName = mappingName.listAppend( nextSegmentCleaned, '_' );
	    			
	    		// Add the non-escaped version to the matching path
				mappingPath = mappingPath.listAppend( leftOver.listFirst( '/' ), '/' );
				
				// Reduce the left over path
				leftOver = leftOver.listDeleteAt( 1, '/' )
    		}
    		
    		// Mapping needs to be in format of /mapping_name
    		mappingName = '/' & mappingName;

			// *nix needs this
			if( leadingSlash ) {
				mappingPath = '/' & mappingPath;
			}

			var nonMappingPart = getFileFromPath( arguments.absolutePath );
			if( leftOver.len() ) {
				nonMappingPart = leftOver & '/' & nonMappingPart;
			}
			// UNC network paths
			if( UNC ) {
				var mapping = locateUNCMapping( mappingPath );
				return mapping & '/' & nonMappingPart;
			} else {
				createMapping( mappingName, mappingPath );
				return mappingName & '/' & nonMappingPart;
			}
		}

    	// *nix needs to include first folder due to Lucee bug.
    	// So /usr/brad/foo.cfc becomes /usr
    	if( !isWindows() ) {
    		if( listLen( arguments.absolutePath, '/' ) > 1 ) {
		    	var firstFolder = listFirst( arguments.absolutePath, '/' );
		    	var path = listRest( arguments.absolutePath, '/' );	
    		} else {
		    	var firstFolder = '';
		    	var path = listChangeDelims( arguments.absolutePath, '/', '/' );
    		}
	    	var mapping = locateUnixDriveMapping( firstFolder );
	    	return mapping & '/' & path;
    	}

		// UNC network path.
		if( arguments.absolutePath.left( 2 ) == '\\' ) {
			// Strip the \\
			arguments.absolutePath = arguments.absolutePath.right( -2 );
			if( arguments.absolutePath.listLen( '/\' ) < 2 ) {
				throw( 'Can''t make relative path for [#absolutePath#].  A mapping must point to a share name, not the root of the server name.' );
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
    	var mappingPath = '/' & arguments.rootFolder & ( len( arguments.rootFolder ) ? '/' : '' );
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
	* Also changes double slashes to a single slash
	*/
	function normalizeSlashes( string path ) {
		if( path.left( 2 ) == '\\' ) {
			return '\\' & path.replace( '\', '/', 'all' ).right( -2 );
		} else {
			return path.replace( '\', '/', 'all' ).replace( '//', '/', 'all' );
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

				var CharsetDecoder = Charset
					.forName( 'UTF-8' )
					.newDecoder()
					.onMalformedInput( CodingErrorAction.REPLACE )
					.onUnmappableCharacter(  CodingErrorAction.REPLACE  )
					.replaceWith( '?' );

				var reader = Channels.newReader( fch, CharsetDecoder, -1 );
				var cb = CharBuffer.allocate( 8192 );
				while( ( var size = reader.read( cb ) ) != -1 ) {
					cb.flip();
					sb.append( cb );
					cb.clear();
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

		        fch.write( ByteBuffer.wrap( contents.getBytes( Charset.forName( 'UTF-8' ) ) ) );
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

	/**
	 * Extract a tar.gz file into a folder
	*/
	function extractTarGz( required string sourceFile, required string targetFolder ) {
		// Ensure target directory
		directoryCreate( targetFolder, true, true );

		// Uncompress the Gzip into a tar file
		try {

			var file_in = createobject('java','java.io.FileInputStream').init( sourceFile );
			var fin = createobject('java','java.util.zip.GZIPInputStream').init(file_in);
			var tmpFile = tempDir & '/' & 'temp#createUUID()#.tar';
			var out = createobject('java','java.io.FileOutputStream').init( tmpFile );
			var buf =  repeatString(" " ,100).getBytes();
			var flen = fin.read(buf);
			while (flen GT 0) {
				out.write(buf, 0, flen);
				flen = fin.read(buf);
				shell.checkInterrupted();
			}

			// Extract tar file into our folder
			extract( format='tar', source=tmpFile, target=targetFolder );

		} finally {

			// Clean up, clean up, everybody clean up!
			try { file_in.close(); } catch( any e ) {}
			try { fin.close(); } catch( any e ) {}
			try { out.close(); } catch( any e ) {}

			try { fileDelete( tmpFile ); } catch( any e ) {}

		}
	}

}
