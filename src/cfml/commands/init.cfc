/**
 * Initialize a package in the current directory by creating a default box.json file.
 * 
 * init
 * 
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @applicationName.hint The humnan-readable name for this package 
	 * @slug.hint The ForgeBox slug for this package (no spaces or special chars)
	 * @directory.hint The location to initialize the project.  Defaults to the current working directory.
	 * @force.hint Do not prompt, overwrite if exists
	 **/
	function run( packagename='myApplication', slug='mySlug', directory='', Boolean force=false ) {
		if( !len( directory ) ) {
			directory = shell.pwd();
		}
		
		// Validate directory
		if( !directoryExists( directory ) ) {
			print.redLine( 'Directory #directory# does not exist.' );
			return;
		}
		
		// TODO: Get author info from default CommandBox config
		
		// Read the default JSON file.  
		// TODO: Externalize the default file and read it in
		var boxJSON = variables.boxJSON;
		// Replace things passed via parameters
		boxJSON = replaceNoCase( boxJSON, '@@packageName@@', packagename );
		boxJSON = replaceNoCase( boxJSON, '@@slug@@', slug );
		
		// Clean up directory
		if( listFind( '\,/', right( directory, 1 ) ) ) {
			directory = mid( directory, 1, len( directory )-1  );
		}
		
		// This is where we will write the box.json file
		var boxfile = directory & "/box.json";
	
		// If the file doesn't exist, or we are forcing, just do it!
		if( !fileExists( boxfile ) || force ) {
			fileWrite( boxfile, boxJSON );
			
			print.greenLine( 'Package Initialized!' );
			print.line( boxfile );
			
		// File exists, better check first
		} else {
			// Ask the user what they want to do
			var isWrite = ask( '#boxfile# already exists, overwrite? [y/n] : ');
			// If they responsed with 'y' or some other boolean true, then do it.
			if( left( isWrite, 1 ) == 'y' 
					|| ( isBoolean( isWrite ) && isWrite ) ) {
				fileWrite( boxfile, boxJSON );
				
				print.greenLine( 'Package Initialized!' );
				print.line( boxfile );
			} else {
				print.redLine( 'cancelled' );		
			}
			
		}
		
	}

	variables.boxJSON = '
	{
		// packagename
		name : "@@packageName@@",
		// semantic version of your package
		version :"1.0.0.buildID",
		// author of this package
		author : "Your Name <your.email@mail.com>",
		// location of where to download the package, overrides ForgeBox location
		location :"URL,Git/svn endpoint,etc",
		// installdirectory where this package should beplaced once installed, if not
		// definedit then installs it in the root /
		directory: "/modules",
		// projecthomepage URL
		Homepage :"URL",
		// documentation URL
		Documentation : "URL",
		// sourcerepository, valid keys: type, URL
		Repository: { type:"git,svn,mercurial", URL:"" },
		// bug issue management URL
		Bugs : "URL",
		// ForgeBox unique slug
		slug : "@@slug@@",
		// ForgeBox short description
		shortDescription : "short description",
		// ForgeBox big description,if not set it looksfor a Readme.md, Readme, or Readme.txt
		description : "",
		// Installinstructions, if not set it looks for a instructions.md, instructions, or instructions.txt
		instructions : "",
		// Changelog, if not set, it looks for a changelog.md, changelog, or changelog.txt
		changelog: "",
		// ForgeBox contribution type
		type : "from forgebox available types",
		// ForgeBox keywords, array of strings
		keywords :[ "groovy", "module" ],
		// Bit that if set to true, will not allow ForgeBox posting if using commands
		private :"Boolean",
		// cfml engines it supports,type and version
		engines :[
			{ type : "railo", version : ">=4.1.x" },
			{ type : "adobe", version : ">=10.0.0" }
		],
		// defaultengine to use using our run embedded server command
		// Available engines are railo, cf9, cf10, cf11
		defaultEngine : "cf9, railo, cf11",
		// defaultengine port usingour run embedded server command
		defaultPort : 8080,
		// defaultproject URL if not using our start server commands
		ProjectURL: "http://railopresso.local/myApp",
		// licensearray of licensesit can have
		License :[
			{ type:"MIT", URL: "" }
		],
		// contributors array of strings or structs: name,email,url
		Contributors : [ "Luis Majano", "Luis Majano <lmajano@mail.com>", {name="luis majano",email="",url=""} ],
		// dependencies, a shortcut for latest version isto use the * string
		Dependencies : {
			"coldbox": "x", // latest version from ForgeBox
			"Name" : "version", // a specific version from ForgeBox
			"Name" : "local filepath", //disallowed from forgebox registration
			"Name" : "URL",
			"Name" : "Git/svn endpoint"
		},
		// only needed on development
		// Same as above, but not installed in production
		DevDependencies : {},
		// array of strings of filesto ignore when installing the package similar to .gitignore pattern spec
		ignore : ["logs*", "readme.md" ],
		// testboxintegration
		testbox :{
		// The uri location of the test runners with slug names
			runner : [
				{ "cf9": "http://cf9cboxdev.jfetmac/coldbox/testing/runner.cfm"},
				{ "railo": "http://railocboxdev.jfetmac/coldbox/testing/runner.cfm"}
			],
			Labels : [],
			Reporter :"",
			ReporterResults : "/test/results",
			Bundles :[ "test.specs" ],
			Directory: { mapping : "test.specs", recurse: true },
			// directories or files to watch for changes, ifthey change, then tests execute
			Watchers :[ "/model" ] ,
			// after tests run we can doa notification report summary
			Notify : {
				Emails : [],
				Growl : "address",
				// URL to hit with test report
				URL : ""
			}
		}
	}

	';

}