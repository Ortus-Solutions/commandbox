/**
*  Create a blank ColdBox app from one of our app skeletons by following our lovely wizard.
**/
component extends="app" {

	/**
	 * @name The name of the app you want to create
	 * @skeleton The application skeleton you want to use (Advanced, AdvancedScript, rest, Simple, SuperSimple)
	 * @skeleton.optionsUDF skeletonComplete
	 * @init Would you like to init this as a CommandBox Package
	 * @installColdBox Install the latest stable version of ColdBox from ForgeBox
	 * @installColdBoxBE Install the bleeding edge version of ColdBox from ForgeBox
	 * @installTestBox Install the latest stable version of TestBox from ForgeBox
	 **/
	function run(
		required name,
		required skeleton,
		required boolean init,
		required boolean installTestBox
	) {
		var skeletons = skeletonComplete();
		// turn off wizard
		arguments.wizard 		= false;
		arguments.initWizard 	= true;
		arguments.directory 	= getCWD();

		if( !arguments.skeleton.len() ) {
			// Remove if empty so it can default correctly
			arguments.delete( 'skeleton' );
		}

		super.run( argumentCollection=arguments );
	}

}
