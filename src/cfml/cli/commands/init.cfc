/**
 * Initialize a ColdBox site in the current directory based on the box.json site descriptor.
 * A default box.json will be created if one doesn't exist.
 * 
 * init
 * 
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @force.hint do not prompt, overwrite if exists
	 **/
	function run( Boolean force=false ) {
		var pwd = shell.pwd();
		var boxfile = pwd & "/box.json";
		var ask = "";
		if(!fileExists(boxfile) && force) {
			fileWrite(boxfile,serializeJSON(box.json));
		} if(fileExists(boxfile)) {
			ask &= "over";
		}
		if(!force) {
			var isWrite = shell.ask(ask&"write file #boxfile#? [y/n] : ");
			if(left(isWrite,1) == "y" || isBoolean(isWrite) && isWrite) {
				fileWrite(boxfile,serializeJSON(box.json));
				return "wrote #boxfile#";
			} else {
				return "cancelled";
			}
		} else {
			fileWrite(boxfile,serializeJSON(box.json));
			return "wrote #boxfile#";
		}
	}


	box.json = {
		// packagename
		name : "string",
		// semantic version of your package
		version :"1.0.0.buildID",
		// authorof this package
		author : "Luis Majano <lmajano@mail.com>",
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
		slug : "",
		// ForgeBox short description
		shortDescription : "short description",
		// ForgeBox big description,if not set it looksfor a Readme.md, Readme, Readme.txt
		description : "",
		// Installinstructions, if not set it looks fora instructions.md,instructions,instructions.txt
		instructions : "",
		// Changelog, if not set, itlooks for a changelog.md, changelog orchangelog.txt
		changelog: "",
		// ForgeBox contribution type
		type : "from forgebox available types",
		// ForgeBox keywords, array of strings
		keywords :[ "groovy", "module" ],
		// Bit that if set to true, will not allow ForgeBox posting if usingcommands
		private :"Boolean",
		// cfml engines it supports,type and version
		engines :[
			{ type : "railo", version : ">=4.1.x" },
			{ type : "adobe", version : ">=10.0.0" }
		],
		// defaultengine to use using our run embedded server command
		// Available engines are railo, cf9, cf10, cf11
		defaultEngine : "cf9, railo,cf11",
		// defaultengine port usingour run embedded server command
		defaultPort : 8080,
		// defaultproject URL if notusing our start server commands
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
		// Same asabove, but not installed in production
		DevDependencies : {},
		// array of strings of filesto ignore when installing the package similar to .gitignore pattern spec
		ignore : ["logs*", "readme.md" ],
		// testboxintegration
		testbox :{
		// the urilocation of the test runner for is appor several with slug names
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
				// URL tohit with test report
				URL : ""
			}
		}
	}



}