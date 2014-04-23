/**
 * build utility
 **/
component output="false" persistent="false" trigger="" {

	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
		thisdir = getDirectoryFromPath(getMetadata(this).path);
		home = thisdir & "/home";
		return this;
	}

	/**
	 * download and install cfdistro
	 **/
	function install(String version="latest")  {
		http url="http://cfmlprojects.org/artifacts/cfdistro/latest/cfdistro.zip" file="#thisdir#/cfdistro.zip";
		zip action="unzip" file="#thisdir#/cfdistro.zip" destination="#home#";
		return "installed";
	}

	/**
	 * Generate war
	 * ex: war destination=/directory/to/store/in
	 **/
	function war(String destination="")  {
		return "generating war";
	}

	/**
	 * Get dependency
	 **/
	function dependency(required artifactId, required groupId, required version, mapping, exclusions="")  {
	}

}