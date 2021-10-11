
/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @description
*
* I am a helper object for executing compile actions for "javac" command and
* jarring actions for "jar" command. Create me and call my
* methods to compile and jar any java project, then .run() will execute me.
*
*/

component accessors=true {

    /* root folder of the project you are working with (compiling, jar) */
    property name='projectRoot'             type="string";
    /* folder inside root project where source files reside (.java) */
    property name='sourceDirectory'         type='string';
    property name='classPathDirectory'      type='string';
    property name='classOutputDirectory'    type='string';
    property name='verbose'                 type='boolean';
    property name='encode'                  type='string';
	property name='sourcePaths'				type='array';
	property name='createJar'				type='boolean';
	property name='jarNameString'			type='string';
	property name='libsDir'					type='string';
	property name='compileOptionsString'	type='string';
	property name='jarOptionsString'		type='string';
    property name='javaBinFolder'           type='string';
	property name='customManifest'			type='string';

    //DI
	property name="packageService"	inject="PackageService";
    property name='wirebox'         inject='wirebox';
    property name='fileSystemUtil'  inject='FileSystem';
	property name='shell'	        inject='shell';
    property name='job'		        inject='interactiveJob';
	property name="tempDir" 		inject="tempDir@constants";

    /*
    have a classpath
    have a verbose flag
    have a encoding flag option
    */

    public function init() {
        setSourceDirectory( 'src\main\java\' );
        setClassOutputDirectory( 'classes\java\main' );
        setVerbose( false );
        setEncode( '' );
		setSourcePaths( [''] );
		setCreateJar( false );
		setLibsDir( 'libs' );
		setCompileOptionsString( '' );
		setJarOptionsString( '' );
		setJarNameString( '' );
		setCustomManifest( '' );
        return this;
    }

	/**
	 * Sets the directory to run the command in
  	 **/
	function projectRoot( required projectRoot ) {
		setProjectRoot( fileSystemutil.resolvePath( projectRoot ) );
		return this;
	}

	function fromSource( required any sourcePaths ) {
		if( isSimpleValue( arguments.sourcePaths ) ) {
			arguments.sourcePaths = listToArray( arguments.sourcePaths, ",", true );
		}
		arguments.sourcePaths = arguments.sourcePaths.map( function( s ) {
			return fileSystemutil.resolvePath( arguments.s, getProjectRoot() );
		} );
		variables.sourcePaths = arguments.sourcePaths;
		return this;
	}

    function toClasses( required classOutputDirectory ){
        setClassOutputDirectory( fileSystemutil.resolvePath( classOutputDirectory, getProjectRoot() ) )
        return this;
    }

    function verbose() {
        setVerbose( true );
        return this;
    }

    function withEncoding( required encodeValue ) {
        setEncode( encodeValue );
        return this;
    }

	function toJar( string jarName='' ) {
		setJarNameString( jarName );
		setCreateJar( true );
		return this;
	}

	function libsDir( required libsDir ) {
		setLibsDir(libsDir);
		return this;
	}

	function compileOptions( required string options ) {
		setCompileOptionsString( options );
		return this;
	}

	function jarOptions( required string options) {
		setJarOptionsString( options );
		return this;
	}

	function addToManifest( required string customManifest ) {
		setCustomManifest( fileSystemutil.resolvePath( customManifest, getProjectRoot() ) );
		return this;
	}

	function withResources( string resourcesFolder ) {
		//if it has a resourcefolder it uses that one
		//if its empty then use java\main\resources
	}

	function toFatJar(  ) {
		//if it has a jarFolder use that one
		//if it does not have any use java\main\libs

		//take all the jars in libs folder and unzip them
		//add them to the classoutputdirectory with the rest of then
		//make the jar
	}

    function run() {
		job.start( 'Compiling' );

        job.start( 'find jdk bin directory' );
		setJavaBinFolder( findJDKBinDirectory() );
        job.complete();

        job.start( 'compiling the code' );
		compileCode();
        job.complete();

		if( getCreateJar() ) {
            job.start( 'creating the jar' );
    		buildJar();
            job.complete();
		}

		job.complete( getVerbose() );
    }

	function compileCode() {

		if( directoryExists( getClassOutputDirectory() ) ){
			directoryDelete( getClassOutputDirectory(), true )
		}

		//shell.printString( " glob-> start... " );
        //job.addLog( " glob-> start... " );

		var globber = wirebox.getInstance( 'globber' );
		var tempSrcFileName = tempDir & 'temp#createUUID()#.txt';

		setSourcePaths( getSourcePaths().map( function( p ) {
			var currentPath = fileSystemutil.resolvePath( arguments.p, getProjectRoot() );
			if ( directoryExists( currentPath ) ) {
				currentPath &= "**.java";
				return currentPath;

			} else if ( FileExists( currentPath ) ) {
				return currentPath;

			} else if ( Find("**", currentPath) ) {
				return currentPath;

			} else {
				throw(
					message='Non-Existing Folder', detail=currentPath & ' does not exist',
					type="commandException"
				);

			}
			return currentPath;

		} ) );

        job.addLog( " " & serialize( getSourcePaths() ) & " " );
		try{

			writeTempSourceFile( tempSrcFileName );

            //job.addLog( " gJBF-->#getJavaBinFolder()#javac<-- " );
            //job.addLog( " cOD-> #variables.classOutputDirectory# " );
			var javacCommand = 'run "#getJavaBinFolder()#javac" "@#tempSrcFileName#" -d #variables.classOutputDirectory# #variables.compileOptionsString#';

			/* if ( getVerbose() ) {
				javacCommand &= " -verbose";
			} */

			if ( getEncode().len() ){
				javacCommand &= " -encoding #variables.encode#";
			}

			//shell.printString( " " & javacCommand & " " );
            job.addLog( " " & javacCommand & " " );
			command( javacCommand ).run();

		} finally {
			if ( FileExists( tempSrcFileName ) ) {
				fileDelete( tempSrcFileName );
			}

		}

	}

	function writeTempSourceFile( string tempSrcFileName , array sourcePath=getSourcePaths() , string extension=".java" ) {
		var globber = wirebox.getInstance( 'globber' );

		//shell.printString( " gSP-> #serialize(getSourcePaths())# " );
        job.addLog( " gSP-> #serialize(sourcePath)# " );
		var sourceList = globber
				.setPattern( sourcePath )
				.asQuery()
				.matches()
				.filter(( row ) => row.type=="file" && row.name.endsWith( extension ))
				.reduce(( acc, row ) => {
					return listappend( acc, row.directory & "/" & row.name, chr(10) );
				}, "")

        job.addLog( " sList-> #serialize(sourceList)# " );
		if( !sourceList.len() ) {
			/* throw(
				message='No java source files found in [#sourceDirs.toList()#]', detail='Check fromSource() and try again',
				type="commandException"
			); */
			throw(
				message='No java source files found in [#sourceList.len()#]', detail='Check fromSource() and try again',
				type="commandException"
			);
		}

		fileWrite( tempSrcFileName, sourceList );
	}

	function buildJar() {
		var currentLibsDir = fileSystemutil.resolvePath( getLibsDir(), getProjectRoot() );
		var jarName = getJarNameString();
        var currentProjectRoot = getProjectRoot();

        var tempSrcFileName = tempDir & 'temp#createUUID()#.txt';

        var sourceFolders = [];
		buildJarSourceFolders = fileSystemutil.resolvePath( variables.classOutputDirectory, getProjectRoot() );
        sourceFolders.append( buildJarSourceFolders & "**.class" );

		job.addLog( "currLibsDir-> #currentLibsDir#" );

        job.start( ' for build jar check jarName ' );
        if( !jarName.len() ){
            // jarName is empty
            //job.addLog( ' jarName is empty ' );
			job.start( ' get jarName From Package ' );
			jarName = getJarNameFromPackage( currentProjectRoot );
			job.complete();

            if( !jarName.len() ) {
                // it is not a package its a normal folder
				var word = '';
				if( ListLen( getProjectRoot(), "\/" ) >= 1 ) {
					word = ListLast( getProjectRoot(), "\/" );

				} else {
					word = "output";

				}
				jarName &= word & ".jar";
				//job.addLog( ' jarName= #jarName# ' );

            }

        }

        job.complete();

        try{
            //writeTempSourceFile( tempSrcFileName,['D:\Javatest\greetings\classes\**.class'], ".class" );
            writeTempSourceFile( tempSrcFileName, sourceFolders, ".class" );

            //j = 'run "#getJavaBinFolder()#jar" --file #currentLibsDir##jarName# #getJarOptionsString()#';
            //j = 'run "#getJavaBinFolder()#jar" --create --file #currentLibsDir#testX.jar "@#tempSrcFileName#" #getJarOptionsString()#';
			if( !getCustomManifest().len() ) {
				j = 'run jar cf "#currentLibsDir#\#jarName#" "@#tempSrcFileName#" #getJarOptionsString()# ';
			} else {
            	j = 'run jar cfm "#currentLibsDir#\#jarName#" "#variables.customManifest#" "@#tempSrcFileName#" #getJarOptionsString()# ';
			}
            //shell.printString( " " & j & " " );
            job.addLog( " " & j & " " );
            command( j ).run();

        } finally {
			if ( FileExists( tempSrcFileName ) ) {
				fileDelete( tempSrcFileName );
			}
        }


	}

    function getJarNameFromPackage( string currentFolder ){
		//job.addLog( ' jarName is empty ' );
		//job.addLog( ' currentProjectRoot-> #currentFolder# ' );
		jarName = '';

		if( packageService.isPackage( currentFolder ) ) {

			//job.addLog( ' dir is a package ' );
			//job.addLog( ' inside getJarNameFromPackage() ' );
			var boxJSON = packageService.readPackageDescriptor( currentFolder );
			var packageName = "";
			var packageVersion = "";

			if( len( boxJSON.slug ) ) {
				packageName = boxJSON.slug;
				jarName &= packageName;

				if( len( boxJSON.version ) ) {
					packageVersion = boxJSON.version;
					jarName &= "-" & packageVersion;
				}

				jarName &= ".jar"

			}

		}

		//job.addLog( ' jarName for this package is: #jarName# ' );
        return jarName;
    }

	function combiningFatJar() {
		j = "run fat jar ";
		shell.printString( " " & j & " " );
		//command( j ).run();
	}

	/**
	 * Run another command by DSL.
	 * @name The name of the command to run.
 	 **/
	function command( required name ) {
		return wirebox.getinstance( name='CommandDSL', initArguments={ name : arguments.name } );
	}

	string function findJDKBinDirectory() {
		var OSExecSuffix = '';
		var OSPathSearch = '!which';

		if( fileSystemUtil.isWindows() ) {
			OSExecSuffix = '.exe';
			OSPathSearch = '!where';
		}

		// First attempt: See if CommandBox CLI is using a JDK to run
		var CLIBinPath = getDirectoryFromPath( fileSystemUtil.getJREExecutable() );

		if( fileExists( CLIBinPath & 'javac' & OSExecSuffix ) ) {
			job.addLog( 'JDK found in the Java installation CommandBox is using.' );
			return CLIBinPath;
		}

		// Second attempt: Check and see if the OS path has a JDK
		try {
			var OSBinPath = command( OSPathSearch & ' javac' ).run( returnOutput=true ).listToArray( chr(13)&chr(10) ).first()
			OSBinPath = getDirectoryFromPath( OSBinPath );
			job.addLog( 'JDK found your OS path.' );
			return OSBinPath;
		} catch( any var e ) {
			// Error is raised if binary is not found on path
		}

		// Third attempt: Look at all of the installed Server JREs and see if there is a JDK laying around
		var javaEndpoint = endpointService.getEndpoint( 'java' );
		var installedJREs = javaService.listJavaInstalls();
		for( var installID in installedJREs ) {
			var javaInstall = installedJREs[ installID ];
			var javaDetails = javaEndpoint.parseDetails( javaInstall.packageVersion );

			// If it's not a JDK or is not installed, NEXT!
			if( javaDetails.type != 'jdk' || !javaInstall.isInstalled ) {
				continue;
			}

			// Check just to make sure the JDK actually is for the current OS
			if(
				( fileSystemUtil.isWindows() && javaDetails.os != 'windows' )
				|| ( fileSystemUtil.isLinux() && javaDetails.os != 'linux' )
				|| ( fileSystemUtil.isMac() && javaDetails.os != 'mac' )
			 ) {
				continue;
			}

			// TODO: Check if the version of the JDK matches what we need.
			// TODO: For ex: you can't compile with a target of Java 11 when using JDK 8.

			// Assert: If we made it here, the current version we're looping over is a qualifying JDK!

			job.addLog( 'JDK found in a pre-downloaded server JRE.' );
			return javaInstall.directory.listAppend( installID, '/' ) & '/bin/';
		}

		// Fourth attempt: Install something to use:
		job.addLog( 'JDK not found, let''s download one!' );
		var javaHome = javaService.getJavaInstallPath( 'openjdk11_jdk', getVerbose() );
		job.addLog( 'JDK downloaded (we''ll use it again next time)' );
		return javaHome.listAppend( 'bin/', '/' );
	}

}
