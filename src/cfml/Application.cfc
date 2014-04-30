component {
	
	this.name="cli";
	this.sessionmanagement="false";
	
	// Set the cfml directory as the root
	this.mappings[ '/' ] = getDirectoryFromPath( getCurrentTemplatePath() );
	
}