
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
    property name='sourceDirectory';
    property name='resourceDirectory';
    property name='classOutputDirectory';

    //DI
	property name='shell'	inject='shell';
    property name="job"		inject='interactiveJob';

    /*
    have a classpath
    have a verbose flag
    have a encoding flag option
    */

    public function init(){
        return this;
    }

	/**
	 * Sets the directory to run the command in
  	 **/
	function inWorkingDirectory( required workingDirectory ) {
		setWorkingDirectory( arguments.workingDirectory );
		return this;
	}

    string function run() {
        shell.printString( "run compile..." );
        //shell.callCommand( 'run javac -cp D:\Javatest\greetings D:\Javatest\greetings\Hello.java -verbose' );
        shell.callCommand( 'run javac D:\Javatest\greetings\Hello.java -verbose' );
    }
}
