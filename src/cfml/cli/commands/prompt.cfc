/**
 * Set prompt
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" {

	function run(String prompt="")  {
		shell.setPrompt(prompt);
	}

}