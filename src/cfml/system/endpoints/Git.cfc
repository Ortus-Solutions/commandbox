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
	property name="semanticVersion"			inject="provider:semanticVersion@semver";
	property name='semverRegex'				inject='semverRegex@constants';
	property name='configService'			inject='configService';

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'git' );
		return this;
	}

	public string function resolvePackage( required string package, string currentWorkingDirectory="", boolean verbose=false ) {

		if( configService.getSetting( 'offlineMode', false ) ) {
			throw( 'Can''t clone [#getNamePrefixes()#:#package#], CommandBox is in offline mode.  Go online with [config set offlineMode=false].', 'endpointException' );
		}

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

		var progressMonitor = createDynamicProxy(
				wirebox.getInstance( 'JGitProgressMonitor@package-commands' ),
				[ 'org.eclipse.jgit.lib.ProgressMonitor' ]
			);

		// Temporary location to place the repo
		var localPath = createObject( 'java', 'java.io.File' ).init( "#tempDir#/git_#createUUID()#" );

		try {

			// Clone the repo locally into a temp folder
			var cloneCommand = Git.cloneRepository()
				.setURI( GitURL )
				.setCloneSubmodules( true )
				.setDirectory( localPath )
				.setProgressMonitor( progressMonitor );

			// Conditionally apply security
			var command = secureCloneCommand( cloneCommand, GitURL );
			local.result = command.call();

			// Get a list of all branches
			var branchListCommand = local.result.branchList();
			var listModeAll = createObject( 'java', 'org.eclipse.jgit.api.ListBranchCommand$ListMode' ).ALL;
			var branchList = [].append( branchListCommand.setListMode( listModeAll ).call(), true );
			branchList = branchList.map( function( ref ){ return ref.getName(); } );

			if( arguments.verbose ){ job.addLog( 'Available branches are #branchList.toList()#' ); }

			// If the commit-ish looks like it's a branch, modify the ref's name.
			if( branchList.filter( function( i ) { return i contains branch; } ).len() ) {
				if( arguments.verbose ){ job.addLog( 'Commit-ish [#branch#] appears to be a branch.' ); }
				branch = 'origin/' & branch;
			} else if( branch == 'master' && branchList.filter( (b)=>b contains 'main' ).len() ) {
				if( arguments.verbose ){ job.addLog( 'Switching to branch [main].' ); }
				branch = 'origin/main';
			}

			// Checkout branch, tag, or commit hash.
			local.result.checkout().setName( branch ).call();

		} catch( any var e ) {
			// Check for Ctrl-C
			shell.checkInterrupted();

			// BoxLang surfaces the underlying Java Throwable in e.cause, so walk down the
			// cause chain to the root cause to build a useful error message. This replaces
			// the CommandCaller Java wrapper that worked around LDEV-454 on Lucee.
			var deepMessage = structKeyExists( e, 'message' ) ? e.message : 'Unknown error';
			var currentCause = structKeyExists( e, 'cause' ) ? e.cause : '';

			while( !isNull( currentCause ) && isObject( currentCause ) ) {
				deepMessage &= chr( 10 ) & currentCause.toString();
				currentCause = currentCause.getCause();
			}

			throw( message="Error cloning #getNamePrefixes()# repository", detail="#deepMessage#", type="endpointException" );

		} finally {
			// Release file system locks on the repo
			if( structKeyExists( local, 'result' ) ) {
				result.getRepository().close();
				// Force JGit's WindowCache to release memory-mapped pack files (Windows file locking issue)
				var WindowCache = createObject( 'java', 'org.eclipse.jgit.internal.storage.file.WindowCache' );
				var WindowCacheConfig = createObject( 'java', 'org.eclipse.jgit.storage.file.WindowCacheConfig' );
				WindowCache.reconfigure( WindowCacheConfig.init() );
			}
		}

		// Clean up .git folder using JGit's FileUtils which has Windows file locking retry logic
		var gitFolder = localPath.getPath() & '/.git';
		if( directoryExists( gitFolder ) ) {
			var JGitFileUtils = createObject( 'java', 'org.eclipse.jgit.util.FileUtils' );
			var RECURSIVE = JGitFileUtils.RECURSIVE;
			var RETRY = JGitFileUtils.RETRY;
			JGitFileUtils.delete(
				createObject( 'java', 'java.io.File' ).init( gitFolder ),
				bitOr( RECURSIVE, RETRY )
			);
		}

		// Defer to file endpoint
		return folderEndpoint.resolvePackage( localPath.getPath(), currentWorkingDirectory, arguments.verbose );

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
		// Check to see if commit-ish semver exists and if so use that
		var versionMatch = reMatch( semverRegex, package.listRest( '##' ) );

		if ( versionMatch.len() ) {
			return {
				isOutdated: semanticVersion.isNew( current=arguments.version, target=versionMatch.last() ),
				version: versionMatch.last()
			};
		}

		// Did not find a version in the commit-ish so assume package is outdated
		return {
			isOutdated: true,
			version: 'unknown'
		};
	}

	// Default is no auth
	private function secureCloneCommand( required any cloneCommand ) {
		return cloneCommand;
	}

}
