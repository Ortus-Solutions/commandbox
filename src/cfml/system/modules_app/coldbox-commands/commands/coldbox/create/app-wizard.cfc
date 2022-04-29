/**
 *  Create a blank ColdBox app from one of our app skeletons by following our lovely wizard.
 **/
component extends="app" aliases="" {

	/**
	 * @name The name of the app you want to create
	 * @skeleton The application skeleton you want to use (AdvancedScript, rest, rest-hmvc, Simple, SuperSimple)
	 * @init Init this as a package
	 **/
	function run(
		required name,
		skeleton
	){

		arguments.directory  = getCWD();
		if( !confirm( 'Are you currently inside the "/#name#" folder (if "No" we will create it)? [y/n]' ) ) {
			arguments.directory  = getCWD() & name & '/';
			if ( !directoryExists( arguments.directory ) ) {
				directoryCreate( arguments.directory );
			}
			shell.cd(arguments.directory);
		}

		print.boldgreenline( '------------------------------------------------------------------------------------------' );
		print.boldgreenline("Files will be installed in the " & arguments.directory & " directory" );
		print.boldgreenline( '------------------------------------------------------------------------------------------' );

		if( confirm( 'Are you creating an API? [y/n]' ) ) {
			print.boldgreenline( '------------------------------------------------------------------------------------------' );
			print.boldgreenline( 'We have 2 different API template options' );
			print.boldgreenline( 'Both include the modules: cbsecurity, cbvalidation, mementifier, relax, & route-visualizer'  );
			print.boldgreenline( '------------------------------------------------------------------------------------------');

			arguments.skeleton =  multiselect( 'Which template would you like to use?' )
			.options( [
				{accessKey=1,  display='Modular (API/REST) Template - provide an "api" module with a "v1" sub-module within it', value='cbtemplate-rest-hmvc', selected=true },
				{accessKey=2,  display='Simple (API/REST) Template - proivdes api endpoints via the handlers/ folder', value='cbtemplate-rest' },
			] )
			.required()
			.ask();

		} else {
			print.boldgreenline( '------------------------------------------------------------------------------------------',true);
			print.greenline( 'We have a few different Non-API template options' );
			print.greenline( 'No default modules are installed for these templates'   );
			print.boldgreenline( '------------------------------------------------------------------------------------------');

			arguments.skeleton =  multiselect( 'Which template would you like to use?')
			.options( [
				{accessKey=1, value="cbtemplate-simple", display="Simple Script - Script based Coldbox App WITHOUT cfconfig & .env settings"},
				{accessKey=2, value="cbtemplate-advanced-script", display="Advanced Script - Script based Coldbox App which uses cfconfig & .env settings", selected=true},
				{accessKey=3, value="cbtemplate-elixir", display="Elixir Template - Advanced Script + ColdBox Elixir: Enable Webpack tasks for your ColdBox applications"},
				{accessKey=4, value="cbtemplate-elixir-vuejs", display="Elixir + Vuejs Template - Elixir Template + pre-installed & configured VueJS"},
			] )
			.required()
			.ask();

			if(arguments.skeleton != 'cbtemplate-simple'){
				print.boldgreenline( '');
				print.boldgreenline( 'This Coldbox Template uses cfconfig & .env "dotenv" ' );
				print.boldgreenline( '----------------------------------------------------------------------------------------');
				print.boldgreenline( 'CFConfig is a module that creates a local settings file' );
				print.greenline( 'in your project directory of all of the ColdFusion Admin Settings' );
				print.greenline( 'Check out more details in the docs: https://cfconfig.ortusbooks.com/' );
				print.boldgreenline( '----------------------------------------------------------------------------------------');
				print.boldgreenline( '.env is a module that creates a local variables that can be' );
				print.greenline( 'used in many places such as .cfconfig.json, box.json, Coldbox.cfc, etc.' );
				print.greenline( 'You will see these used in the template in some of the files above' );
				print.greenline( 'ex. "${DB_DATABASE}" or getSystemSetting( "APPNAME", "Your app name here" )' );
				print.greenline( 'More info at https://github.com/commandbox-modules/commandbox-dotenv' );
				print.boldgreenline( '----------------------------------------------------------------------------------------');
			}
		}
		print.line('Creating your site...').toConsole();

		var skeletons        = skeletonComplete();
		// turn off wizard
		arguments.wizard     = false;
		arguments.initWizard = true;

		if ( !arguments.skeleton.len() ) {
			// Remove if empty so it can default correctly
			arguments.delete( "skeleton" );
		}

		super.run( argumentCollection = arguments );
	}

}
