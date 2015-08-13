/**
 * Copyright (C) 2012 Ortus Solutions, Corp
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3.0 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library.
 */
package cliloader;

import java.io.IOException;
import java.io.InputStream;

public class NonClosingInputStream extends InputStream{
	private final boolean		closeWrapped;
	private final InputStream	in;

	public NonClosingInputStream( final InputStream in ){
		this( in, false );
	}

	public NonClosingInputStream( final InputStream in,
			final boolean closeWrapped ){
		this.in = in;
		this.closeWrapped = closeWrapped;
	}

	@Override
	public int available() throws IOException{
		return this.in.available();
	}

	@Override
	public void close() throws IOException{
		if( this.closeWrapped ) {
			this.in.close();
		}
	}

	@Override
	public synchronized void mark( final int readlimit ){
		this.in.mark( readlimit );
	}

	@Override
	public boolean markSupported(){
		return this.in.markSupported();
	}

	@Override
	public int read() throws IOException{
		return this.in.read();
	}

	@Override
	public int read( final byte[] b ) throws IOException{
		return this.in.read( b );
	}

	@Override
	public int read( final byte[] b, final int off, final int len )
			throws IOException{
		return this.in.read( b, off, len );
	}

	@Override
	public synchronized void reset() throws IOException{
		this.in.reset();
	}

	@Override
	public long skip( final long n ) throws IOException{
		return this.in.skip( n );
	}
}
