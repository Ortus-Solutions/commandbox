/**
 * Returns shell version
 **/
component extends="commandbox.system.BaseCommand" aliases="ver" excludeFromHelp=false {

	function run()  {
		print.line( 'CommandBox #shell.getVersion()#' );
	}

}