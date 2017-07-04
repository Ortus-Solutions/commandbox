/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the base command implementation.  An abstract class if you will.
*
*/
component accessors="true" singleton {

	// DI
	property name="CR";
	property name="formatterUtil";
	property name="fileSystemUtil";
	property name="shell";
	property name="print";
	property name="wirebox";
	property name="logger";
	property name="parser";
	property name="SystemSettings";

	/**
	* Constructor
	*/
	function init() {
		variables.wirebox			= application.wirebox;
		variables.CR				= wirebox.getInstance( "CR@constants" );
		variables.formatterUtil		= wirebox.getInstance( "Formatter" );
		variables.fileSystemUtil	= wirebox.getInstance( "FileSystem" );
		variables.shell				= wirebox.getInstance( "shell" );
		variables.print				= wirebox.getInstance( "PrintBuffer" );
		variables.logger			= wirebox.getLogBox().getLogger( this );
		variables.parser			= wirebox.getInstance( "Parser" );
		variables.configService		= wirebox.getInstance( "ConfigService" );
		variables.SystemSettings	= wirebox.getInstance( "SystemSettings" );

		hasErrored = false;
		return this;
	}

	// This method needs to be overridden by the concrete class.
	function run() {
		return 'This command CFC has not implemented a run() method.';
	}

	// Convenience method for getting stuff from WireBox
	function getInstance( name, dsl, initArguments={}, targetObject='' ) {
		return wirebox.getInstance( argumentCollection = arguments );
	}

	// Called prior to each execution to reset any state stored in the CFC
	function reset() {
		print.clear();
		hasErrored = false;
	}

	// Get the result.  This will be called if the run() method doesn't return anything
	function getResult() {
		return print.getResult();
	}

	// Returns the current working directory of the shell
	function getCWD() {
		return shell.pwd();
	}

	/**
	 * ask the user a question and wait for response
	 * @message.hint message to prompt the user with
	 * @mask.hint When not empty, keyboard input is masked as that character
	 *
	 * @return the response from the user
 	 **/
	string function ask( message, string mask='', string defaultResponse='' ) {
		print.toConsole();
		return shell.ask( arguments.message, arguments.mask, arguments.defaultResponse );
	}

	/**
	 * Wait until the user's next keystroke
	 * @message.hint Message to display to the user such as "Press any key to continue."
 	 **/
	function waitForKey( message='' ) {
		if( len( arguments.message ) ) {
			print.toConsole();
		}
		return shell.waitForKey( arguments.message );
	}

	/**
	 * Ask the user a question looking for a yes/no response
	 * Accepts any boolean value, or "y".
	 * @message.hint The message to display to the user such as "Would you like to continue?"
 	 **/
	function confirm( required message ) {
		print.toConsole();
		return shell.confirm( arguments.message );
	}

	/**
	 * Run another command by name.
	 * This is deprecated in favor of command(), which escapes parameters for you.
	 * @command.hint The command to run. Pass the same string a user would type at the shell.
 	 **/
	function runCommand( required command, returnOutput=false ) {
		return shell.callCommand( arguments.command, arguments.returnOutput );
	}

	/**
	 * Run another command by DSL.
	 * @name.hint The name of the command to run.
 	 **/
	function command( required name ) {
		return getinstance( name='CommandDSL', initArguments={ name : arguments.name } );
	}

	/**
	 * Create a directory watcher.  Call its DSL to configure it.
 	 **/
	function watch() {
		return getinstance( 'watcher' );
	}

	/**
	 * Return a new globber
 	 **/
	function globber( pattern='' ) {
		var globber = wirebox.getInstance( 'Globber' );
		if( pattern.len() ) {
			globber.setPattern( arguments.pattern );
		}
		return globber;
	}

	/**
	 * Return a new PropertyFile instance
 	 **/
	function propertyFile( propertyFilePath='' ) {
		var propertyFile = wirebox.getInstance( 'propertyFile@propertyFile' );
		if( propertyFilePath.len() ) {
			propertyFile.load( propertyFilePath );
		}
		return propertyFile;
	}

	/**
	 * Use if if your command wants to give controlled feedback to the user without raising
	 * an actual exception which comes with a messy stack trace.
	 * Use clearPrintBuffer to wipe out any output accrued in the print buffer.
	 *
	 * return error( "We're sorry, but happy hour ended 20 minutes ago." );
	 *
	 * @message.hint The error message to display
	 * @clearPrintBuffer.hint Wipe out the print buffer or not, it does not by default
 	 **/
	function error( required message, detail='', clearPrintBuffer=false ) {
		setExitCode( 1 );
		hasErrored = true;
		if( arguments.clearPrintBuffer ) {
			// Wipe
			print.clear();
		} else {
			// Distance ourselves from whatever other output the command may have given so far.
			print.line();
		}
		throw( message=arguments.message, detail=arguments.detail, type="commandException");

	}

	/**
	 * Tells you if the error() method has been called on this command.
 	 **/
	function hasError() {
		return hasErrored;
	}

	/**
	 * Sets the OS exit code
 	 **/
	function setExitCode( required string exitCode ) {
		if( arguments.exitCode != 0 ) {
			hasErrored = true;
		}
		return shell.setExitCode( arguments.exitCode );
	}

	/**
	 * This will open a file or folder externally in the default editor for the user.
	 * Useful for opening a new file for editing that was just created.
 	 **/
	function openPath( path ) {
		// Defer to "open" command.
		command( "open" )
			.params( arguments.path )
			.run();
	}

	/**
	 * This will open a URL in the user's browser
 	 **/
	function openURL( theURL ) {
		// Defer to "browse" command.
		command( "browse" )
			.params( arguments.theURL )
			.run();
	}

	/**
	* Retrieve a Java System property or env value by name.
	*
	* @key The name of the setting to look up.
	* @defaultValue The default value to use if the key does not exist in the system properties
	*/
    function getSystemSetting( required string key, defaultValue ) {
		return systemSettings.getSystemSetting( argumentCollection=arguments );
	}

	/**
	* Retrieve a Java System property by name.
	*
	* @key The name of the setting to look up.
	* @defaultValue The default value to use if the key does not exist in the system properties
	*/
    function getSystemProperty( required string key, defaultValue ) {
		return systemSettings.getSystemProperty( argumentCollection=arguments );
	}

	/**
	* Retrieve an env value by name.
	*
	* @key The name of the setting to look up.
	* @defaultValue The default value to use if the key does not exist in the env
	*/
    function getEnv( required string key, defaultValue ) {
		return systemSettings.getEnv( argumentCollection=arguments );
	}


}