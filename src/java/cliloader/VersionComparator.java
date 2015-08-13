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

import java.util.Comparator;

public class VersionComparator implements Comparator< Object >{

	@Override
	public int compare( Object o1, Object o2 ){
		String version1 = ( String ) o1;
		String version2 = ( String ) o2;

		VersionTokenizer tokenizer1 = new VersionTokenizer( version1 );
		VersionTokenizer tokenizer2 = new VersionTokenizer( version2 );

		int number1 = 0, number2 = 0;
		String suffix1 = "", suffix2 = "";

		while( tokenizer1.MoveNext() ) {
			if( !tokenizer2.MoveNext() ) {
				do {
					number1 = tokenizer1.getNumber();
					suffix1 = tokenizer1.getSuffix();
					if( number1 != 0 || suffix1.length() != 0 ) {
						// Version one is longer than number two, and non-zero
						return 1;
					}
				} while( tokenizer1.MoveNext() );

				// Version one is longer than version two, but zero
				return 0;
			}

			number1 = tokenizer1.getNumber();
			suffix1 = tokenizer1.getSuffix();
			number2 = tokenizer2.getNumber();
			suffix2 = tokenizer2.getSuffix();

			if( number1 < number2 ) {
				// Number one is less than number two
				return -1;
			}
			if( number1 > number2 ) {
				// Number one is greater than number two
				return 1;
			}

			boolean empty1 = suffix1.length() == 0;
			boolean empty2 = suffix2.length() == 0;

			if( empty1 && empty2 ) {
				continue; // No suffixes
			}
			if( empty1 ) {
				return 1; // First suffix is empty (1.2 > 1.2b)
			}
			if( empty2 ) {
				return -1; // Second suffix is empty (1.2a < 1.2)
			}

			// Lexical comparison of suffixes
			int result = suffix1.compareTo( suffix2 );
			if( result != 0 ) {
				return result;
			}

		}
		if( tokenizer2.MoveNext() ) {
			do {
				number2 = tokenizer2.getNumber();
				suffix2 = tokenizer2.getSuffix();
				if( number2 != 0 || suffix2.length() != 0 ) {
					// Version one is longer than version two, and non-zero
					return -1;
				}
			} while( tokenizer2.MoveNext() );

			// Version two is longer than version one, but zero
			return 0;
		}
		return 0;
	}

	public boolean equals( Object o1, Object o2 ){
		return compare( o1, o2 ) == 0;
	}
}

class VersionTokenizer{
	private boolean			_hasValue;
	private final int		_length;

	private int				_number;
	private int				_position;
	private String			_suffix;
	private final String	_versionString;

	public VersionTokenizer( String versionString ){
		if( versionString == null ) {
			throw new IllegalArgumentException( "versionString is null" );
		}

		this._versionString = versionString;
		this._length = versionString.length();
	}

	public int getNumber(){
		return this._number;
	}

	public String getSuffix(){
		return this._suffix;
	}

	public boolean hasValue(){
		return this._hasValue;
	}

	public boolean MoveNext(){
		this._number = 0;
		this._suffix = "";
		this._hasValue = false;

		// No more characters
		if( this._position >= this._length ) {
			return false;
		}

		this._hasValue = true;

		while( this._position < this._length ) {
			char c = this._versionString.charAt( this._position );
			if( c < '0' || c > '9' ) {
				break;
			}
			this._number = this._number * 10 + c - '0';
			this._position++;
		}

		int suffixStart = this._position;

		while( this._position < this._length ) {
			char c = this._versionString.charAt( this._position );
			if( c == '.' ) {
				break;
			}
			this._position++;
		}

		this._suffix = this._versionString.substring( suffixStart,
				this._position );

		if( this._position < this._length ) {
			this._position++;
		}

		return true;
	}
}