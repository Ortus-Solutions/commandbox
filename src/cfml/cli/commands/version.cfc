/**
 * Returns shell version
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" excludeFromHelp=false {

	function run()  {
		print.line( 'CommandBox #shell.version()#' );
	}

}