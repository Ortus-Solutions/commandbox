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

import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.PrintStream;
import java.net.URL;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;
import java.util.Timer;
import java.util.TimerTask;
import java.util.jar.JarEntry;
import java.util.jar.JarInputStream;
import java.util.jar.JarOutputStream;
import java.util.jar.Pack200;
import java.util.zip.GZIPInputStream;

import cliloader.LoaderCLIMain.ExtFilter;

public class Util{

	private static final int	KB	= 1024;

	public static void cleanUpUnpacked( File libDir ){
		if( libDir.exists()
				&& libDir.listFiles( new ExtFilter( ".gz" ) ).length > 0 ) {
			for( File gz : libDir.listFiles( new ExtFilter( ".gz" ) )) {
				try {
					gz.delete();
				} catch ( Exception e ) {
				}
			}
		}
	}

	public static void copyFile( File source, File dest ) throws IOException{
		FileInputStream fi = new FileInputStream( source );
		FileChannel fic = fi.getChannel();
		MappedByteBuffer mbuf = fic.map( FileChannel.MapMode.READ_ONLY, 0,
				source.length() );
		fic.close();
		fi.close();
		FileOutputStream fo = new FileOutputStream( dest );
		FileChannel foc = fo.getChannel();
		foc.write( mbuf );
		foc.close();
		fo.close();
	}

	public static void copyInternalFile( ClassLoader classLoader,
			String resourcePath, File dest ){
		URL resource = classLoader.getResource( resourcePath );
		try {
			BufferedInputStream bis = new BufferedInputStream(
					resource.openStream() );
			FileOutputStream output = new FileOutputStream( dest );
			writeStreamTo( bis, output, 8 * KB );
			output.close();
		} catch ( FileNotFoundException e ) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch ( IOException e ) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

	}

	public static void ensureJavaVersion(){
		Class< ? > nio;
		try {
			nio = Util.class.getClassLoader().loadClass(
					"java.nio.charset.StandardCharsets" );
			if( nio == null ) {
				System.out
						.println( "Could not load NIO!  Are we running on Java 7 or greater?  Sorry, exiting..." );
				System.exit( 1 );
			}
		} catch ( java.lang.ClassNotFoundException e ) {
			System.out
					.println( "Could not load NIO!  Are we running on Java 7 or greater?  Sorry, exiting..." );
			System.exit( 1 );
		}
	}

	static String getResourceAsString( String path ){
		InputStream is = null;
		ByteArrayOutputStream out = new ByteArrayOutputStream();
		PrintStream outPrint = new PrintStream( out );
		try {
			is = Util.class.getClassLoader().getResourceAsStream( path );
			int content;
			while( ( content = is.read() ) != -1 ) {
				// convert to char and display it
				outPrint.print( ( char ) content );
			}
		} catch ( IOException e ) {
			e.printStackTrace();
		} finally {
			try {
				if( is != null ) {
					is.close();
				}
				if( outPrint != null ) {
					outPrint.close();
				}
			} catch ( IOException ex ) {
				ex.printStackTrace();
			}
		}
		return out.toString();
	}

