/**
 * display file contents
 **/
component persistent="false" extends="cli.BaseCommand" aliases="type" {

	/**
	 * @file.hint file to view contents of
 	 **/
	function run(file="")  {
		if(left(file,1) != "/"){
			file = shell.pwd() & "/" & file;
		}
		return fileRead(file);
	}

}