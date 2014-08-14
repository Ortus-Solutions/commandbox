component{

	this.name = "CommandBox-APIDocs" & hash(getCurrentTemplatePath());
	this.sessionManagement = true;
	this.sessionTimeout = createTimeSpan(0,0,1,0);
	this.setClientCookies 	= true;

	// mappings
	API_ROOT = getDirectoryFromPath( getCurrentTemplatePath() );
	this.mappings[ "/colddoc" ] = API_ROOT;

	rootPath = REReplaceNoCase( this.mappings[ "/colddoc" ], "apidocs(\\|\/)$", "" );
	this.mappings[ "/root" ]		= rootPath;
	this.mappings[ "/commandbox" ] 	= rootPath & "src/cfml";
	this.mappings[ '/wirebox' ] 	= rootPath & "src/cfml/system/wirebox";

	// request start
	public boolean function onRequestStart( String targetPage ){
		return true;
	}

}