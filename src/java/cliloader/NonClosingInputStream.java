/**
 * Copyright (C) 2012 Ortus Solutions, Corp
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the APACHE LICENSE, VERSION 2.0
 * as published by the Apache Software Foundation.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
 * APACHE LICENSE for more details.
 *
 * You should have received a copy of the APACHE LICENSE, VERSION 2.0
 * along with this library.
 */
package cliloader;

import java.io.IOException;
import java.io.InputStream;

public class NonClosingInputStream extends InputStream {
	private final boolean closeWrapped;
	private final InputStream in;

	public NonClosingInputStream(final InputStream in) {
		this(in, false);
	}

	public NonClosingInputStream(final InputStream in,
			final boolean closeWrapped) {
		this.in = in;
		this.closeWrapped = closeWrapped;
	}

	@Override
	public int available() throws IOException {
		return this.in.available();
	}

	@Override
	public void close() throws IOException {
		if (this.closeWrapped) {
			this.in.close();
		}
	}

	@Override
	public synchronized void mark(final int readlimit) {
		this.in.mark(readlimit);
	}

	@Override
	public boolean markSupported() {
		return this.in.markSupported();
	}

	@Override
	public int read() throws IOException {
		return this.in.read();
	}

	@Override
	public int read(final byte[] b) throws IOException {
		return this.in.read(b);
	}

	@Override
	public int read(final byte[] b, final int off, final int len)
			throws IOException {
		return this.in.read(b, off, len);
	}

	@Override
	public synchronized void reset() throws IOException {
		this.in.reset();
	}

	@Override
	public long skip(final long n) throws IOException {
		return this.in.skip(n);
	}
}
