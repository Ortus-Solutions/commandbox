component {

	this.name="cli";
	this.sessionmanagement="false";

	this.mappings[ '/cfml' ] = getDirectoryFromPath(getMetadata(this).path);
	this.mappings[ '/cli' ] = this.mappings[ '/cfml' ] & '/cli';

}