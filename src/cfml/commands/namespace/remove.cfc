/**
 * Remove a new top-level command namespace
 **/
component  persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @name.hint The name of the command to remove
	 **/
	function run( required string name )  {
		print.redLine( 'Not implemented' );
		
	}

	
}