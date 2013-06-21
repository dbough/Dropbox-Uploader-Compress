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
use File::Basename;

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
my $mv = "/bin/mv";                         # Path to mv exe.
my $download;                               # Print help for download.  Easiest to use dropbox_uplooader.sh
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
    "download"    => \$download,                    # optional
    "help" => \$help,								# optional
    "encrypt" => \$encrypt,                         # optional
    "q" => \$quiet                                  # optional
); 

# Set variables based on flags passed etc.
$compressType = get_compression_type();
$compressPath = get_compression_path();
$fileSuffix = get_file_suffix();
$suppressOutput = get_suppress_output();
my $dbuExe = $dbuScriptPath . $dbuScriptName;

# Other variables
my $time = strftime "%Y-%m-%d_%H-%M-%S", localtime; 
my $filename = $buPrefix . "_" . "backup_" . $time . "." . $fileSuffix;
my $password_file = "pass_" . $time . ".txt";
my $openssl = "/usr/bin/openssl";      
my $backupTarget;

# If download is set, print help for download.
if ( $download ) {
    download_help();
}

# Format the target folder (add a / at the end)
$buTargetFolder = $buTargetFolder . "/";

# Verify our required flags are set.  If not, send instructions to the screen.
if ( !$backupSource || $help ) { readme(); }

if ( !$nocompress ) {
    $backupTarget =  $buTargetFolder . $filename;
} else {
    $backupTarget = get_file_name($backupSource);
}

# Determine if the source is a file or a folder
if ( -f $backupSource ) {
    $backupSourceType = 'file';
    # Determine the parent directory of the file
    if ( !$nocompress ) {
        $backupSourceFolder = get_folder_name($backupSource);
    }
} elsif ( -d $backupSource ) {
    $backupSourceType = 'folder';

    # If the user didnt include a trailing "/" in the backup source name, add it.
    if (substr($backupSource, -1) ne '/'){
        $backupSource .= "/";
    }

    # For relative paths when using TAR
    $backupSourceFolder = $backupSource;

    # If the nocompress flag is set, exit;
    if ( $nocompress ) {
        print "You must compress folders!  Remove the --nocompress flag please.\n";
        exit;
    }

    # Determine if folder is empty
    if ( is_folder_empty($backupSource) ) {
        print "Folder is empty!  Put some stuff in it first!\n";
        exit;
    }

    # If compression type = zip, we need to make sure it knows to compress all files in the folder
    # This is probably a confusing way to do this though.
    if ( $compressType eq 'zip' ) {
        $backupSource .= "* ";
    }
}

# If the ecnrpyt flag is set, create a random password and store it in $password_file
if ( $encrypt ) {
    my $result = encrypt_password();
    if ( !$result ) {
        print "Password file missing.  Try again.\n";
        exit;
    }
}

# Process file / folder based on compression type and send it to Dropbox.
switch ( $compressType ) {
    case "tar" { tar_file() }
    case "zip" { zip_file() }
    else { no_compress() }
}

################### SUBS BELOW ####################

