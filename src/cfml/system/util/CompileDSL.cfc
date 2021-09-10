
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
	property name='source'					type='array';
	property name='recursive'				type='boolean';
	property name='withJar'					type='boolean';
	property name='defaultClassOutputDir'	type='string';

    //DI
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

    public function init(){
        setSourceDirectory( '' );
        setClassOutputDirectory( '' );
        setVerbose( false );
        setEncode( '' );
		setSource( [] );
		setRecursive( false );
		setWithJar( false );
		setDefaultClassOutputDir( 'classes\java\' );
        return this;
    }

	/**
	 * Sets the directory to run the command in
  	 **/
	function projectRoot( required projectRoot ) {
		setProjectRoot( fileSystemutil.resolvePath( projectRoot ) );
		return this;
	}

	function fromSource( required any source ) {
		if( isSimpleValue( arguments.source ) ) {
			arguments.source = listToArray( arguments.source );
		}
		arguments.source = arguments.source.map( function( s ) {
			return fileSystemutil.resolvePath( arguments.s, getProjectRoot() );
		} );
		variables.source = arguments.source;
		return this;
	}

    function toClasses( required classOutputDirectory ){
        setClassOutputDirectory( fileSystemutil.resolvePath( classOutputDirectory, getProjectRoot() ) )
        return this;
    }

    function withVerbose() {
        setVerbose( true );
        return this;
    }

    function withEncoding( required encodeValue ) {
        setEncode( encodeValue );
        return this;
    }

	function recursive() {
		setRecursive( true );
		return this;
	}

	function toJar() {
		setWithJar( true );
	}

    function run() {
        runJavaCommands();

    }

	function runJavaCommands() {

		compileCode();

		if( withJar ) {
			creatingJar();
		}

		/* var zipFileName = "D:\Javatest\greetings\test.jar";
		var tmpPath = "D:\Javatest\greetings\";
		cfzip(
			action = "zip",
			file = zipFileName,
			overwrite = true,
			source = tmpPath
		); */

		/* shell.printString( " test filewrite-> " );
		var tempSrcFileName = "D:\Javatest\greetings\temp\temp.txt";
		var sourceDirs = "D:\Javatest\greetings\**.java";
		var fileName = 'temp#createUUID()#.zip';
		var fullPath = tempDir & '/' & fileName;
		var globber = wirebox.getInstance( 'globber' );
		fileWrite(
			tempSrcFileName,
			globber
				.setPattern( sourceDirs )
				.matches()
				.toList( chr(10) )
		); */

		/* var globs = globber
			.setPattern( "D:\Javatest\greetings\**.java" )
			.matches()
			.toList( chr(10) );
		shell.printString( " glob out-> #serialize(globs)# " ); */

	}

	function compileCode() {
		shell.printString( " entering compileCode()... " );
		var workingDirectory = getProjectRoot();
		var classOutputString = "";
		var verboseString = "";
        var encodingString = "";
		var tempSrcFileName = "";
		var fileName = "";

		if ( getRecursive() ) {

			//creating the file path of the txt
			fileName = 'temp#createUUID()#.txt';
			var fullPath = tempDir & fileName;
			shell.printString( " fullpath-> #fullPath# " );

			tempSrcFileName = fullPath;
			var sourceDirs = "D:\Javatest\greetings\**.java";
			var globber = wirebox.getInstance( 'globber' );
			fileWrite(
				tempSrcFileName,
				globber
					.setPattern( sourceDirs )
					.matches()
					.toList( chr(10) )
			);

			//j = " run dir /s /B #workingDirectory#*.java > sources.txt ";
			//shell.printString( j );
			//shell.callCommand( j );
		}

        if ( getSource().len() == 0 ){
            variables.source = listToArray( workingDirectory );
        }

        var currSource = getSource();
        currSource = currSource.map( function( p ) {
            var currFolder = fileSystemutil.resolvePath( arguments.p, getProjectRoot() );
            if ( directoryExists( currFolder ) ) {
                return currFolder & "*.java";
            } else {
                throw(
                    message='Non-Existing Folder', detail=currFolder & ' does not exist',
                    type="commandException"
                );
            }
        } );
        variables.source = currSource;

        arrayeach( variables.source, function( p ) {
            variables.sourceDirectory = variables.sourceDirectory & "#arguments.p# ";
        } );

        if ( getSourceDirectory().len() ) {
            workingDirectory = getSourceDirectory();
        }

        if ( getSourceDirectory().len() ) {
            workingDirectory = getSourceDirectory();
        }

        if ( getClassOutputDirectory().len() ) {
			classOutputString = "-d #variables.classOutputDirectory#";
        } else {
			classOutputString = "-d " & getProjectRoot() & getDefaultClassOutputDir();
		}

        if ( getVerbose() ) {
            verboseString = "-verbose";
        }

        if ( getEncode().len() ){
            encodingString = "-encoding #variables.encode# ";
        }

		if( getRecursive() ){
			j = 'run javac "@#tempSrcFileName#" #classOutputString#';
			//j = 'run javac "@#testDir##fileName#"';
		} else {
			j = "run javac #workingDirectory# #classOutputString# #verboseString# #encodingString#";
		}
		shell.printString( " " & j & " " );
		shell.callCommand( j );
		fileDelete( tempSrcFileName );
	}

	function creatingJar() {
		/* shell.printString( " test filewrite-> " );
		var tempSrcFileName = "D:\Javatest\greetings\temp\temp.txt";
		var sourceDirs = "D:\Javatest\greetings\**.java";
		var fileName = 'temp#createUUID()#.zip';
		var fullPath = tempDir & '/' & fileName;
		var globber = wirebox.getInstance( 'globber' );
		fileWrite(
			tempSrcFileName,
			globber
				.setPattern( sourceDirs )
				.matches()
				.toList( chr(10) )
		); */

		j = "run jar ";
		shell.printString( " " & j & " " );
		//shell.callCommand( j );
	}

	function combiningFatJar() {
		j = "run fat jar ";
		shell.printString( " " & j & " " );
		//shell.callCommand( j );
	}
}
