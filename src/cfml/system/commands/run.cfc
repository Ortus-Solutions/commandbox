/**
 * Execute an operation system level command
 * .
 * {code}
 * run "C:\Windows\System32\SoundRecorder.exe"
 * {code}
 *
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false{

	/**
	* @name.hint The full pathname of the application to execute including extension
	* @arguments.hint Command-line arguments passed to the application
	* @timeout.hint Indicates how long, in seconds, the executing thread waits for the spawned process. A timeout of 0 is equivalent to the non-blocking mode of executing. Default is 60
	**/
	function run(
		required name,
		args="",
		numeric timeout=60
	){

		var executeResult 	= "";
		var threadName		= "commandbox-runner-#createUUID()#";

		thread name="#threadName#" 
			   command="#arguments.name#" 
			   commandArgs="#arguments.args#"{
			try{
				// execute the server command
				execute name="#attributes.command#" arguments="#attributes.commandArgs#" timeout="60" variable="executeResult";
				// Output Results
				print.cyanLine( executeResult );
			} catch (any e) {
				error( '#e.message##CR##e.detail##CR##e.stackTrace#' );
			}
		}

		// join thread
		thread action="join" name="#threadName#" timeout="#arguments.timeout#"{}

		// end
		print.greenLine( "Command completed succesfully!" );
	}

}