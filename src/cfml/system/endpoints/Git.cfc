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
	property name="shell" 					inject="shell";
	property name='wirebox'					inject='wirebox';

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'git' );
		return this;
	}

	public string function resolvePackage( required string package, boolean verbose=false ) {
		var job = wirebox.getInstance( 'interactiveJob' );
		var GitURL = replace( arguments.package, '//', '' );
		GitURL = getProtocol() & GitURL;
		var branch = 'master';
		if( GitURL contains '##' ) {
			branch = listLast( GitURL, '##' );
			GitURL = listFirst( GitURL, '##' );
			job.addLog( 'Using branch [#branch#]' );
		}

		job.addLog( 'Cloning Git URL [#GitURL#]' );

		// The main Git API
		var Git = createObject( 'java', 'org.eclipse.jgit.api.Git' );

		// Wrap up system out in a PrintWriter and create a progress monitor to track our clone
		var printWriter = shell.getReader().getTerminal().writer();
		var progressMonitor = createObject( 'java', 'org.eclipse.jgit.lib.TextProgressMonitor' ).init( printWriter );

		// Temporary location to place the repo
		var localPath = createObject( 'java', 'java.io.File' ).init( "#tempDir#/git_#randRange( 1, 1000 )#" );

		// This will trap the full java exceptions to work around this annoying behavior:
		// https://luceeserver.atlassian.net/browse/LDEV-454
		var CommandCaller = createObject( 'java', 'com.ortussolutions.commandbox.jgit.CommandCaller' ).init();

		try {
			job.clear();
			
			// Clone the repo locally into a temp folder
			var cloneCommand = Git.cloneRepository()
				.setURI( GitURL )
				.setCloneSubmodules( true )
				.setDirectory( localPath )
				.setProgressMonitor( progressMonitor );

			// Conditionally apply security
			var command = secureCloneCommand( cloneCommand );
		    // call with our special java wrapper
			local.result = CommandCaller.call( command );

			job.draw();
			
			// Get a list of all branches
			var branchListCommand = local.result.branchList();
			var listModeAll = createObject( 'java', 'org.eclipse.jgit.api.ListBranchCommand$ListMode' ).ALL;
			var branchList = [].append( CommandCaller.call( branchListCommand.setListMode( listModeAll ) ), true );
			branchList = branchList.map( function( ref ){ return ref.getName(); } );

	    	if( arguments.verbose ){ job.addLog( 'Available branches are #branchList.toList()#' ); }

	    	// If the commit-ish looks like it's a branch, modify the ref's name.
		    if( branchList.containsNoCase( branch ) ) {
		    	if( arguments.verbose ){ job.addLog( 'Commit-ish [#branch#] appears to be a branch.' ); }
		    	branch = 'origin/' & branch;
		    }

		    // Checkout branch, tag, or commit hash.
	        CommandCaller.call( local.result.checkout().setName( branch ) );
	        
		} catch( any var e ) {
			// Check for Ctrl-C
			shell.checkInterrupted();
			
			// If the exception came from the Java call, this exception won't be null
			var theRealJavaException = CommandCaller.getException();

			// If it's null, that just means some other CFML code must have blown chunks above.
			if( isNull( theRealJavaException ) ) {
				throw( message="Error Cloning Git repository", detail="#e.message#",  type="endpointException");
			} else {
				var deepMessage = '';
				// Start at the top level and work around way down to the root cause.
				do {
					deepMessage &= '#theRealJavaException.toString()# #chr( 10 )#';
					theRealJavaException = theRealJavaException.getCause()
				} while( !isNull( theRealJavaException ) )

				throw( message="Error Cloning Git repository", detail="#deepMessage#",  type="endpointException");
			}

		} finally {
			// Release file system locks on the repo
			if( structKeyExists( local, 'result' ) ) {
				result.getRepository().close();
			}
		}

		// Clean up a bit
		var gitFolder = localPath.getPath() & '/.git';
		if( directoryExists( gitFolder ) ) {
			directoryDelete( gitFolder, true );
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
			// Repo URLs with a semver in the name are considered to not have an update since we assume they are an exact version
			isOutdated = !package
				.listRest( '##' )
				.reFindNoCase( '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' ),
			version = 'unknown'
		};

		return result;
	}

	// Default is no auth
	private function secureCloneCommand( required any cloneCommand ) {
		return cloneCommand;
	}

}
