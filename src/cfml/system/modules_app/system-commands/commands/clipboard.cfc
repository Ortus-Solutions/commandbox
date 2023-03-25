/**
 * Stores text inputted into OS clipboard.
 * .
 * {code:bash}
 * echo "Hello World!" | clipboard
 * {code}
 * .
 * Output the text and copy it to the clipboard with the --echo flag
 * .
 * {code:bash}
 * ls --tree | clipboard --echo
 * {code}
  **/
component {

	/**
	 * @text The text to store on clipboard
	 * @echo Echo text out to console as well
	 **/
	function run( String text="", Boolean echo=false )  {
		if( FileSystemUtil.isWindows() ) {
			var binary = 'clip';
		} else if( FileSystemUtil.isMac() ) {
			var binary = 'pbcopy';
		} else if( FileSystemUtil.isLinux() ) {
			try {
				var whichXclip = command( '!which xclip' ).run( returnOutput=true );
			} catch( any e ) {
				var whichXclip = '';
			}
			if( len( trim( whichXclip ) ) ) {
				var binary = 'xclip';
			} else {
				error( 'xclip binary not installed for Linux.  Please install xclip and try again.' );
			}
		} else {
			error( 'Unsupported OS for "clipboard" [#getSystemSetting( 'os.name' )#]' );
		}
		command( '!' & binary )
			.run( piped=print.unansi( text ) );

		if( echo ) {
			print.text( text );
		} else {
			print.greenLine( 'Copied to clipboard!' );
		}
	}

}
