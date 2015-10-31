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
* Also supports this shortcut syntax for GitHub repos
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
	property name="system" 					inject="system@constants";
	
	
	// Properties
	property name="namePrefixes" type="string";
	
	function init() {
		setNamePrefixes( 'git' );
		return this;
	}
		
	public string function resolvePackage( required string package, boolean verbose=false ) {
		
		var GitURL = replace( arguments.package, '//', '' );
		GitURL = getProtocol() & GitURL;
		var branch = 'master';
		if( GitURL contains '##' ) {
			branch = listLast( GitURL, '##' );
			GitURL = listFirst( GitURL, '##' );
			consoleLogger.debug( 'Using branch [#branch#]' );
		}

		consoleLogger.debug( 'Cloning Git URL [#GitURL#]' );
		
		// The main Git API
		var Git = createObject( 'java', 'org.eclipse.jgit.api.Git' );
		
		// Wrap up system out in a PrintWriter and create a progress monitor to track our clone
		var printWriter = createObject( 'java', 'java.io.PrintWriter' ).init( system.out, true );
		var progressMonitor = createObject( 'java', 'org.eclipse.jgit.lib.TextProgressMonitor' ).init( printWriter );
		
		// Temporary location to place the repo
		var localPath = createObject( 'java', 'java.io.File' ).init( "#tempDir#/git_#randRange( 1, 1000 )#" );
				
		try { 
			// Clone the repo locally into a temp folder
			var cloneCommand = Git.cloneRepository()
				.setURI( GitURL )			        
				.setBranch( branch )
				.setCloneSubmodules( true )
				.setDirectory( localPath )
				.setProgressMonitor( progressMonitor );
		        
			// Conditionally apply security
			local.result = secureCloneCommand( cloneCommand )
		        .call();
		        
		} catch( any var e ) {
			throw( message="Error Cloning Git repository", detail="#e.message#",  type="endpointException"); 
		} finally {
			// Release file system locks on the repo
			if( structKeyExists( local, 'result' ) ) {
				result.getRepository().close();
				result.close();
			}
		}
		
		// Defer to file endpoint
		return folderEndpoint.resolvePackage( localPath.getPath(), arguments.verbose );
		
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
		if( listFindNoCase( 'github,git+https,git', prefix ) ) {
			return "https://";
		} else if( prefix == 'git+http' ) {
			return "http://";
		} else if( prefix == 'git+ssh' ) {
			return "";
		}
		return prefix & '://';
		
	}

	public function getUpdate( required string package, required string version, boolean verbose=false ) {
		var result = {
			isOutdated = true,
			version = 'unknown'
		};
		
		return result;
	}

	// Default is no auth
	private function secureCloneCommand( required any cloneCommand ) {
		return cloneCommand;
	}

}