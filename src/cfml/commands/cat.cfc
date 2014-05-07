/**
 * This command will read a file and display its contents to the console
 * 
 * cat box.json
 * 
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="type" excludeFromHelp=false {

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