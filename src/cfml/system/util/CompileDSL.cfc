
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
        return this;
    }

	/**
	 * Sets the directory to run the command in
  	 **/
	function projectRoot( required projectRoot ) {
		setProjectRoot( fileSystemutil.resolvePath( projectRoot ) );
		return this;
	}

    function fromSource( required sourceDirectory ){
        setSourceDirectory( fileSystemutil.resolvePath( sourceDirectory, getProjectRoot() ) )
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
        var workingDirectory = getProjectRoot();
        var classOutputString = "";
        var verboseString = "";
        var encodingString = "";

        if( getSourceDirectory().len() ) {
            workingDirectory = getSourceDirectory();
        }

        if ( getClassOutputDirectory().len() ) {
            classOutputString = "-d #variables.classOutputDirectory#";
        }

        if ( getVerbose() ) {
            verboseString = "-verbose";
        }

        if ( getEncode().len() ){
            encodingString = "-encoding #variables.encode#";
        }

        var finalCommand = "run javac ";
        finalCommand = listAppend(finalCommand, "#workingDirectory#*.java", " ");
        finalCommand = listAppend(finalCommand, "#classOutputString#", " ");
        finalCommand = listAppend(finalCommand, "#verboseString#", " ");
        finalCommand = listAppend(finalCommand, "#encodingString#", " ");

        shell.printString( " #finalCommand# " );
        shell.callCommand( "#finalCommand#" );

    }
}
