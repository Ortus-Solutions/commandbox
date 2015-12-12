/**
 * Remvoe a task
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/** 
	 * @name.hint The Task name
	 **/
	function run( required String name ) {
		print.line( "faux-remove! Task:#name#" );
	}

}