	public static void launch( List< String > cmdarray, int timeout )
			throws IOException, InterruptedException{
		// byte[] buffer = new byte[1024];

		ProcessBuilder processBuilder = new ProcessBuilder( cmdarray );
		processBuilder.redirectErrorStream( true );
		Process process = processBuilder.start();
		Thread.sleep( 500 );
		InputStream is = process.getInputStream();
		InputStreamReader isr = new InputStreamReader( is );
		BufferedReader br = new BufferedReader( isr );
		String line;
		int exit = -1;
		long start = System.currentTimeMillis();
		System.out.print( "Starting in background - " );
		while( System.currentTimeMillis() - start < timeout ) {
			if( br.ready() && ( line = br.readLine() ) != null ) {
				// Outputs your process execution
				try {
					exit = process.exitValue();
					if( exit == 0 ) {
						// Process finished
						while( ( line = br.readLine() ) != null ) {
							System.out.println( line );
						}
						System.exit( 0 );
					} else if( exit == 1 ) {
						System.out.println();
						printExceptionLine( line );
						while( ( line = br.readLine() ) != null ) {
							printExceptionLine( line );
						}
						System.exit( 1 );
					}
				} catch ( IllegalThreadStateException t ) {
					// This exceptions means the process has not yet finished.
					// decide to continue, exit(0), or exit(1)
					processOutout( line, process );
				}
			}
			Thread.sleep( 100 );
		}
		if( System.currentTimeMillis() - start > timeout ) {
			process.destroy();
			System.out.println();
			System.err.println( "ERROR: Startup exceeded timeout of " + timeout
					/ 1000 + " seconds - aborting!" );
			System.exit( 1 );
		}
		System.out.println( "Server is up - " );
		System.exit( 0 );
	}

	public static void printExceptionLine( String line ){
		final String msg = "java.lang.RuntimeException: ";
		System.out.println( line );
		String formatted = line.contains( msg ) ? line.substring( line
				.indexOf( msg ) + msg.length() ) : line;
		formatted = formatted.matches( "^\\s+at runwar.Start.*" ) ? ""
				: formatted.trim();
		if( formatted.length() > 0 ) {
			System.err.println( formatted );
		}
	}

	private static boolean processOutout( String line, Process process ){
		System.out.println( "processoutput: " + line );
		if( line.indexOf( "Server is up - " ) != -1 ) {
			// start up was successful, quit out
			System.out.println( line );
			System.exit( 0 );
		} else if( line
				.indexOf( "Exception in thread \"main\" java.lang.RuntimeException" ) != -1 ) {
			return true;
		}
		return false;
	}

	static String readFile( String path ) throws IOException{
		return readFile( path, StandardCharsets.UTF_8 );
	}

	static String readFile( String path, Charset encoding ) throws IOException{
		byte[] encoded = Files.readAllBytes( Paths.get( path ) );
		return new String( encoded, encoding );
	}

	/**
	 * Attempt to delete the Runwar jar and exit if it looks like locks exist on the file
	 * Do this first, since it's the most likely file to be locked and we can abort before destroying any other files
	 * @param libDir The folder to look in
	 * @param nameContains Match a jar with this in the name
	 */
	public static void checkIfJarsLocked( File libDir, String nameContains ){
		if( libDir.exists()
				&& libDir.listFiles( new ExtFilter( ".jar" ) ).length > 0 ) {
			for( File previous : libDir.listFiles( new ExtFilter( ".jar" ) )) {
				// Look for runwar{version}.jar
				if( previous.getAbsolutePath().toLowerCase().contains( nameContains )  ) {
					try {
						boolean result = previous.delete();

						if( !result ) {
							System.err.println( "CommandBox is having problems deleting your previous jars to complete the upgrade." );
							System.err.println( "Please close all open consoles and stop all running servers before trying again." );
							System.exit( 1 );
						}
						
					} catch ( Exception e ) {
						System.err.println( "CommandBox is having problems deleting your previous jars to complete the upgrade." );
						System.err.println( "Error: " + e.getMessage() );
						System.err.println( "Please close all open consoles and stop all running servers before trying again." );
						System.exit( 1 );
					}
				}
			}
		}
	}

	public static void removePreviousLibs( File libDir ){
		if( libDir.exists()
				&& libDir.listFiles( new ExtFilter( ".jar" ) ).length > 0 ) {
			for( File previous : libDir.listFiles( new ExtFilter( ".jar" ) )) {
				try {
					boolean result = previous.delete();

					if( !result ) {
						System.err.println( "CommandBox could not delete the jar [" + previous.getAbsolutePath() + "]" );
						System.err.println( "Please close all open consoles and stop all running servers before trying again." );
						System.exit( 1 );
					}
					
				} catch ( Exception e ) {
					System.err.println( "CommandBox could not delete the jar [" + previous.getAbsolutePath() + "]" );
					System.err.println( "Error: " + e.getMessage() );
					System.err.println( "Please close all open consoles and stop all running servers before trying again." );
					System.exit( 1 );
				}
			}
		}
	}

