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

# Debug stuff.

use Data::Dumper;
use warnings;

#####

use strict;
use Getopt::Long qw(:config no_auto_abbrev);
use POSIX qw(strftime);

# Configurable variables
my $backupSourceFile; 						# Folder or file to back up.  Do not use FULL names.
my $backupSourcePath; 						# Path that $backupSourceFile lives under.
my $buPrefix = "default"; 					# Backed up file/folder filename prefix.
my $buTargetFolder; 						# Folder on dropbox to back up to.
my $buStagingFolder = "/tmp/"; 				# Local folder to stage your backup.  Used as a container to compress the backup.
my $dbuScriptName = "dropbox_uploader.sh"; 	# Name of Dropbox_Uploader script.
my $dbuScriptPath; 							# Path where Dropbox_Uploader lives.
my $tar = "/bin/tar"; 						# Path to the tar exe.
my $rm = "/bin/rm"; 						# Path to the rm exe.
my $compress; 								# Compress files / folders before uploading?
my $help; 									# Display help?

GetOptions (
    "bu_source_file=s"   => \$backupSourceFile, 	# required
    "bu_source_path=s"   => \$backupSourcePath, 	# required
    "bu_prefix=s"   => \$buPrefix,					# optional
    "bu_target_folder=s"   => \$buTargetFolder, 	# required
    "bu_staging_folder=s"   => \$buStagingFolder, 	# optional
    "script_name=s"   => \$dbuScriptName, 			# optional
    "script_path=s"   => \$dbuScriptPath, 			# required
    "tar=s"   => \$tar, 							# optional
    "rm=s"   => \$rm, 								# optional
    "compress"  => \$compress, 						# optional
    "help" => \$help								# optional
); 

# Verify our required flags are set.  If not, send instructions to the screen.
if ( !$backupSourceFile || !$backupSourcePath || !$buTargetFolder || !$dbuScriptPath || $help ) { readme(); }

# Other variables.
my $time = strftime "%Y-%m-%d_%H-%M-%S", localtime; # Formatted time (to use in the backed up file/folder name).
my $filename = $buPrefix . "_" . "backup_" . $time . ".tgz";
my $backupTarget =  $buTargetFolder . $filename;
my $dbuExe = $dbuScriptPath . $dbuScriptName;

# All of our work is done here.  Compress (if flag is set), then backup to dropbox, then remove the local compressed file (if flag is set).
if ( $compress ) {
 system($tar . " -czf " . $buStagingFolder . $filename . " " . $backupSourcePath . $backupSourceFile);
}
system($dbuScriptPath . $dbuScriptName . " upload " . $buStagingFolder . $filename . " " . $backupTarget);
if ( $compress ) {
    system($rm . " " . $buStagingFolder . $filename);
}

sub readme{
	print "Dropbox Uploader Compress v0.1\n";
	print "Dan Bough - daniel.bough\@gmail.com\n\n";
	print "Usage:  ./db_uploader_wrapper.pl [OPTIONS]\n";
    print "Example:  ./db_uploader_wrapper.pl --bu_source_file='bigfile.txt' --bu_source_path='/home/yourname/' --bu_target_folder='Backups' --script_path='/usr/sbin/' --compress\n\n";
    print "--bu_source_file     Required:  Folder of file to back up.  Do NOT use full paths.\n";
    print "--bu_source_path     Required:  Path to --bu_source_file.\n";
    print "--bu_prefix          Optional:  Backed up file/folder filename prefix. (Defaults to 'default').\n";
    print "--bu_target_folder   Required:  Folder on dropbox to back up to.\n";
    print "--bu_staging_folder  Optional:  Folder to stage backkup file / folder (it gets compressed here & then gets removed after it's uploaded.  Defaults to /tmp/.)\n";
    print "--script_name        Optional:  Name of Dropbox Uploader shell script (defaults to dropbox_uploader.sh).\n";
    print "--script_path        Required:  Path where dropbox_uploader.sh lives\n";
    print "--tar                Optional:  Path to tar (defaults to /bin/tar).\n";
    print "--rm                 Optional:  Path to rm (defaults to /bin/rm).\n";
    print "--compress           Optional:  Compress file or folder (tar and gzip).\n";       
    print "--help               Optional:  Display this message.\n\n";
	exit;
}
