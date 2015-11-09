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
 * Additional endpoints include HTTP/HTTPS, local zip file or folder, Git repos, CFlib.org, and RIAForge.org
 * .
 * {code:bash}
 * install C:/myZippedPackages/package.zip
 * install C:/myUnzippedPackages/package/
 * install http://site.com/package.zip
 * install git://site.com/user/repo.git
 * install git+https://site.com/user/repo.git
 * install git+ssh://site.com:user/repo.git
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
 * UDFs from CFLib.org can be installed via the cflib endpoint.  Install UDFs into a ColdBox app with the cflib-coldbox endpoint.
 * .
 * {code:bash}
 * install cflib:AreaParallelogram
 * install cflib-coldbox:AreaParallelogram
 * {code}
 * .
 * Projects from RIAForge.org can be installed via the riaforge endpoint.
 * .
 * {code:bash}
 * install riaforge:iwantmylastfm
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="install" excludeFromHelp=false {
	
	/**
	* The ForgeBox entries cache
	*/
	property name="entries";

	// DI
	property name="forgeBox" 		inject="ForgeBox";
	property name="packageService" 	inject="PackageService";
			
	/**
	* @ID.hint "endpoint:package" to install. Default endpoint is "forgebox".  If no ID is passed, all dependencies in box.json will be installed.
	* @ID.optionsUDF IDComplete
	* @directory.hint The directory to install in and creates the directory if it does not exist. This will override the packages's box.json install dir if provided. 
	* @save.hint Save the installed package as a dependancy in box.json (if it exists), defaults to true
	* @saveDev.hint Save the installed package as a dev dependancy in box.json (if it exists)
	* @production.hint When calling this command with no ID to install all dependencies, set this to true to ignore devDependencies.
	* @verbose.hint If set, it will produce much more verbose information about the package installation
	* @force.hint When set to true, it will force dependencies to be installed whether they already exist or not
	**/
	function run( 
		string ID='',
		string directory,
		boolean save=true,
		boolean saveDev=false,
		boolean production=false,
		boolean verbose=false,
		boolean force=false
	){
		
		// Don't default the dir param since we need to differentiate whether the user actually 
		// specifically typed in a param or not since it overrides the package's box.json install dir.
		if( structKeyExists( arguments, 'directory' ) ) {
			
			arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
			
			// Validate directory
			if( !directoryExists( arguments.directory ) ) {
				directoryCreate( arguments.directory );
			}
			
		}
				
		// TODO: climb tree to find root of the site by searching for box.json
		arguments.currentWorkingDirectory = getCWD();
		// Make ID an array
		arguments.IDArray = listToArray( arguments.ID );


		// Install this package(s).
		// Don't pass directory unless you intend to override the box.json of the package being installed
		
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
				
	}

	// Auto-complete list of IDs
	function IDComplete() {
		var result = [];
		// Cache in command
		if( !structKeyExists( variables, 'entries' ) ) {
			variables.entries = forgebox.getEntries();			
		}
		
		// Loop over results and append all active ForgeBox entries
		for( var entry in variables.entries ) {
			if( val( entry.isactive ) ) {
				result.append( entry.slug );
			}
		}
		
		return result;
	}

} 