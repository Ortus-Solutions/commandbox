/**
 * This command will read any number of files and return their concatenated contents.  By default, the 
 * the output is displayed on the console, but it can also be piped into other commands.
 * 
 * cat box.json myFile.txt
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="type" excludeFromHelp=false {

	/**
	 * You can have as many args as you want, but I'm including 4 just so 
	 * auto-complete will at least work for the first 4 since it's based on arg name.
	 * 
	 * @file1.hint File to output
	 * @file2.hint File to concatenate to previous file
	 * @file3.hint File to concatenate to previous file(s)
	 * @file4.hint File to concatenate to previous file(s)
 	 **/
	function run( required file1, file2, file3, file4 )  {
		
		var buffer = '';
		
		for( var arg in arguments ) {
			var file = arguments[ arg ];
			
			if( !isNull( file ) ) {
				
				// Make file canonical and absolute
				file = fileSystemUtil.resolvePath( file );
				
				if( !fileExists( file ) ){
					return error( "File: #file# does not exist!" );
				}
					
				buffer &= fileRead( file );
				
			}
			
			
		}
		

		return buffer;
	}

}