	public static void unpack( File inFile ){

		JarOutputStream out = null;
		InputStream in = null;
		String inName = inFile.getPath();
		String outName;

		if( inName.endsWith( ".pack.gz" ) ) {
			outName = inName.substring( 0, inName.length() - 8 );
		} else if( inName.endsWith( ".pack" ) ) {
			outName = inName.substring( 0, inName.length() - 5 );
		} else {
			outName = inName + ".unpacked";
		}
		try {
			Pack200.Unpacker unpacker = Pack200.newUnpacker();
			out = new JarOutputStream( new FileOutputStream( outName ) );
			in = new FileInputStream( inName );
			if( inName.endsWith( ".gz" ) ) {
				in = new GZIPInputStream( in );
			}
			unpacker.unpack( in, out );
		} catch ( IOException ex ) {
			ex.printStackTrace();
		} finally {
			if( in != null ) {
				try {
					in.close();
				} catch ( IOException ex ) {
					System.err.println( "Error closing file: "
							+ ex.getMessage() );
				}
			}
			if( out != null ) {
				try {
					out.flush();
					out.close();
				} catch ( IOException ex ) {
					System.err.println( "Error closing file: "
							+ ex.getMessage() );
				}
			}
		}
	}

	public static void unzipInteralZip( ClassLoader classLoader,
			String resourcePath, File libDir, boolean debug ){
		if( debug ) {
			System.out.println( "Extracting " + resourcePath );
		}
		libDir.mkdir();
		URL resource = classLoader.getResource( resourcePath );
		if( resource == null ) {
			System.err.println( "Could not find the " + resourcePath
					+ " on classpath!" );
			System.exit( 1 );
		}
		class PrintDot extends TimerTask{
			@Override
			public void run(){
				System.out.print( "." );
			}
		}
		Timer timer = new Timer();
		PrintDot task = new PrintDot();
		timer.schedule( task, 0, 2000 );

		try {

			BufferedInputStream bis = new BufferedInputStream(
					resource.openStream() );
			JarInputStream jis = new JarInputStream( bis );
			JarEntry je = null;
			while( ( je = jis.getNextJarEntry() ) != null ) {
				java.io.File f = new java.io.File( libDir.toString()
						+ java.io.File.separator + je.getName() );
				if( je.isDirectory() ) {
					f.mkdir();
					continue;
				}
				File parentDir = new File( f.getParent() );
				if( !parentDir.exists() ) {
					parentDir.mkdir();
				}
				FileOutputStream fileOutStream = new FileOutputStream( f );
				writeStreamTo( jis, fileOutStream, 8 * KB );
				if( f.getPath().endsWith( "pack.gz" ) ) {
					unpack( f );
					fileOutStream.close();
					f.delete();
				}
			}

		} catch ( Exception exc ) {
			task.cancel();
			exc.printStackTrace();
		}
		task.cancel();

	}

	public static int writeStreamTo( final InputStream input,
			final OutputStream output, int bufferSize ) throws IOException{
		int available = Math.min( input.available(), 256 * KB );
		byte[] buffer = new byte[ Math.max( bufferSize, available ) ];
		int answer = 0;
		int count = input.read( buffer );
		while( count >= 0 ) {
			output.write( buffer, 0, count );
			answer += count;
			count = input.read( buffer );
		}
		return answer;
	}
	
	public static void deleteDirectory(File f) throws IOException {
		  if (f.isDirectory()) {
		    for (File c : f.listFiles())
		    	deleteDirectory(c);
		  }
		  if (!f.delete())
		    throw new FileNotFoundException("Failed to delete file: " + f);
		}
	
}
