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
use Switch;

# Configurable variables
my $backupSource;    						# Folder or file to back up.  Do not use FULL names.
my $backupSourceType;                       # Folder or File?
my $backupSourceFolder;                     # Used when tarring
my $buPrefix = "default"; 					# Backed up file/folder filename prefix.
my $buTargetFolder; 						# Folder on dropbox to back up to.
my $buStagingFolder = "/tmp/"; 				# Local folder to stage your backup.  Used as a container to compress the backup.
my $dbuScriptName = "dropbox_uploader.sh"; 	# Name of Dropbox_Uploader script.
my $dbuScriptPath = "./"; 					# Path where Dropbox_Uploader lives.
my $compressType;                           # What compression?  tar = tar/gzip, zip = zip
my $compressPath;                        	# Path to the tar or zip exe.
my $rm = "/bin/rm"; 						# Path to the rm exe.
my $nocompress; 							# Compress files / folders before uploading?
my $fileSuffix;                             # Use custom suffix?
my $encrypt;                                # Encrypt file?
my $help; 									# Display help?

GetOptions (
    "bu_source=s"   => \$backupSource, 	            # required
    "bu_prefix=s"   => \$buPrefix,					# optional
    "bu_target_folder=s"   => \$buTargetFolder, 	# optional
    "bu_staging_folder=s"   => \$buStagingFolder, 	# optional
    "script_name=s"   => \$dbuScriptName, 			# optional
    "script_path=s"   => \$dbuScriptPath, 			# optional
    "compression_path=s"   => \$compressPath, 			# optional
    "rm=s"   => \$rm, 								# optional
    "nocompress"  => \$nocompress, 					# optional
    "compression_type=s" => \$compressType,         # optional
    "file_suffix=s"   => \$fileSuffix,                # optional
    "help" => \$help,								# optional
    "encrypt" => \$encrypt                          # optional
); 

# Get compression type and paths
$compressType = get_compression_type();
$compressPath = get_compression_path();
$fileSuffix = get_file_suffix();

# Format the target folder (add a / at the end)
$buTargetFolder = $buTargetFolder . "/";

# Verify our required flags are set.  If not, send instructions to the screen.
if ( !$backupSource || $help ) { readme(); }

# Other variables.
my $time = strftime "%Y-%m-%d_%H-%M-%S", localtime; # Formatted time (to use in the backed up file/folder name).
my $filename = $buPrefix . "_" . "backup_" . $time . "." . $fileSuffix;

my $backupTarget;
if ( !$nocompress ) {
    $backupTarget =  $buTargetFolder . $filename;
} else {
    $backupTarget =  $buTargetFolder . $backupSource;
}
my $dbuExe = $dbuScriptPath . $dbuScriptName;

# Determine if the source is a file or a folder
if ( -f $backupSource ) {
    $backupSourceType = 'file';
    $backupSourceFolder = get_folder_name($backupSource);
} elsif ( -d $backupSource ) {
    $backupSourceType = 'folder';

    # Format source folder (add a / at the end)
    $backupSource = $backupSource . "/";

    # For relative paths when using TAR
    $backupSourceFolder = $backupSource;

    # If the compress flag not set, exit;
    if ( $nocompress ) {
        print "You must compress folders!  Remove the --nocompress flag please.\n";
        exit;
    }

    # Determine if folder is empty
    if ( is_folder_empty($backupSource) ) {
        print "Folder is empty dummy!  Put some stuff in it first!\n";
        exit;
    }
}


# All of our work is done here.
switch ( $compressType ) {
    case "tar" { tar_file() }
    case "zip" { zip_file() }
    else { no_compress() }
}

# Subs below 

sub get_compression_type {
    if ( $compressType eq 'zip' ) {
        return 'zip';
    } elsif ( $compressType eq 'tar' ) {
        return 'tar';
    } elsif ( $nocompress ) {
        return 'none';
    } else {
        return 'tar'
    }
}

