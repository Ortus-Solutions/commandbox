/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I am a helper object for executing tasks via a DSL.  Create me and call my
* methods to build up an execution, then .run() will execute me.
*
* I am a transient and hold state.  Do not share me with your friends.
*
*/
component accessors=true {

	property name='taskFile';
	property name='target';
	property name='params';
	property name='target';
	property name='flags';
	property name='workingDirectory';
	property name='rawParams';
	property name='exitCode';


	// DI
	property name='parser'	inject='parser';
	property name='shell'	inject='shell';
	property name='wirebox'	inject='wirebox';
	property name="job"		inject='interactiveJob';

	/**
	 * Create a new, executable task
	 *
	 * @taskFile.hint I am the task to execute
  	 **/
	function init( taskFile='task' ) {

		if( !structKeyExists( arguments, 'taskFile' ) ) {
			throw( 'Task name not provided' );
		}

		setTaskFile( arguments.taskFile );
		setTarget( 'run' );
		setParams( [] );
		setFlags( [] );
		setWorkingDirectory( '' );
		setRawParams( false );
		setExitCode( 0 );
		return this;
	}

	/**
	 * Add params to the task
  	 **/
	function target( target ) {
		setTarget( arguments.target );
		return this;
	}

	/**
	 * Add params to the command
  	 **/
	function params() {
		setParams( arguments );
		return this;
	}

	/**
	 * Convert params to named or positional arguments
  	 **/
	private array function processParams() {
		var processedParams = [];
		if( !arraylen( getParams() ) ) {
			processedParams.append( getTaskFile() );
			processedParams.append( getTarget() );
			return processedParams;
		}

		// Positional params
		if( isNumeric( listFirst( structKeyList( getParams() ) ) ) ) {
			processedParams.append( getTaskFile() );
			processedParams.append( getTarget() );
			for( var param in getParams() ) {
				if( getRawParams() ) {
					processedParams.append( '"#getParams()[ param ]#"' );
				} else {
					processedParams.append( '"#parser.escapeArg( getParams()[ param ] )#"' );					
				}
			}
		// Named params
		} else {
			processedParams.append( 'taskFile="#getTaskFile()#"' );
			processedParams.append( 'target="#getTarget()#"' );
			for( var param in getParams() ) {
				processedParams.append( ':#param#="#parser.escapeArg( getParams()[ param ] )#"' );					
			}
		}

		return processedParams;
	}

	/**
	 * Add flags to the command
  	 **/
	function flags() {

		for( var param in arguments ) {
			var thisParam = arguments[ param ];
			thisParam = ( thisParam.startsWith( '--' ) ? '' : '--' ) & thisParam;
			thisParam = thisParam.replace( '--', '--:' );
			getFlags().append( thisParam );
		}

		return this;
	}

	/**
	 * Sets the directory to run the task in
  	 **/
	function inWorkingDirectory( required workingDirectory ) {
		setWorkingDirectory( arguments.workingDirectory );
		return this;
	}

	/**
	 * Turn this CFC into an array of command tokens
  	 **/
	array function getTokens() {
		var tokens = [];
		// Break the command name on the spaces
		tokens.append( [ 'task', 'run' ], true );
		tokens.append( processParams(), true );
		tokens.append( getFlags(), true );

		return tokens;
	}

	/**
	 * Turn this CFC into a string representation
  	 **/
	string function getCommandString() {
		return getTokens().toList( ' ' );
	}

	/**
	 * Run this command
  	 **/
	string function run( returnOutput=false, boolean echo=false, boolean rawParams=false ) {

		setRawParams( rawParams );

		if( arguments.echo ) {
			shell.callCommand( 'echo "#parser.escapeArg( getCommandString() )#"' );
		}

		var originalCWD = shell.getPWD();
		if( getWorkingDirectory().len() ) {
			shell.cd( getWorkingDirectory() );
		}
		
		try {
			var result = shell.callCommand( getTokens(), true );			
		} finally {
	
			setExitCode( shell.getExitCode() );
			
			var postCommandCWD = shell.getPWD();
	
			// Only change back if the executed command didn't change the CWD
			if( getWorkingDirectory().len() && postCommandCWD == getWorkingDirectory() ) {
				shell.cd( originalCWD );
			}
		}

		if( !isNull( local.result ) && arguments.returnOutput ) {
			return local.result;
		} else {
			shell.printString( result );
		}

	}

}
