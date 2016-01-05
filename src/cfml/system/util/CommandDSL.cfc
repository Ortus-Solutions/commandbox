/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I am a helper object for executing commands via a DSL.  Create me and call my 
* methods to build up a command chain, then .run() will execute me.
*
* I am a transient and hold state.  Do not share me with your friends.
*
*/
component accessors=true {
	
	property name='command';
	property name='params';
	property name='piped';
	property name='flags';
	property name='append';
	property name='overwrite';
	
	
	// DI
	property name='parser' inject='parser';
	property name='shell' inject='shell';
		
	/**
	 * Create a new, executable command
	 *
	 * @name.hint I am the command to execute
  	 **/
	function init( name ) {
		
		if( !structKeyExists( arguments, 'name' ) ) {
			throw( 'Command name not provided' );
		}
		
		setCommand( arguments.name );
		setPiped( [] );
		setParams( [] );
		setFlags( [] );
		setAppend( '' );
		setOverwrite( '' );
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
			return processedParams;
		}
		
		// Positional params
		if( isNumeric( listFirst( structKeyList( getParams() ) ) ) ) {
			for( var param in getParams() ) {
				processedParams.append( '"#parser.escapeArg( getParams()[ param ] )#"' );
			}
		// Named params
		} else {
			for( var param in getParams() ) {
				processedParams.append( '#param#="#parser.escapeArg( getParams()[ param ] )#"' );
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
			getFlags().append( ( thisParam.startsWith( '--' ) ? '' : '--' ) & thisParam );
		}
		
		return this;
	}
			
	/**
	 * Append results to file 
  	 **/
	function append( required path ) {
		setAppend( '"#parser.escapeArg( arguments.path )#"' );
		return this;
	}
			
	/**
	 * overwrite file with results 
  	 **/
	function overwrite( required path ) {
		setOverwrite( '"#parser.escapeArg( arguments.path )#"' );
		return this;
	}
		
	/**
	 * Pipe additional commands
  	 **/
	function pipe( commandDSL ) {
		
		if( !structKeyExists( arguments, 'commandDSL' ) ) {
			throw( 'Please pass a commandDSL to pipe' );
		}
		
		if( !isObject( arguments.commandDSL ) ) {
			throw( 'What you passed to pipe isn''t a commandDSL instance.' );
		}
		
		getPiped().append( arguments.commandDSL );
		return this;
	}
	
	/**
	 * Turn this CFC into an array of command tokens
  	 **/
	array function getTokens() {
		var tokens = [];
		// Break the command name on the spaces
		tokens.append( listToArray( getCommand(), ' ' ), true );
		tokens.append( processParams(), true );		
		tokens.append( getFlags(), true );
		
		if( len( getOverwrite() ) ) {
			tokens.append( '>' );
			tokens.append( getOverwrite() );
		}
		
		if( len( getAppend() ) ) {
			tokens.append( '>>' );
			tokens.append( getAppend() );
		}
		
		for( var piperton in getPiped() ) {
			tokens.append( '|' );
			tokens.append( piperton.getTokens(), true );
		}
				
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
	string function run( returnOutput=false, string piped, boolean echo=false ) {
		
		if( arguments.echo ) {
			shell.callCommand( 'echo "#parser.escapeArg( getCommandString() )#"' );
		}
		
		if( structkeyExists( arguments, 'piped' ) ) {
			return shell.callCommand( getTokens(), arguments.returnOutput, arguments.piped );
		} else {
			return shell.callCommand( getTokens(), arguments.returnOutput );
		}		
	}

}