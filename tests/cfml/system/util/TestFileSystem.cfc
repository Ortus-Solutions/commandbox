component name="TestFileSystem" extends="mxunit.framework.TestCase" {

	public void function testGetTopLevelPathsMixedFilesAndFolders() {
		var fileSystemUtil = application.wirebox.getInstance( 'FileSystem' );
		var result = fileSystemUtil.getTopLevelPaths( [ '\box.json', '\models\', '\models\foo.cfc' ] );
		assertEquals( [ 'box.json', 'models' ], result );
	}

	public void function testGetTopLevelPathsBothSeparatorStyles() {
		var fileSystemUtil = application.wirebox.getInstance( 'FileSystem' );
		var result = fileSystemUtil.getTopLevelPaths( [ '/box.json', '\models/', 'readme.md' ] );
		assertEquals( [ 'box.json', 'models', 'readme.md' ], result );
	}

	public void function testGetTopLevelPathsCollapsesDuplicates() {
		var fileSystemUtil = application.wirebox.getInstance( 'FileSystem' );
		var result = fileSystemUtil.getTopLevelPaths( [ '\models\a.cfc', '\models\b.cfc', '\Models\sub\c.cfc' ] );
		assertEquals( [ 'models' ], result );
	}

	public void function testGetTopLevelPathsEmptyArray() {
		var fileSystemUtil = application.wirebox.getInstance( 'FileSystem' );
		var result = fileSystemUtil.getTopLevelPaths( [] );
		assertEquals( [], result );
	}

	public void function testGetTopLevelPathsBareTopLevelFile() {
		var fileSystemUtil = application.wirebox.getInstance( 'FileSystem' );
		var result = fileSystemUtil.getTopLevelPaths( [ '\box.json' ] );
		assertEquals( [ 'box.json' ], result );
	}

	public void function testResetWindowsPermissionsIsSafeToCall() {
		var fileSystemUtil = application.wirebox.getInstance( 'FileSystem' );
		// On non-Windows systems, the method returns before doing any work.
		// On Windows, the empty array gives the method no paths to reset.
		// The method should not throw on either system.
		fileSystemUtil.resetWindowsPermissions( getTempDirectory(), [] );
	}

}
