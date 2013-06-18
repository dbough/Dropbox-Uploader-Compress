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
use Getopt::Long qw(:config no_auto_abbrev permute);
use POSIX qw(strftime);
use Switch;
use File::Basename;

# Unknown options
# if ( $ARGV[0] ) {
#     print $ARGV[0] . " is unknown!\n\n";
#     readme();
#     exit;
# }

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
my $quiet;                                  # Suppress output?
my $suppressOutput;                         # Used in conjunction with $queiet.
my $help; 									# Display help?

GetOptions (
    "bu_source=s"   => \$backupSource, 	            # required
    "bu_prefix=s"   => \$buPrefix,					# optional
    "bu_target_folder=s"   => \$buTargetFolder, 	# optional
    "bu_staging_folder=s"   => \$buStagingFolder, 	# optional
    "script_name=s"   => \$dbuScriptName, 			# optional
    "script_path=s"   => \$dbuScriptPath, 			# optional
    "compression_path=s"   => \$compressPath, 	    # optional
    "rm=s"   => \$rm, 								# optional
    "nocompress"  => \$nocompress, 					# optional
    "compression_type=s" => \$compressType,         # optional
    "file_suffix=s"   => \$fileSuffix,              # optional
    "help" => \$help,								# optional
    "encrypt" => \$encrypt,                         # optional
    "q" => \$quiet                                  # optional
); 

# Set variables based on flags passed etc.
$compressType = get_compression_type();
$compressPath = get_compression_path();
$fileSuffix = get_file_suffix();
$suppressOutput = get_suppress_output();

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
    $backupTarget = get_file_name($backupSource);
}
my $dbuExe = $dbuScriptPath . $dbuScriptName;

# Determine if the source is a file or a folder
if ( -f $backupSource ) {
    $backupSourceType = 'file';
    if ( !$nocompress ) {
        $backupSourceFolder = get_folder_name($backupSource);
    }
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

# If the ecnrpyt flag is set, make sure we have private and public keys
# in the local directory.  If not, prompt user to create them through the encrypt_help sub.
if ( $encrypt ) {
    my $dirname = dirname(__FILE__);
    if ( (-f $dirname . "/key.pem") && ( -f $dirname . "/key-public.pem") ) {
        # Check to make sure the keys are formatted correctly.  
        # If not, the subroutine will exit and the script will stop executing.
        is_key_valid( "key.pem", "private" );
        is_key_valid( "key-public.pem", "public" );
        print "key.pem and key-public.pem found.  Continuing...\n";
        exit;
    } else {
        encrypt_help();
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

sub get_suppress_output {
    if ( $quiet ) {
        return " > /dev/null 2>&1"
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
    my $file = shift;;
    return dirname($file);
}

sub get_file_name {
    my $file = shift;
    my @paths = split(/\//,$file);
    return  @paths[-1];
}

sub tar_file {
    if ( !$nocompress ) {
        system($compressPath . " czfP " . $buStagingFolder . $filename . " -C " . $backupSourceFolder . " " . $backupSource . " " . $suppressOutput);
        system($dbuScriptPath . $dbuScriptName . " upload " . $buStagingFolder . $filename . " " . $backupTarget . " " . $suppressOutput);
        system($rm . " " . $buStagingFolder . $filename) . " " . $suppressOutput;
    } else {
        print "The --nocompress flag is set. Cannot continue.  For help, run ./db_uploader_compress --help\n\n";
        exit;
    }
}

sub zip_file {
    if ( $encrypt ) {
        print "You encrypted it!\n";
    } else {
        system($compressPath . " " . $buStagingFolder . $filename . " " . $backupSourceFolder . " " . $backupSource . " " . $suppressOutput);
        system($dbuScriptPath . $dbuScriptName . " upload " . $buStagingFolder . $filename . " " . $backupTarget . " " . $suppressOutput);
        system($rm . " " . $buStagingFolder . $filename);
    }
}

sub no_compress {
    if ( $backupSourceType eq 'folder' ) {
        print "You must compress folders.  Please remove the --nocompress flag.\n";
    }
    system($dbuScriptPath . $dbuScriptName . " upload " . $backupSource . " " . $backupTarget . " " . $suppressOutput);
}

sub is_key_valid {
    my $file = shift;
    my $type = shift;
    my $result;
    open FILE, $file or die $!;
    while ( <FILE> ) {
        if ( $type eq "private" ) {
            $result = index($_, "BEGIN RSA PRIVATE KEY");
        } elsif ( $type eq "public" ) {
            $result = index($_, "BEGIN PUBLIC KEY");
        } else {
            print "Unknown key type:  $type ! \n";
            encrypt_help();
        }
    }
    close(FILE);
    if ( !($result >= 0) ) {
        print "$file does not appear to be a valid $type key.\n";
        encrypt_help();
    }
}

sub encrypt {

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
    print "--compression_type   Optional:  Valid compression types:  tar and zip.\n";
    print "--compression_path   Optional:  Path to compression file.  Default:  /bin/tar (tar), /usr/bin/zip (zip).\n";
    print "--file_suffix        Optional:  Custom file suffix.  Used to obfuscate file types.\n";
    print "--encrypt            Optional:  Encrypt file\n";
    print "--help               Optional:  Display this message.\n";
    print "--nocompress         Optional:  Do not compress file. Folders HAVE to be compressed!\n";
    print "--q                  Optional:  Suppress outout.\n";
    print "--rm                 Optional:  Path to rm (defaults to /bin/rm).\n";
    print "--script_name        Optional:  Name of Dropbox Uploader shell script (defaults to dropbox_uploader.sh).\n";
    print "--script_path        Optional:  Path where dropbox_uploader.sh lives (defaults to local directory).\n\n";
	exit;
}

sub encrypt_help{
    print "\nEncryption Help\n\n";
    print "In order to encrypt a file or folder, a public and private encryption key must be present in the same directory as db_uploader_compress.pl\n";
    print "These files must be named 'key.pem' (private key) and key-public.pm (public key).\n";
    print "To create these keys, run the following from the command line:\n\n";
    print "openssl genrsa -out key.pem 2048\n";
    print "openssl rsa -in key.pem -out key-public.pem -outform PEM -pubout\n\n";
    print "When encryption occurs, the encrypted file will be password protected using a random string.\n";
    print "The password will be automatically generated and encrypted, then put in a file called 'enc.key.txt' in the same folder as db_uploader_compress.pl\n";
    print "This file, along with your private key (key.pem), will be needed to decrypt your encrypted file.\n";
    print "To decrypt the password and file, run the following from the command line:\n\n";
    print "openssl rsautl -decrypt -inkey key.pem < enc.key.txt > key.txt\n";
    print "openssl enc -aes-256-cbc -d -pass file:key.txt < ENCRYPTED_FILE_NAME > UNENCRYPTED_FILE_NAME\n\n";
    exit;
}