# Allows the omission of compression type flag.
# Defaults to 'tar' unless the nocompress flag is set 
sub get_compression_type 
{
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

# Default paths to the compression software
sub get_compression_path 
{
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

# Default file suffixes determined by the compression type
sub get_file_suffix 
{
    # If we're encrypting, add another file extension.
    my $enc;
    if ( $encrypt ) {
        $enc = "enc.";
    }
    if ( $fileSuffix ) {
        return $enc . $fileSuffix;
    } elsif ( $compressType eq 'zip' ) {
        return $enc . "zip";
    } elsif ( $compressType eq 'tar' ) {
        return $enc . "tgz";
    } else {
        return $enc . "";
    }
}

# Dirty way to silence everything if required
sub get_suppress_output 
{
    if ( $quiet ) {
        return " > /dev/null 2>&1"
    } else {
        return "";
    }
}

# If a directory is empty, we don't bother processing it
sub is_folder_empty 
{
    my $dirname = shift;
    opendir(my $dh, $dirname) or die "Not a directory";
    return scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) == 0;
}

sub get_folder_name 
{
    my $file = shift;;
    return dirname($file);
}

# If we're not compressing, we only need the file name (will be sent to Dropbox as this).
sub get_file_name 
{
    my $file = shift;
    my @paths = split(/\//,$file);
    return  @paths[-1];
}

# Compress with tar / gzip
sub tar_file 
{
    # Verify the nocompress flag is not set.  It shouldn't be - this is just a precaution.
    if ( !$nocompress ) {
        # Compress file
        system($compressPath . " czfP " . $buStagingFolder . $filename . " -C " . $backupSourceFolder . " " . $backupSource . " " . $suppressOutput);
        # Encrypt if needed
        if ( $encrypt ) { 
            encrypt_file($buStagingFolder . $filename);
            encrypt_help($filename);
        }
        # Send to Dropbox
        system($dbuScriptPath . $dbuScriptName . " upload " . $buStagingFolder . $filename . " " . $backupTarget . " " . $suppressOutput);
        # Delete temp file
        system($rm . " " . $buStagingFolder . $filename) . " " . $suppressOutput;
    } else {
        print "The --nocompress flag is set. Cannot continue (you are trying to tar/gzip a file.)  For help, run ./db_uploader_compress --help\n\n";
        exit;
    }
}

# Compress with zip
sub zip_file 
{
    # Verify the nocompress flag is not set.  It shouldn't be - this is just a precaution.
    if ( !$nocompress ) {
        # Compress file
        system($compressPath . " -r " . $buStagingFolder . $filename . " " . $backupSourceFolder . " " . $backupSource . " " . $suppressOutput);
        # If encryption is selected, do so now.
        if ( $encrypt ) { 
            encrypt_file($buStagingFolder . $filename);
            encrypt_help($filename);
        }
        # Send file to Dropbox
        system($dbuScriptPath . $dbuScriptName . " upload " . $buStagingFolder . $filename . " " . $backupTarget . " " . $suppressOutput);
        # Delete temp file.
        system($rm . " " . $buStagingFolder . $filename);
    } else {
        print "The --nocompress flag is set. Cannot continue (you are trying to tar/gzip a file.)  For help, run ./db_uploader_compress --help\n\n";
        exit;
    }
}

# Do no compress
sub no_compress 
{
    # If this is a folder throw an error.  This should never happen - this is a precaution.
    if ( $backupSourceType eq 'folder' ) {
        print "You must compress folders.  Please remove the --nocompress flag.\n";
        exit;
    }
    # Encrypt if needed
    if ( $encrypt ) { 
            encrypt_file($backupSource);
    }
    # Send file to Dropbox
    system($dbuScriptPath . $dbuScriptName . " upload " . $backupSource . " " . $backupTarget . " " . $suppressOutput);
}

# Generates a random password and file, used for encryption
sub encrypt_password
{
    # Generate random password and put it in a file.
    my $password = `openssl rand -base64 32`;
    open (FH, ">$password_file") or die $!;
    print FH $password;
    close FH;
    if ( -e $password_file ) {
        return 1;
    } else {
        return 0;
    }
}

# Encrypt a file 
sub encrypt_file
{
    my $file = shift;
    my $tmpFile = $file . "1";
    system($openssl . " enc -aes-256-cbc -in " . $file . " -out " . $tmpFile . " -pass file:$password_file " . $suppressOutput);
    system("$mv $tmpFile $file");
}

# If the -download flag is passed, just print instructions.
sub download_help
{
    print "Please run dropbox_uploader.sh to download a file.\n\n";
    print " ./dropbox_uploader.sh download [REMOTE_FILE/DIR] <LOCAL_FILE/DIR>\n\n";
    exit;
}

# Help / instructions
sub readme
{
	print "Dropbox Uploader Compress v0.2.0\n";
	print "Dan Bough - daniel.bough\@gmail.com\n\n";
	print "Usage:  ./db_uploader_compress.pl [OPTIONS]\n";
    print "Example:  ./db_uploader_compress.pl -bu_source='/home/bar/foo'\n\n";
    print "-bu_source          Required:  Folder of file to back up.  Use full paths.\n";
    print "-bu_prefix          Optional:  Backed up file/folder filename prefix. (Defaults to 'default').  This is not applicable if the --nocompress flag is set.\n";
    print "-bu_staging_folder  Optional:  Folder to stage backkup file / folder (it gets compressed here & then gets removed after it's uploaded.  Defaults to /tmp/.)\n";
    print "-bu_target_folder   Optional:  Folder on dropbox to back up to.\n";
    print "-compression_type   Optional:  Valid compression types:  tar and zip.\n";
    print "-compression_path   Optional:  Path to compression file.  Default:  /bin/tar (tar), /usr/bin/zip (zip).\n";
    print "-download           Optional:  Print download instructions.\n";
    print "-file_suffix        Optional:  Custom file suffix.  Used to obfuscate file types.\n";
    print "-encrypt            Optional:  Encrypt file\n";
    print "-help               Optional:  Display this message.\n";
    print "-nocompress         Optional:  Do not compress file. Folders HAVE to be compressed!\n";
    print "-q                  Optional:  Suppress outout.\n";
    print "-rm                 Optional:  Path to rm (defaults to /bin/rm).\n";
    print "-script_name        Optional:  Name of Dropbox Uploader shell script (defaults to dropbox_uploader.sh).\n";
    print "-script_path        Optional:  Path where dropbox_uploader.sh lives (defaults to local directory).\n\n";
	exit;
}

# If encryption is used, display decryption help to the user.  Also writes it to a file for future reference.
sub encrypt_help
{
    my $file = shift;
    my $unencrypted = $file;
    $unencrypted =~ s/.enc//i;
    my $log = "DECRYPT_INSTRUCTIONS_" . $file . ".txt";

    print "\nIMPORTANT:  Decryption instructions for $file located in $log.\n\n";

    open FH, ">$log";
    print FH "\n!!!DO NOT LOSE THIS!!!\n\n";
    print FH "======= Encryption help for $file =======\n\n";
    print FH "You have chosen to encrypt your file.  The extension '.enc' will be added before the normal file extension.\n";
    print FH "A password file called '$password_file' has been created for you and will be needed to decrypt your file.\n";
    print FH "To decrypt, run the following:\n\n";
    print FH " openssl enc -d -aes-256-cbc -in $file -out $unencrypted -pass file:$password_file\n\n";
    print FH "This assumes your files are in the same path as db_uploader_compress.pl.  Add paths if necessary.\n";
    close FH;
}