sub get_compression_path {
    if ( $compressPath ) {
        return $compressPath;
    } elsif ( $compressType eq 'zip' ) {
        return "/usr/bin/zip"
    } elsif ( $compressType eq 'tar' ) {
        return "/bin/tar";;
    } else {
        return "";
    }
}

sub get_file_suffix {
    if ( $fileSuffix ) {
        return $fileSuffix;
    } elsif ( $compressType eq 'zip' ) {
        return "zip";
    } elsif ( $compressType eq 'tar' ) {
        return "tgz";
    } else {
        return "";
    }
}

sub is_folder_empty {
    my $dirname = shift;
    opendir(my $dh, $dirname) or die "Not a directory";
    return scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) == 0;
}

sub get_folder_name {
    my $file = shift;
    my @paths = split(/\//,$file);
    my $folder = join '/', @paths[0...$#paths-1];
    return $folder . "/";
}

sub tar_file {
    if ( !$nocompress ) {
        system($compressPath . " czfP " . $buStagingFolder . $filename . " -C " . $backupSourceFolder . " " . $backupSource);
        system($dbuScriptPath . $dbuScriptName . " upload " . $buStagingFolder . $filename . " " . $backupTarget);
        system($rm . " " . $buStagingFolder . $filename);
    } else {
        print "The --nocompress flag is set. Cannot continue.  For help, run ./db_uploader_compress --help\n\n";
        exit;
    }
}

sub zip_file {
    if ( $encrypt ) {
        print "You encrypted it!\n";
    } else {
        system($compressPath . " " . $buStagingFolder . $filename . " " . $backupSourceFolder . " " . $backupSource);
        system($dbuScriptPath . $dbuScriptName . " upload " . $buStagingFolder . $filename . " " . $backupTarget);
        system($rm . " " . $buStagingFolder . $filename);
    }
}

sub no_compress {
    if ( $backupSourceType eq 'folder' ) {
        print "You must compress folders.  Please remove the --nocompress flag.\n";
    }
    system($dbuScriptPath . $dbuScriptName . " upload " . $backupSource . " " . $backupTarget);
}

sub encript {

}

sub readme{
	print "Dropbox Uploader Compress v0.1.3\n";
	print "Dan Bough - daniel.bough\@gmail.com\n\n";
	print "Usage:  ./db_uploader_compress.pl [OPTIONS]\n";
    print "Example:  ./db_uploader_compress.pl --bu_source='/home/bar/foo' --bu_target_folder='baz'\n\n";
    print "--bu_source          Required:  Folder of file to back up.  Do NOT use full paths or slashes.\n";
    print "--bu_prefix          Optional:  Backed up file/folder filename prefix. (Defaults to 'default').  This is not applicable if the --nocompress flag is set.\n";
    print "--bu_staging_folder  Optional:  Folder to stage backkup file / folder (it gets compressed here & then gets removed after it's uploaded.  Defaults to /tmp/.)\n";
    print "--bu_target_folder   Optional:  Folder on dropbox to back up to.\n";
    print "--compression_type   Optional:  Valid compression types:  tar (tar/gzip), zip (zip)\n";
    print "--compression_path      Optional:  Path to compression file.  Default:  /bin/tar (tar), /usr/bin/zip (zip).\n";
    print "--file_suffix        Optional:  Custom file suffix.  Used to obfuscate file types.\n";
    print "--encrypt            Optional:  Encrypt file\n";
    print "--help               Optional:  Display this message.\n";
    print "--nocompress         Optional:  Do not compress file (tar and gzip). Folders HAVE to be compressed!\n";       
    print "--rm                 Optional:  Path to rm (defaults to /bin/rm).\n";
    print "--script_name        Optional:  Name of Dropbox Uploader shell script (defaults to dropbox_uploader.sh).\n";
    print "--script_path        Optional:  Path where dropbox_uploader.sh lives (defaults to local directory).\n\n";
	exit;
}
