/**
 * Returns shell version
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	function run()  {
		print.line( 'CommandBox #shell.getVersion()#' );
	}

}