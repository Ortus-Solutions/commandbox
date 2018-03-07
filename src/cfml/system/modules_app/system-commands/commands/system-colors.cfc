/**
 * Outputs the colors CommandBox is capable of printing.  What you see is dependant on your terminal.  
 * Some terminals only support 16 colors, others support all 256.
 * .
 * {code:bash}
 * system-colors
 * {code}
 * .
 **/
component {
	property name='colors256Data'	inject='colors256Data@constants';
	property name='printHelper'		inject='print';
	
	/**
	 * 
	 **/
	function run()  {
		var colorsByID = {};
		colors256Data.each( function( i ) {
			i.colors.each( function( c ) {
				colorsByID[ i.colors[ c ].colorID ] = i.colors[ c ];
			} );
		} );

		var caps = createObject( 'java', 'org.jline.utils.InfoCmp$Capability' );
		var numColors = shell.getReader().getTerminal().getNumericCapability( caps.max_colors );

		if( numColors < 256 ) {
	       	print.line();
			print.redLine( 'Your terminal does not appear to support 256 colors.  Instead it only supports #numColors# colors.' );
			print.redLine( 'The output below will be rounded down to only use #numColors# colors which likely won''t look very good.' );
		} else {
	       	print.line();
			print.boldlimeLine( 'Your terminal supports #numColors# colors.' );			
		}

       	print.line();
		
        var i = -1;
        var c = 0;
        var line = '';
        while( ++i < 256 ) {
        	c++;
        	var color = colorsByID[ i ]; 
            line &= printHelper.text(  printBlock( color.name, color.colorID, ( c < 17 ? 14 : 19 ) ), '#textColor( color.hsl )#onColor#i#' );
            if( c == 16 || c == 8 || ( c > 16 && (c-16) % 6 == 0 ) ) {
               	print.line( line );
               	line = '';
                if( c == 16 || c == 232 ) {
                	print.line();
                }
                
            }
            
        }
        
       	print.line( line );
       	print.line();
	}

	private function printBlock( name, colorID, required number columnWidth ) {
		return name & repeatString( ' ', columnWidth-len( name & colorID ) ) & colorID & ' ';
	}

	private function textColor( hsl ) {
		// Really light colors use black text
		if( hsl.l > 75 ) {
			return 'black';
		// Decently light colors or yellows, unless they're dark blue use black text
		} else if( ( hsl.l > 40 || ( hsl.h >= 45 && hsl.h <= 80 ) ) && !( hsl.h >= 200 && hsl.h <= 299 ) ) {
			return 'black';
		// Everything else uses white text
		} else {
			return 'white';
		}
	}
 	
}
