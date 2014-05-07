/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
* Main Application Bootstrap
*/
component{

	this.name = "CommandBox CLI";
	this.sessionmanagement = "false";

	// Move everything over to this mapping which is the "root" of our app
	this.mappings[ '/commandbox' ] = getDirectoryFromPath( getMetadata( this ).path );
	
	// Deprecate these mappings in favor of the top one.
	//this.mappings[ '/cfml' ] = getDirectoryFromPath( getMetadata( this ).path );
	//this.mappings[ '/cli' ]  = this.mappings[ '/cfml' ] & '/cli';

}