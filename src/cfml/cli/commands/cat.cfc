/**
 * This command will read a file and display its contents to the console
 * 
 * cat box.json
 * 
 **/
component persistent="false" extends="cli.BaseCommand" aliases="type" {

	/**
	 * @file.hint File to view contents of
 	 **/
	function run(file="")  {
		if(left(file,1) != "/"){
			file = shell.pwd() & "/" & file;
		}
		return fileRead(file);
	}

}