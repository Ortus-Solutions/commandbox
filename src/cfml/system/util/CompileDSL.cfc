
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

    //DI
    property name='wirebox'         inject='wirebox';
    property name='fileSystemUtil'  inject='FileSystem';
	property name='shell'	        inject='shell';
    property name='job'		        inject='interactiveJob';

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

    string function run() {
        j = generateJavacCommand();
		shell.printString( j );
		shell.callCommand( j );

    }

	function generateJavacCommand() {
        var workingDirectory = getProjectRoot();
        var classOutputString = "";
        var verboseString = "";
        var encodingString = "";

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

        if ( getClassOutputDirectory().len() ) {
            classOutputString = "-d #variables.classOutputDirectory#";
        }

        if ( getVerbose() ) {
            verboseString = "-verbose";
        }

        if ( getEncode().len() ){
            encodingString = "-encoding #variables.encode# ";
        }

		return "run javac #workingDirectory# #classOutputString# #verboseString# #encodingString#";
	}
}
