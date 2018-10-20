/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the gist endpoint
*
* - gist:<gistID>
* - gist:<gistID>#<commit-ish>
* - gist:<githubname>/<gistID>
* - gist:<githubname>/<gistID>#<commit-ish>
*
* If no <commit-ish> is specified, then master is used.
*
*/
component accessors=true implements="IEndpoint" singleton {

	// DI
	property name="consoleLogger"			inject="logbox:logger:console";
	property name="tempDir" 				inject="tempDir@constants";
	property name="folderEndpoint"			inject="commandbox.system.endpoints.Folder";
	property name="progressableDownloader" 	inject="ProgressableDownloader";
	property name="progressBar" 			inject="ProgressBar";
	property name="system" 					inject="system@constants";
	property name="shell" 					inject="shell";
	property name='wirebox'					inject='wirebox';

	// Properties
	property name="namePrefixes" type="string";

	function init() {
		setNamePrefixes( 'gist' );
		return this;
	}

	/**
	* Accepts the name of a package, retrieves it, and returns a local folder path where the package is
	*
	* @throws endpointException
	*/
	public string function resolvePackage( required string package, boolean verbose=false ) {
		var job = wirebox.getInstance( 'interactiveJob' );
		var gistURL = "https://gist.github.com/" & arguments.package;
		var branch = "master";
		/* Check to see if a specific commit is being requested */
		if( gistURL contains '##' ) {
			branch = listLast( gistURL, '##' );
			gistURL = listFirst( gistURL, '##' );
			job.addLog( 'Using commit [#branch#]' );
		}

		job.addLog( 'Cloning Gist [#gistURL#]' );

		// The main Git API
		var Git = createObject( 'java', 'org.eclipse.jgit.api.Git' );

		var progressMonitor = createDynamicProxy(
				wirebox.getInstance( 'JGitProgressMonitor@package-commands' ),
				[ 'org.eclipse.jgit.lib.ProgressMonitor' ]
			);

		// Temporary location to place the repo
		var localPath = createObject( 'java', 'java.io.File' ).init( "#tempDir#/git_#randRange( 1, 1000 )#" );

		// This will trap the full java exceptions to work around this annoying behavior:
		// https://luceeserver.atlassian.net/browse/LDEV-454
		var CommandCaller = createObject( 'java', 'com.ortussolutions.commandbox.jgit.CommandCaller' ).init();

		try {

			// Clone the repo locally into a temp folder
			var cloneCommand = Git.cloneRepository()
				.setURI( gistURL )
				.setCloneSubmodules( true )
				.setDirectory( localPath )
				.setProgressMonitor( progressMonitor );

			// call with our special java wrapper
			local.result = CommandCaller.call( cloneCommand );

			// Checkout branch, tag, or commit hash.
			CommandCaller.call( local.result.checkout().setName( branch ) );

		} catch( any var e ) {
			// Check for Ctrl-C
			shell.checkInterrupted();

			// If the exception came from the Java call, this exception won't be null
			var theRealJavaException = CommandCaller.getException();

			// If it's null, that just means some other CFML code must have blown chunks above.
			if( isNull( theRealJavaException ) ) {
				throw( message="Error Cloning Gist", detail="#e.message#",  type="endpointException");
			} else {
				var deepMessage = '';
				// Start at the top level and work around way down to the root cause.
				do {
					deepMessage &= '#theRealJavaException.toString()# #chr( 10 )#';
					theRealJavaException = theRealJavaException.getCause()
				} while( !isNull( theRealJavaException ) )

				throw( message="Error Cloning Gist", detail="#deepMessage#",  type="endpointException");
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
		var defaultName = listFirst( arguments.package, '##' );

		return reReplaceNoCase( arguments.package, '[^a-zA-Z0-9]', '', 'all' );
	}

	/**
	* Checks to see if there is an update to the package
	* @returns a struct specifying if the currently installed version
	* is outdated as well as the newly available version.
	* The default return struct is this:
	*
	* {
	* 	isOutdated = false,
	* 	version = ''
	* }
	*
	* @throws endpointException
	*/
	public function getUpdate( required string package, required string version, boolean verbose=false ) {

		return {
			isOutdated = true,
			version = 'unknown'
		};
	}

}
