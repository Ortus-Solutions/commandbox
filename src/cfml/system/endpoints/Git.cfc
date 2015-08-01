/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the Git endpoint.  I get packages from a Git  URL.
* 
* - git+ssh://git@github.com:user/repo.git#v1.0.27
* - git+https://login@github.com/user/repo.git
* - git+http://login@github.com/user/repo.git
* - git+https://login@github.com/user/repo.git
* - git://github.com/user/repom.git#v1.0.27
*
* If no <commit-ish> is specified, then master is used.
*
* Look into supporting this shortcut syntax for GitHub repos
* install mygithubuser/myproject
* install github:mygithubuser/myproject
*
*/
component accessors="true" implements="IEndpoint" singleton {
		
	// DI
	property name="consoleLogger"			inject="logbox:logger:console";
	property name="tempDir" 				inject="tempDir@constants";
	property name="artifactService" 		inject="ArtifactService";
	property name="folderEndpoint"			inject="commandbox.system.endpoints.Folder";
	property name="progressableDownloader" 	inject="ProgressableDownloader";
	property name="progressBar" 			inject="ProgressBar";
	
	// Properties
	property name="namePrefixes" type="string";
	
	function init() {
		setNamePrefixes( 'git' );
		return this;
	}
		
	public string function resolvePackage( required string package, boolean verbose=false ) {
		
		// TODO: Add artifacts caching
		
		var Git = createObject( 'java', 'org.eclipse.jgit.api.Git' );
		
		// Temporary location to place the repo
		var localPath = createObject( 'java', 'java.io.File' ).init( "#tempDir#/git_#randRange( 1, 1000 )#" );
		
		try { 
			// Clone the repo locally into a temp folder
			var local.result = Git.cloneRepository()
			        .setURI( getProtocol() & ':' & arguments.package )
			        .setDirectory( localPath )
			        .call();
		} finally {
			// Release file system locks on the repo
			if( structKeyExists( local, 'result' ) ) {
				result.getRepository().close();
				result.close();
			}
		}
		
		// Defer to file endpoint
		return folderEndpoint.resolvePackage( localPath, arguments.verbose );
		
	}

	/**
	* Determines the name of a package based on its ID if there is no box.json
	*/
	public function getDefaultName( required string package ) {
		// Remove committ-ish
		var baseURL = listFirst( arguments.package, '##' );
		
		// Find last segment of URL (may or may not be a repo name)
		var repoName = listLast( baseURL, '/' );
		
		// Check for the "git" extension in URL
		if( listLast( repoName, '.' ) == 'git' ) {
			return listFirst( repoName, '.' );
		}
		return reReplaceNoCase( arguments.package, '[^a-zA-Z0-9]', '', 'all' );		
	}

	private function getProtocol() {
		var prefix = getNamePrefixes();
		if( listFindNoCase( 'github,git+https', prefix ) ) {
			return "https";
		} else if( prefix == 'git+http' ) {
			return "http";
		} else if( prefix == 'git+ssh' ) {
			return "ssh";
		}
		return prefix;
		
	}

}