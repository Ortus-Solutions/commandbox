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

	property name="CR";
	property name="formatterUtil";
	property name="fileSystemUtil";
	property name="shell";
	property name="print";
	property name="wirebox";
	property name="logger";
	property name="parser";
	property name="SystemSettings";
	property name="job";
	property name="exitCode";

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
		variables.job				= wirebox.getInstance( "interactiveJob" );

		variables.exitCode = 0;
		return this;
	}

	// This method needs to be overridden by the concrete class.
	function run() {
		error( 'This command CFC has not implemented a run() method.' );
	}

	function getPrinter() {
		return variables.print;
	}

	// Convenience method for getting stuff from WireBox
	function getInstance( name, dsl, initArguments={}, targetObject='' ) {
		return wirebox.getInstance( argumentCollection = arguments );
	}

	function getExitCode() {
		return variables.exitCode;
	}

	function setExitCode( exitCode ) {
		variables.exitCode = arguments.exitCode;
	}

	// Called prior to each execution to reset any state stored in the CFC
	function reset() {
		print.clear();
		variables.exitCode = 0;
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
	string function ask( message, string mask='', string defaultResponse='', keepHistory=false, highlight=true, complete=false ) {
		print.toConsole();
		return shell.ask( arguments.message, arguments.mask, arguments.defaultResponse, arguments.keepHistory, arguments.highlight, arguments.complete );
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
	 * Let a user choose between several options. Can be set to multiselect, which returns array of selections
	 * multiSelect().setQuestion( 'Please Choose: ' ).setOptions( 'one,two,three' ).ask()
	 **/
	function multiSelect() {
		return getinstance( 'MultiSelect' );
	}

	/**
	 * Run another command by name.
	 * This is deprecated in favor of command(), which escapes parameters for you.
	 * @command.hint The command to run. Pass the same string a user would type at the shell.
 	 **/
	function runCommand( required command, returnOutput=false ) {
		var results = shell.callCommand( arguments.command, arguments.returnOutput );
		
		// If the previous command chain failed
		if( shell.getExitCode() != 0 ) {
			error( 'Command returned failing exit code (#shell.getExitCode()#)', 'Failing Command: ' & command, shell.getExitCode(), shell.getExitCode() );
		}
		
		return results;
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
	* This resolves an absolute or relative path using the rules of the operating system and CLI.
	* It doesn't follow CF mappings and will also always return a trailing slash if pointing to 
	* an existing directory.
	* 
	* Resolve the incoming path from the file system
	* @path.hint The directory to resolve
	* @basePath.hint An expanded base path to resolve the path against. Defaults to CWD.
	*/
	function resolvePath( required string path, basePath=shell.pwd() ) {
		return filesystemUtil.resolvepath( path, basePath );
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
		
		// If the user passed a propertyFile path
		if( propertyFilePath.len() ) {
			
			// Make relative paths resolve to the current folder that the task lives in.
			propertyFilePath = resolvePath( propertyFilePath );
			
			// If it exists, go ahead and load it now
			if( fileExists( propertyFilePath ) ){
				propertyFile.load( propertyFilePath );
			} else {
				// Otherwise, just set it so it can be used later on save.
				propertyFile
					.setPath( propertyFilePath );
			}
			
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
	function error( required message, detail='', clearPrintBuffer=false, exitCode=1 ) {

		if( job.isActive() ) {
			job.errorRemaining( message );
			// Distance ourselves from whatever other output the command may have given so far.
			print.line().toConsole();
		}
		
		setExitCode( arguments.exitCode );
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
		return variables.exitCode != 0;
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


	/**
	* Call this method periodically in a long-running task to check and see
	* if the user has hit Ctrl-C.  This method will throw an UserInterruptException
	* which you should not catch.  It will unroll the stack all the way back to the shell
	*/
	function checkInterrupted() {
		shell.checkInterrupted();
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
	function classLoad( paths ) {
		fileSystemUtil.classLoad( paths );
	}


}
