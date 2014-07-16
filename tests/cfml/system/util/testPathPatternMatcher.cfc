component name="TestPathPatternMatcher" extends="mxunit.framework.TestCase" {

	public void function setup() {
		PathPatternMatcher = application.wirebox.getInstance( 'PathPatternMatcher' );		
	}

	// End a pattern with a slash to only match a directory. Start a pattern with a slash to start in the root.
	
	// foo will match any file or folder in the directory tree
	public void function testSimpleString() {				
		assertTrue( PathPatternMatcher.matchPattern( 'a', 'a/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a', 'a/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'b', 'a/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'c', 'a/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'd', 'a/b/c/d/' ) );
		
		assertTrue( PathPatternMatcher.matchPattern( 'a', 'a' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a', 'a/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'b', 'a/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'c', 'a/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'd', 'a/b/c/d' ) );
	}
	
	
	// /foo will only match a file or folder in the root
	public void function testLeadingSlash() {
		assertTrue( PathPatternMatcher.matchPattern( '/a', 'a/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a', 'a/b/c/d/' ) );
		assertFalse( PathPatternMatcher.matchPattern( '/b', 'a/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a/b', 'a/b/c/d/' ) );
		assertFalse( PathPatternMatcher.matchPattern( '/d', 'a/b/c/d/' ) );
		
		assertTrue( PathPatternMatcher.matchPattern( '/a', 'a' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a', 'a/b/c/d' ) );
		assertFalse( PathPatternMatcher.matchPattern( '/b', 'a/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a/b', 'a/b/c/d' ) );
		assertFalse( PathPatternMatcher.matchPattern( '/d', 'a/b/c/d' ) );
	}
	
	// foo/ will only match a directory anywhere in the directory tree
	public void function testTrailingSlash() {
		assertTrue( PathPatternMatcher.matchPattern( 'a/', 'a/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a/', 'a/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'b/', 'a/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'c/', 'a/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'd/', 'a/b/c/d/' ) );
		
		assertFalse( PathPatternMatcher.matchPattern( 'a/', 'a' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a/', 'a/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'b/', 'a/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'c/', 'a/b/c/d' ) );
		assertFalse( PathPatternMatcher.matchPattern( 'd/', 'a/b/c/d' ) );
	}
	
	// /foo/ will only match a folder in the root
	public void function testLeadingAndTrailingSlash() {
		assertTrue( PathPatternMatcher.matchPattern( '/a/', 'a/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a/', 'a/b/c/d/' ) );
		assertFalse( PathPatternMatcher.matchPattern( '/b/', 'a/b/c/d/' ) );
		assertFalse( PathPatternMatcher.matchPattern( '/c/', 'a/b/c/d/' ) );
		assertFalse( PathPatternMatcher.matchPattern( '/d/', 'a/b/c/d/' ) );
		
		assertFalse( PathPatternMatcher.matchPattern( '/a/', 'a' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a/', 'a/b/c/d' ) );
		assertFalse( PathPatternMatcher.matchPattern( '/b/', 'a/b/c/d' ) );
		assertFalse( PathPatternMatcher.matchPattern( '/c/', 'a/b/c/d' ) );
		assertFalse( PathPatternMatcher.matchPattern( '/d/', 'a/b/c/d' ) );
	}
	
	// Use a single * to match zero or more characters INSIDE a file or folder name (won't match a slash)
	
	// foo* will match any file or folder starting with "foo"
	public void function testTrailingSingleAstrisk() {				
		assertTrue( PathPatternMatcher.matchPattern( 'a*', 'a/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a*', 'abc/' ) );
		assertFalse( PathPatternMatcher.matchPattern( 'a*', 'xyz/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a*', 'a/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a*', 'abc/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'b*', 'a/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'b*', 'a/bxyz/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'd*', 'a/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'd*', 'a/b/c/def/' ) );
		
		assertTrue( PathPatternMatcher.matchPattern( 'a*', 'a' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a*', 'abc' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a*', 'a/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a*', 'abc/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'b*', 'a/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'b*', 'a/bxyz/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'd*', 'a/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'd*', 'a/b/c/def' ) );
	}
	
	// foo*.txt will match any file or folder starting with "foo" and ending with .txt
	public void function testInsideSingleAstrisk() {
		assertTrue( PathPatternMatcher.matchPattern( 'a*.txt', 'a.txt/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a*.txt', 'abc.txt/' ) );
		assertFalse( PathPatternMatcher.matchPattern( 'a*.txt', 'xyz.txt/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a*z', 'az/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a*z', 'abcz/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'b*z', 'a/bz/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'b*z', 'a/bxyz/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'd*z', 'a/b/c/dz/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'd*z', 'a/b/c/defz/' ) );
		
		assertTrue( PathPatternMatcher.matchPattern( 'a*.txt', 'a.txt' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a*.txt', 'abc.txt' ) );
		assertFalse( PathPatternMatcher.matchPattern( 'a*.txt', 'xyz.txt' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a*z', 'az/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a*z', 'abcz/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'b*z', 'a/bz/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'b*z', 'a/bxyz/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'd*z', 'a/b/c/dz' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'd*z', 'a/b/c/defz' ) );
	}
	
	// *foo will match any file or folder ending with "foo"
	public void function testLeadingSingleAstrisk() {
		assertTrue( PathPatternMatcher.matchPattern( '*a.txt', 'a.txt/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*a.txt', 'cba.txt/' ) );
		assertFalse( PathPatternMatcher.matchPattern( '*a.txt', 'xyz.txt/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*a', 'a/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*xyz', 'xyz/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*xyz', 'abcxyz/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*xyz', 'a/xyz/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*xyz', 'a/abcxyz/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*xyz', 'a/b/c/xyz/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*xyz', 'a/b/c/abcxyz/' ) );
		
		assertTrue( PathPatternMatcher.matchPattern( '*a.txt', 'a.txt' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*a.txt', 'cba.txt' ) );
		assertFalse( PathPatternMatcher.matchPattern( '*a.txt', 'xyz.txt' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*a', 'a/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*xyz', 'xyz/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*xyz', 'abcxyz/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*xyz', 'a/xyz/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*xyz', 'a/abcxyz/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*xyz', 'a/b/c/xyz' ) );
		assertTrue( PathPatternMatcher.matchPattern( '*xyz', 'a/b/c/abcxyz' ) );
	}
	
	// a/*/z will match a/b/z but not a/b/c/z
	public void function testSingleAstrisk() {
		assertTrue( PathPatternMatcher.matchPattern( 'a/*/z', 'a/b/z/' ) );
		assertFalse( PathPatternMatcher.matchPattern( 'a/*/z', 'a/b/c/z/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/*/z', 'a/z/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/*/z', 'a/z/foo/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a/*', 'a/b/' ) );
		
		assertTrue( PathPatternMatcher.matchPattern( 'a/*/z', 'a/b/z/' ) );
		assertFalse( PathPatternMatcher.matchPattern( 'a/*/z', 'a/b/c/z/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/*/z', 'a/z/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/*/z', 'a/z/foo/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a/*', 'a/b/' ) );
	}
	
	// Use a double ** to match zero or more characters including slashes. This allows a pattern to span directories
	
	// a/**/z will match a/z and a/b/z and a/b/c/z
	public void function testDoubleAstrisk() {
		assertTrue( PathPatternMatcher.matchPattern( 'a/**/z', 'a/b/z/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a/**/z', 'a/z/' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a/**/z', 'a/b/c/z/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/**/z', 'a/z/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/**/z', 'a/b/c/z/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/**/z', 'a/z/foo/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/**/z', 'a/b/c/z/foo/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a/**', 'a/b/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a/**', 'a/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '**/foo', 'foo/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '**/foo/bar', 'foo/bar/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '**/foo/bar', 'a/b/foo/bar/' ) );
		
		assertTrue( PathPatternMatcher.matchPattern( 'a/**/z', 'a/b/z' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a/**/z', 'a/z' ) );
		assertTrue( PathPatternMatcher.matchPattern( 'a/**/z', 'a/b/c/z' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/**/z', 'a/z' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/**/z', 'a/b/c/z' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/**/z', 'a/z/foo' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/**/z', 'a/b/c/z/foo' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a/**', 'a/b' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a/**', 'a/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( '**/foo', 'foo' ) );
		assertTrue( PathPatternMatcher.matchPattern( '**/foo/bar', 'foo/bar' ) );
		assertTrue( PathPatternMatcher.matchPattern( '**/foo/bar', 'a/b/foo/bar' ) );
	}
	
	// Normalized slashes
	public void function testNormalizedSlashes() {
		assertTrue( PathPatternMatcher.matchPattern( '/a', 'a\' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a', 'a\b/c\d/' ) );
		assertFalse( PathPatternMatcher.matchPattern( '\b', 'a/b/c/d/' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a/b', 'a/b/c/d/' ) );
		assertFalse( PathPatternMatcher.matchPattern( '\d', 'a\b\c\d\' ) );
		
		assertTrue( PathPatternMatcher.matchPattern( '\a', 'a' ) );
		assertTrue( PathPatternMatcher.matchPattern( '\a', 'a\b/c/d' ) );
		assertFalse( PathPatternMatcher.matchPattern( '/b', 'a/b/c/d' ) );
		assertTrue( PathPatternMatcher.matchPattern( '/a\b', 'a/b/c\d' ) );
		assertFalse( PathPatternMatcher.matchPattern( '/d', 'a\b\c\d' ) );
	}
}