/**
 * Verifies a slug against ForgeBox.
 * .
 * {code:bash}
 * forgebox slugcheck MyApp
 * {code}
 * .
 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	// DI
	property name="forgeBox" inject="ForgeBox";
	
	/**
	* Constructor
	*/
	function init(){
		super.init();
		return this;
	}

	/**
	* @slug.hint The slug to verify in ForgeBox
	*/
	function run( required slug ) {
		
		var exists = forgebox.isSlugAvailable( arguments.slug );

		if( exists ){
			print.greenBoldLine( "The slug '#arguments.slug#' does not exist in ForgeBox and can be used!" );
		} else {
			print.redBoldLine( "The slug '#arguments.slug#' already exists in ForgeBox!" );
		}
		
	}

}