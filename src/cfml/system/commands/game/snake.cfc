/**
* This is am experiment with interactive ANSI stuff
**/
component extends="commandbox.system.BaseCommand" aliases="snake" excludeFromHelp=true {

	property name='p' inject='print';

	function run()  {
		
		variables.height = 17;
		variables.width = 53;
		//variables.height = shell.getTermHeight()-13;
		//variables.width = shell.getTermWidth()-3;
		variables.centerX = round( variables.width / 2 );
		variables.centerY = round( variables.height / 2 );
		
		resetGame();
	
		
		variables.gameHeader = 
		'*******************************************************' & cr & 
		'*                   ' & p.boldGreen( 'CommandBox Snake' ) & '                  *' & cr &
		'*                     by Brad Wood                    *' & cr &
		'*******************************************************';
		
		// Initialize an array with an index for each row
		variables.gameSurface = arrayNew( 2 );
		var i = 0;
		// For each row...
		while( ++i <= variables.height ) {
			// Initialize it as an array of characters for each column
			//variables.gameSurface[ i ] = []; 
			loop from=1 to=variables.width index='j' {
				variables.gameSurface[ i ][ j ] = ' ';
			}			
		}
		
		variables.gameFooter =
		'*******************************************************' & cr &
		'*                   ' & p.bold( 'S' ) & ' moves left                      *' & cr &
		'*                   ' & p.bold( 'F' ) & ' moves right                     *' & cr &
		'*                   ' & p.bold( 'E' ) & ' moves up                        *' & cr &
		'*                   ' & p.bold( 'C' ) & ' moves down                      *' & cr &
		'*                                                     *' & cr &
		'*                   Press ' & p.bold( 'Q' ) & ' to quit                   *' &	cr &
		'*******************************************************';
		
		var a = p.bold( '*' );
		var s = ' ';

		variables.gameOverMessage =  [
			[ a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a ],
			[ a, s, s, s, s, s, s, s,  p.boldRed( 'G' ), p.boldRed( 'A' ), p.boldRed( 'M' ), p.boldRed( 'E' ), s, p.boldRed( 'O' ), p.boldRed( 'V' ), p.boldRed( 'E' ), p.boldRed( 'R' ), p.boldRed( '!' ), s, s, s, s, s, s, s, a ],
			[ a, s, s, s, p.bold( 'P' ), p.bold( 'r' ), p.bold( 'e' ), p.bold( 's' ), p.bold( 's' ), s, p.bold( '"' ), p.bold( 'R' ), p.bold( '"' ), s, p.bold( 't' ), p.bold( 'o' ), s, p.bold( 'r' ), p.bold( 'e' ), p.bold( 't' ), p.bold( 'r' ), p.bold( 'y' ), s, s, s, a ],
			[ a, s, s, s, s, s, s, s, s, s, p.bold( 'S' ), p.bold( 'c' ), p.bold( 'o' ), p.bold( 'r' ), p.bold( 'e' ), p.bold( ':' ),  s, s, s, s, s, s, s, s, s, a ],
			[ a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a, a ]
		];
		
		// Flush out anything stored up
		print.toConsole();
		// Start with a blank slate
		shell.clearScreen();
		
		
		// This lets the thread know we're still running'
		variables.snakeRun = true;
				
		try {
			// This thread will keep redrawing the screen while the main thread waits for user input
			threadName = 'snakeDrawer#createUUID()#';
			thread action="run" name=threadName priority="HIGH" {
				try{
					// Only keep drawing as long as the main thread is active
					while( variables.snakeRun ) {
						// Move and re-draw if not in an invalid state
						if( !variables.collision ) {
							variables.collision = !move( variables.direction );			
							printGame();
						}
						// Decrease this to speed up the game
						sleep( 200 );
					}	
				} catch( any e ) {
					logger.error( e.message & ' ' & e.detail, e.stacktrace );
				}
				
			}   // End thread
			
			var key = '';
			while( true ) {
						
				// Detect user input
				key = shell.waitForKey();
				
				if( isQuit( key ) ) {
					break;
				} else if( isLeft( key ) ) {
					variables.direction = 'left';
				} else if( isRight( key ) ) {
					variables.direction = 'right';
				} else if( isUp( key ) ) {
					variables.direction = 'up';
				} else if( isDown( key ) ) {
					variables.direction = 'down';
				} else if( isRetry( key ) ) {
					resetGame();
				}
								
			}

		} catch ( any e ) {
			// If anything bad happens, make sure the thread exits
			variables.snakeRun = false;
			// Wait until the thread finishes its last draw
			thread action="join" name=threadName;
			rethrow;
		}
		
		// We're done with the game, clean up.
		variables.snakeRun = false;
		// Wait until the thread finishes its last draw
		thread action="join" name=threadName;
				
	}

	/* *************************************************************************************
	* Private methods
	************************************************************************************* */

	private function printGame() {
		
			print.line( variables.gameHeader );
			
			var thisGameSurface = duplicate( variables.gameSurface );
			
			// Overlay the snake
			for( var part in variables.body ) {
				thisGameSurface[ part.y ][ part.x ] = p.green( '0' );
			}
			
			// Overlay the apples
			for( var apple in variables.apples ) {
				thisGameSurface[ apple.y ][ apple.x ] = p.redBold( '@' );
			}
			
			
			// If boom-booms happened, overlay message
			if( variables.collision ) {
				
				// Add in score
				thisScore = NumberFormat( variables.biteCount, "000" );
				gameOverMessage[ 4 ][ 18 ] = mid( thisScore, 1, 1 );
				gameOverMessage[ 4 ][ 19 ] = mid( thisScore, 2, 1 );
				gameOverMessage[ 4 ][ 20 ] = mid( thisScore, 3, 1 );
				
				// Find the offset of the upper left corner
				var startX = variables.centerX - ( round( gameOverMessage[1].len() / 2 ) );
				var startY = variables.centerY - ( round( gameOverMessage.len() / 2 ) ); 

				var YOffset = 0;
				for( var line in gameOverMessage ) {
					var XOffset = 0;
					while( ++XOffset <= line.len() ) {
						thisGameSurface[ startY + YOffset ][ startX + XOffset-1 ] = line[ XOffset];
					}
					YOffset++;
				}
								
			}
			
			// Now that we've build up the array of characters, spit them out to the console
			for( var row in thisGameSurface ) {
				print.text( '*' );
				for( var col in row ) {				
					print.text( col );
				}
				print.line( '*' );
				
			}
			
			print.line( variables.gameFooter );
			
			shell.clearScreen();
			print.toConsole();
			
	}


	private function move( required direction ) {
		var head = variables.body[1];
		var newHead = duplicate( head );
		
		// Move the head
		switch( arguments.direction ) {
			case 'up':
				newHead.y--;
				break;
			case 'down':
				newHead.y++;
				break;
			case 'left':
				newHead.x--;
				break;
			case 'right':
				newHead.x++;
				break;
				
		}
		
		// If the snake bites an apple, it grows by one
		if( !bite( newHead ) ) {
			// Move tail
			variables.body.deleteAt( variables.body.len() );
		}
			
		// If we hit something, the move failed
		if( isWallCollision( newHead ) || isSnakeCollision( newHead ) ) {
			return false;
		}
		
		// Move the snakes head
		variables.body.prepend( newHead );
		
		// Move successful
		return true;
	}

	private function resetGame() {
		
		// An array of coordinates that represent where the snake is
		// He starts in the center with a lenth of "1"
		variables.body = [
			{
				x : variables.centerX,
				y : variables.centerY
			}
		];
		
		// Start with 3 apples
		variables.appleCount = 3;
		variables.biteCount = 0;
		
		// An array of apples
		variables.apples = [];
		
		seedApples();
			
		variables.direction = 'up';
		variables.collision = false;
	}
	
	private function seedApples() {
		
		// Randomly seed our apples
		while( variables.apples.len() < variables.appleCount ) {
			var newApple = {
				x : randRange( 1, variables.width ),
				y : randRange( 1, variables.height )
			};
			
			// Make sure we don't double-stack our apples, or put them on the snake
			if( !isSnakeCollision( newApple ) && !isAppleCollision( newApple ) ) {
				variables.apples.append( newApple );	
			}
		}
		
	}
			
	private function isWallCollision( location ) {
		
		// Check collision with outside of play area
		if(
			   location.x < 1
			|| location.y < 1
			|| location.x > variables.width
			|| location.y > variables.height
		) {
			return true;
		}
				
		return false;
	}
	
			
	private function isSnakeCollision( location ) {
				
		// Check collision with snake
		for( piece in variables.body ) {
			if( piece.x == location.x && piece.y == location.y ) {				
				return true;
			}
		}
		
		return false;
	}
	
	private function bite( location ) {
		
		// Check to see if we reached an apple
		for( apple in variables.apples ) {
			if( apple.x == location.x && apple.y == location.y ) {
				// Add 1 to the score
				variables.biteCount++;
				// Remove that apple from the game area
				variables.apples.delete( apple );
				
				// If that was the last apple
				if( !variables.apples.len() ) {
					// Add some more!
					variables.appleCount += 3;
					seedApples();	
				}
				
				return true;
			}
		}
		
		return false;
		
	}
	
	private function isAppleCollision( location ) {
		
		// Check to see if this location is an an apple
		for( apple in variables.apples ) {
			if( apple.x == location.x && apple.y == location.y ) {
				return true;
			}
		}
		
		return false;
		
	}
		
	private function isQuit( key ) {
		// q or Q
		return ( key == 113 || key == 81 );
	}
		
	private function isRetry( key ) {
		// r or R
		return ( key == 114 || key == 82 );
	}
		
	private function isUp( key ) {
		// e or E 
		return ( key == 101 || key == 69 );
	}
		
	private function isDown( key ) {
		// c or C 
		return ( key == 99 || key == 67 );
	}
		
	private function isLeft( key ) {
		// s or S 
		return ( key == 115 || key == 83 );
	}
		
	private function isRight( key ) {
		// f or F 
		return ( key == 102 || key == 70 );
	}


}