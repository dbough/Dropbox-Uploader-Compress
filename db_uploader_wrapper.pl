#!/usr/bin/perl
use strict;
use Getopt::Long;
use POSIX qw(strftime);

# Configurable variables
my $backupSourceFile; # Folder or file to back up.  Do not use FULL names.
my $backupSourcePath; # Path that $backupSourceFile lives under.
my $buPrefix = "default"; # Backed up file/folder filename prefix.
my $buTargetFolder; # Folder on dropbox to back up to.
my $buStagingFolder = "/tmp/"; # Local folder to stage your backup.  Used as a container to compress the backup.
my $dbuScriptName = "dropbox_uploader.sh"; # Name of Dropbox_Uploader script.
my $dbuScriptPath; # Path where Dropbox_Uploader lives.
my $tar = "/bin/tar"; # Path to the tar exe.
my $rm = "/bin/rm"; # Path to the rm exe.
my $compress; # Compress files / folders before uploading?

my $options = GetOptions (
	# "length=i" => \$length,    # numeric
    # "file=s"   => \$data,      # string
	"compress"  => \$compress	   # flag
);  

if( !$options ) {
	readme();
}

# Other variables.
my $time = strftime "%Y-%m-%d_%H-%M-%S", localtime; # Formatted time (to use in the backed up file/folder name).
my $filename = $buPrefix . "_" . "backup_" . $time . ".tgz";
my $backupTarget =  $buTargetFolder . $filename;
my $dbuExe = $dbuScriptPath . $dbuScriptName;

system($tar . " -cvzf " . $buStagingFolder . $filename . " " . $backupSourcePath . $backupSourceFile);
system($dbuScriptPath . $dbuScriptName . " upload " . $buStagingFolder . $filename . " " . $backupTarget);
system($rm . " " . $buStagingFolder . $filename);

sub readme{
	print "Hi\n";
	exit;
}



