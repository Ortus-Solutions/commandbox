/**
* CommandBox CLI
* Copyright since 2012 by Ortus Solutions, Corp
* www.ortussolutions.com/products/commandbox
* ---
* Application Bootstrap
*/
component{

	this.name 				= "CommandBox-APIDocs" & hash(getCurrentTemplatePath());
	this.sessionManagement 	= true;
	this.sessionTimeout 	= createTimeSpan(0,0,1,0);
	this.setClientCookies 	= true;

	// mappings
	API_ROOT = getDirectoryFromPath( getCurrentTemplatePath() );
	this.mappings[ "/docbox" ] = API_ROOT & "/docbox";

	rootPath = REReplaceNoCase( API_ROOT, "apidocs(\\|\/)$", "" );
	this.mappings[ "/root" ]		= rootPath;
	this.mappings[ "/commandbox" ] 	= rootPath & "src/cfml";
	this.mappings[ '/wirebox' ] 	= rootPath & "src/cfml/system/wirebox";

	// request start
	public boolean function onRequestStart( String targetPage ){
		return true;
	}

}