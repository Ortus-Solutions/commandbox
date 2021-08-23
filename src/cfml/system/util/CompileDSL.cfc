
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

component accessors=true  {

    //DI
	property name='shell'	inject='shell';

    public function init(){
        return this;
    }

    string function run() {

    }
}
