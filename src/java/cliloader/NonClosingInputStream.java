package cliloader;

import java.io.IOException;
import java.io.InputStream;

public class NonClosingInputStream extends InputStream {
	private final InputStream in;
	private final boolean closeWrapped;

	public NonClosingInputStream(final InputStream in, final boolean closeWrapped) {
		this.in = in;
		this.closeWrapped = closeWrapped;
	}

	public NonClosingInputStream(final InputStream in) {
		this(in, false);
	}

	@Override
	public int read() throws IOException {
		return in.read();
	}

	@Override
	public int read(final byte[] b) throws IOException {
		return in.read(b);
	}

	@Override
	public int read(final byte[] b, final int off, final int len) throws IOException {
		return in.read(b, off, len);
	}

	@Override
	public long skip(final long n) throws IOException {
		return in.skip(n);
	}

	@Override
	public int available() throws IOException {
		return in.available();
	}

	@Override
	public void close() throws IOException {
		if (closeWrapped)
			in.close();
	}

	@Override
	public synchronized void mark(final int readlimit) {
		in.mark(readlimit);
	}

	@Override
	public synchronized void reset() throws IOException {
		in.reset();
	}

	@Override
	public boolean markSupported() {
		return in.markSupported();
	}
}
