#!/usr/bin/perl

# Dropbox Uploader Compress
#
# Copyright (C) 2010-2013 Dan Bough <daniel.bough@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#

use strict;
use Getopt::Long qw(:config no_auto_abbrev);
use POSIX qw(strftime);

# Configurable variables
my $backupSourceFile; 						# Folder or file to back up.  Do not use FULL names.
my $backupSourcePath; 						# Path that $backupSourceFile lives under.
my $backupSourceType;                       # Folder or file?
my $buPrefix = "default"; 					# Backed up file/folder filename prefix.
my $buTargetFolder; 						# Folder on dropbox to back up to.
my $buStagingFolder = "/tmp/"; 				# Local folder to stage your backup.  Used as a container to compress the backup.
my $dbuScriptName = "dropbox_uploader.sh"; 	# Name of Dropbox_Uploader script.
my $dbuScriptPath; 							# Path where Dropbox_Uploader lives.
my $tar = "/bin/tar"; 						# Path to the tar exe.
my $rm = "/bin/rm"; 						# Path to the rm exe.
my $nocompress; 							# Compress files / folders before uploading?
my $help; 									# Display help?

GetOptions (
    "bu_source=s"   => \$backupSourceFile, 	# required
    "bu_source_path=s"   => \$backupSourcePath, 	# required
    "type=s"   => \$backupSourceType,               # required
    "bu_prefix=s"   => \$buPrefix,					# optional
    "bu_target_folder=s"   => \$buTargetFolder, 	# optional
    "bu_staging_folder=s"   => \$buStagingFolder, 	# optional
    "script_name=s"   => \$dbuScriptName, 			# optional
    "script_path=s"   => \$dbuScriptPath, 			# required
    "tar=s"   => \$tar, 							# optional
    "rm=s"   => \$rm, 								# optional
    "nocompress"  => \$nocompress, 					# optional
    "help" => \$help								# optional
); 

# Format the target folder (add a / at the end)
$buTargetFolder = $buTargetFolder . "/";

# Verify our required flags are set.  If not, send instructions to the screen.
if ( !$backupSourceFile || !$backupSourcePath || !$backupSourceType || ( $backupSourceType ne 'folder' && $backupSourceType ne 'file') || !$dbuScriptPath || $help ) { readme(); }

# Other variables.
my $time = strftime "%Y-%m-%d_%H-%M-%S", localtime; # Formatted time (to use in the backed up file/folder name).
my $filename = $buPrefix . "_" . "backup_" . $time . ".tgz";
my $backupTarget;
if ( !$nocompress ) {
    $backupTarget =  $buTargetFolder . $filename;
} else {
    $backupTarget =  $buTargetFolder . $backupSourceFile;
}
my $dbuExe = $dbuScriptPath . $dbuScriptName;

# Format source folder (add a / at the end)
if ( $backupSourceType eq 'folder' ) {
    $backupSourceFile = $backupSourceFile . "/";
}

# All of our work is done here.  Compress (unless the nocompress flag is set), then backup to dropbox, then remove the local compressed file (if nocompress flag is set).
if ( !$nocompress ) {
    system($tar . " -czf " . $buStagingFolder . $filename . " -C " . $backupSourcePath . " " . $backupSourceFile);
    system($dbuScriptPath . $dbuScriptName . " upload " . $buStagingFolder . $filename . " " . $backupTarget);
    system($rm . " " . $buStagingFolder . $filename);
} else {
    system($dbuScriptPath . $dbuScriptName . " upload " . $backupSourcePath . $backupSourceFile . " " . $backupTarget);
}

sub readme{
	print "Dropbox Uploader Compress v0.1.2\n";
	print "Dan Bough - daniel.bough\@gmail.com\n\n";
	print "Usage:  ./db_uploader_compress.pl [OPTIONS]\n";
    print "Example:  ./db_uploader_compress.pl --bu_source='foo' --bu_source_path='/home/bar/' --bu_target_folder='baz' --script_path='/usr/sbin/' --type='folder'\n\n";
    print "--bu_source          Required:  Folder of file to back up.  Do NOT use full paths or slashes.\n";
    print "--bu_source_path     Required:  Path to --bu_source_file.\n";
    print "--type               Required:  Source = folder or file.\n";
    print "--bu_prefix          Optional:  Backed up file/folder filename prefix. (Defaults to 'default').  This is not applicable if the --nocompress flag is set.\n";
    print "--bu_target_folder   Optional:  Folder on dropbox to back up to.\n";
    print "--bu_staging_folder  Optional:  Folder to stage backkup file / folder (it gets compressed here & then gets removed after it's uploaded.  Defaults to /tmp/.)\n";
    print "--script_name        Optional:  Name of Dropbox Uploader shell script (defaults to dropbox_uploader.sh).\n";
    print "--script_path        Required:  Path where dropbox_uploader.sh lives\n";
    print "--tar                Optional:  Path to tar (defaults to /bin/tar).\n";
    print "--rm                 Optional:  Path to rm (defaults to /bin/rm).\n";
    print "--nocompress         Optional:  Do not compress file (tar and gzip). Folders HAVE to be compressed!\n";       
    print "--help               Optional:  Display this message.\n\n";
	exit;
}
