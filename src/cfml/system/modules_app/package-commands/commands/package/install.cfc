/**
 * Download and install an entry from an endpoint (like ForgeBox) into your application or read the box.json descriptor
 * and install all production/development dependencies in your project if no ID is passed.
 * .
 * Install the feeds package from ForgeBox and save as a dependency
 * {code:bash}
 * install feeds
 * {code}
 * .
 * Override the installation location by passing the "directory" parameter.
 * {code:bash}
 * install coldbox ../lib/frameworks/
 * {code}
 * .
 * Install "feeds" and does not save as a dependency
 * {code:bash}
 * install feeds --!save
 * {code}
 * .
 * Install cbdebugger and save as a devDependency
 * {code:bash}
 * install cbdebugger --saveDev
 * {code}
 * .
 * This command can also be called with no ID.  In that instance, it will search for a box.json in the current working
 * directory and install all the dependencies.
 * {code:bash}
 * install
 * {code}
 * .
 * The "production" argument is used in order to determine if we should install development dependencies or not.
 * By default "production" is false, so all development dependencies will be installed.
 * {code:bash}
 * install --production
 * {code}
 * .
 * You can also specify the version of a package you want to install from Forgebox. Note, this only
 * currently works if the specified version of the package is in your local artifacts folder.
 * {code:bash}
 * install coldbox@3.8.1
 * {code}
 * .
 * Installation from endpoints other than ForgeBox is supported.
 * Additional endpoints include HTTP/HTTPS, local zip file or folder, Git repos, GitHub Gists, CFlib.org, and RIAForge.org
 * .
 * {code:bash}
 * install C:/myZippedPackages/package.zip
 * install C:/myUnzippedPackages/package/
 * install http://site.com/package.zip
 * install git://site.com/user/repo.git
 * install git+https://site.com/user/repo.git
 * install git+ssh://site.com:user/repo.git
 * install git+ssh://git@github.com:user/repo.git
 * {code}
 * .
 * The git+ssh endpoint will look for a private SSH key in your ~/.ssh directory named "id_rsa", "id_dsa", or "identity".
 * That matching public key needs to be registered in the Git server.
 * .
 * Git repos are cloned and the "master" branch used by default.
 * You can also use a committ-ish to target a branch, tag, or commit
 * .
 * {code:bash}
 * install git://site.com/user/repo.git#development
 * install git://site.com/user/repo.git#v2.1.0
 * install git://site.com/user/repo.git#09d302b4fffa0b988d1edd8ea747dc0c0f2883ea
 * {code}
 * .
 * A shortcut notation is also supported for GitHub repos specifically where you can only specify the GitHub user and repo name
 * .
 * {code:bash}
 * install mygithubuser/myproject
 * {code}
 * .
 * The Gist endpoint will install a package from gist.github.com. The username is optional but the gist ID is required.
 * You can also use a commit-ish to target a specific commit.
 * .
 * {code:bash}
 * install gist:b6cfe92a08c742bab78dd15fc2c1b2bb
 * install gist:b6cfe92a08c742bab78dd15fc2c1b2bb#37348a126f1f410120785be0d84ad7a2148c3e9f
 * {code}
 * .
 * UDFs from CFLib.org can be installed via the cflib endpoint.  Install UDFs into a ColdBox app with the cflib-coldbox endpoint.
 * .
 * {code:bash}
 * install cflib:AreaParallelogram
 * install cflib-coldbox:AreaParallelogram
 * {code}
 **/
component aliases="install" {

	/**
	* The ForgeBox entries cache
	*/
	property name="entries";

	// DI
	property name="packageService"	inject="PackageService";
	property name="endpointService"	inject="endpointService";
	property name='interceptorService'	inject='interceptorService';

	/**
	* @ID.hint "endpoint:package" to install. Default endpoint is "forgebox".  If no ID is passed, all dependencies in box.json will be installed.
	* @ID.optionsUDF IDComplete
	* @ID.optionsFileComplete true
	* @ID.optionsDirectoryComplete true
	* @directory.hint The directory to install in and creates the directory if it does not exist. This will override the packages box.json install dir if provided.
	* @save.hint Save the installed package as a dependency in box.json (if it exists), defaults to true
	* @saveDev.hint Save the installed package as a dev dependency in box.json (if it exists)
	* @production.hint Ignore devDependencies when called with no ID to install all dependencies
	* @verbose.hint Output much more verbose information about the package installation
	* @force.hint Force dependencies to be installed whether they already exist or not
	* @system.hint Install this package into the global CommandBox module's folder
	**/
	function run(
		string ID='',
		string directory,
		boolean save=true,
		boolean saveDev=false,
		boolean production,
		boolean verbose=false,
		boolean force=false,
		boolean system=false
	){

		// Don't default the dir param since we need to differentiate whether the user actually
		// specifically typed in a param or not since it overrides the package's box.json install dir.
		if( structKeyExists( arguments, 'directory' ) ) {

			arguments.directory = resolvePath( arguments.directory );

			// Validate directory
			if( !directoryExists( arguments.directory ) ) {
				directoryCreate( arguments.directory );
			}

		}


		if( arguments.system ) {
			arguments.currentWorkingDirectory = expandPath( '/commandbox' );
		} else {
			arguments.currentWorkingDirectory = getCWD();
		}
		// Make ID an array
		arguments.IDArray = listToArray( arguments.ID );


		// Install this package(s).
		// Don't pass directory unless you intend to override the box.json of the package being installed

		interceptorService.announceInterception( 'preInstallAll', { installArgs=arguments } );

		try {

			// One or more IDs
			if( arguments.IDArray.len() ) {
				for( var thisID in arguments.IDArray ){
					arguments.ID = thisID;
					packageService.installPackage( argumentCollection = arguments );
				}
			// No ID, just install the dependencies in box.json
			} else {
				arguments.ID = '';
				packageService.installPackage( argumentCollection = arguments );
			}

		// endpointException exception type is used when the endpoint has an issue that needs displayed,
		// but I don't want to "blow up" the console with a full error.
		} catch( endpointException var e ) {
			error( e.message, e.detail );
		} catch( EndpointNotFound var e ) {
			error( e.message, e.detail );
		}


		interceptorService.announceInterception( 'postInstallAll', { installArgs=arguments } );

	}

	// Auto-complete list of IDs
	function IDComplete( string paramSoFar ) {
		// Only hit forgebox if they've typed something.
		if( !len( trim( arguments.paramSoFar ) ) ) {
			return [];
		}
		try {


			var endpointName = configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );

			try {
				var oEndpoint = endpointService.getEndpoint( endpointName );
			} catch( EndpointNotFound var e ) {
				error( e.message, e.detail ?: '' );
			}

			var forgebox = oEndpoint.getForgebox();
			var APIToken = oEndpoint.getAPIToken();

			// Get auto-complete options
			return forgebox.slugSearch( searchTerm=arguments.paramSoFar, APIToken=APIToken );
		} catch( forgebox var e ) {
			// Gracefully handle ForgeBox issues
			print
				.line()
				.yellowLine( e.message & chr( 10 ) & e.detail )
				.toConsole();
			// After outputting the message above on a new line, but the user back where they started.
			getShell().getReader().redrawLine();
		}
		// In case of error, break glass.
		return [];
	}

}
