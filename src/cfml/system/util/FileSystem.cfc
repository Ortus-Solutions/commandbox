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
		return this;
	}

	/**
	* Resolve the incoming path from the file system
	* @path.hint The directory to resolve
	* @basePath.hint An expanded base path to resolve the path against. Defaults to CWD.
	*/
	function resolvePath( required string path, basePath=shell.pwd() ) {
		
		try {
			
			// Load our path into a Java file object so we can use some of its nice utility methods
			var oPath = createObject( 'java', 'java.io.File' ).init( path );
	
			// This tells us if it's a relative path
			// Note, at this point we don't actually know if it actually even exists yet
			if( !oPath.isAbsolute() ) {
				// If it's relative, we assume it's relative to the current working directory and make it absolute
				oPath = createObject( 'java', 'java.io.File' ).init( arguments.basePath & '/' & path );
			}
	
			// This will standardize the name and calculate stuff like ../../
			return oPath.getCanonicalPath();
			
		} catch ( any e ) {
			return arguments.basePath & '/' & path;
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
	function getJREExecutable(){
		// get java home
		var jreDirectory = createObject( "java", "java.lang.System" ).getProperty( "java.home" );
		if( isNull( jreDirectory ) OR !len( jreDirectory ) ){
			throw(message="Java.home not found", type="IllegalStateException" );
		}
		// detect OS
		var fileExtension = findNoCase( "windows", server.os.name ) ? ".exe" : "";
		// build path to executable
		var javaPath = jreDirectory & "/" & "bin" & "/java#fileExtension#";
		// build command
		var javaCommand =  createObject( "java", "java.io.File").init( javaPath ).getCanonicalPath();
		// take care of spaces in command
		if( javaCommand contains " " ){
			javaCommand = """#javaCommand#""";
		}
		
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
			logger.error( '#e.message# #e.detail#' , e.stackTrace );
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
    		return arguments.absolutePath;
    	}
    	var driveLetter = listFirst( arguments.absolutePath, ':' );
    	var path = listRest( arguments.absolutePath, ':' );
    	var mapping = locateMapping( driveLetter );
    	return mapping & path;
    }
    
    /** 
    * Accepts a Windows drive letter and returns a CF Mapping
    * Creates the mapping if it doesn't exist
    */
    string function locateMapping( required string driveLetter  ) {
    	var mappingName = '/' & arguments.driveLetter & '_drive';
    	var mappingPath = arguments.driveLetter & ':/';
    	var mappings = getApplicationSettings().mappings;
    	if( !structKeyExists( mappings, mappingName ) ) {
    		mappings[ mappingName ] = mappingPath;
    		application action='update' mappings='#mappings#';
   		}
   		return mappingName;
    }

}