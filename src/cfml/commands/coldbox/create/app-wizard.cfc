/**
*  Create a blank ColdBox app from one of our app skeletons by following our lovely wizard.
**/
component extends="app" aliases="" excludeFromHelp=false {
	
	/**
	 * @name The name of the app you want to create
	 * @skeleton Application Skeleton to use (Advanced,AdvancedScript,Simple,SuperSimple,AdvancedBE,AdvancedScriptBE,SimpleBE,SuperSimpleBE)
	 * @init Would you like to init this as a CommandBox Package
	 * @installColdBox Install the latest stable version of ColdBox from ForgeBox
	 * @installColdBoxBE Install the bleeding edge version of ColdBox from ForgeBox
	 * @installTestBox Install the latest stable version of TestBox from ForgeBox
	 **/
	function run(
		required name,
		required skeleton,
		required boolean init,
		required boolean installColdBox,
		required boolean installColdBoxBE,
		required boolean installTestBox
	) {
		var skeletons = "(Advanced|AdvancedScript|Simple|SuperSimple|AdvancedBE|AdvancedScriptBE|SimpleBE|SuperSimpleBE)";
		// turn off wizard
		arguments.wizard = false;
		arguments.initWizard = true;
		arguments.directory=getCWD();

		// Validate skeletons
		while( !reFindNoCase( skeletons, arguments.skeleton ) ){
			print.boldRedLine( "The skeleton you chose: '#arguments.skeleton#' is not valid." )
				.boldRedLine( " Valid Choices are #replace( skeletons, '|', ',', 'all' )#" )
				.toConsole();
			arguments.skeleton = ask( "Choose Skeleton: " );
		}

		super.run( argumentCollection=arguments );	
	}

}