
/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @file  D:\Dev\Repos\commandbox\src\cfml\system\util\CompileDSL.cfc
* @author  Balbino Aylagas
* @description
*
* I am a helper object for executing compile actions for "javac" command and
* jarring actions for "jar" command Create me and call my
* methods to compile and jar any java project, then .run() will execute me.
*
*/

component accessors=true {

    property name='command';
    property name='target';
    property name='projectRoot';
    property name='fileSystemUtil';
	property name='wirebox';
    property name='sourceDirectory';
    property name='resourceDirectory';
    property name='classOutputDirectory';

    //DI
	property name='shell'	inject='shell';
    property name='job'		inject='interactiveJob';

    /*
    have a classpath
    have a verbose flag
    have a encoding flag option
    */

    public function init(){
		variables.wirebox			= application.wirebox;
        variables.fileSystemUtil	= wirebox.getInstance( 'FileSystem' );
        setSourceDirectory( '' )
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

    string function run() {

        //shell.printString( " run compile... " );
        var commandCWD = shell.getPWD();
        var newCWD = '';

		if( getProjectRoot().len() ) {
			shell.cd( getProjectRoot() );
            newCWD = shell.getPWD();
		} else {
            newCWD = commandCWD;
        }

        if( getsourcedirectory().len() ) {
            shell.printString( " srcDir-> #variables.sourceDirectory# " );
            newCWD = variables.sourceDirectory;
        }

        try{
            shell.printString( " run javac #newCWD#*.java " );
            shell.callCommand( "run javac #newCWD#*.java" );

        } finally {

			if( getProjectRoot().len() ) {
				shell.cd( commandCWD );
			}

        }
    }
}
