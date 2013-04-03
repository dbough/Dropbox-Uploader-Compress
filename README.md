Dropbox Uploader Compress
-------------------------
v0.1.2 - Current Beta Release (2013-04-03).

Author
------
Author: Dan Bough  
Email:  daniel.bough@gmail.com  
Web:    http://www.danielbough.com  

Dropbox Uploader Author  
-----------------------
Author: Andrea Fabrizi  
Email:  andrea.fabrizi@gmail.com  
Web:    http://www.andreafabrizi.it  
Readme:  RM.ORIG

Introduction
------------
Dropbox Uploader Compress is a fork of Andrea Fabrizi's Dropbox-Uploader (https://github.com/andreafabrizi/Dropbox-Uploader).  It's native purpose is to allow folder & file compression (tar / gzip) prior to uploading to dropbox.  

It does not change (and has no intentions of changing) Dropbox-Uploader.

Requirements
------------
- Perl v5

Instructions
------------
1) First time only:  Run `./dropbox_uploader.sh` & follow the instructions.  
2) Run `./db_uploader_compress.pl --help`

    Usage:  ./db_uploader_compress.pl [OPTIONS]
    Example:  ./db_uploader_compress.pl --bu_source='foo' --bu_source_path='/home/bar/' --bu_target_folder='baz' --script_path='/usr/sbin/' --type='folder'
    
    --bu_source_file     Required:  Folder of file to back up.  Do NOT use full paths.
    --bu_source_path     Required:  Path to --bu_source_file.
    --type               Required:  Source = folder or file.
    --bu_prefix          Optional:  Backed up file/folder filename prefix. (Defaults to 'default').  This is not applicable if the --nocompress flag is set.
    --bu_target_folder   Optional:  Folder on dropbox to back up to.
    --bu_staging_folder  Optional:  Folder to stage backkup file / folder (it gets compressed here & then gets removed after it's uploaded.  Defaults to /tmp/.)
    --script_name        Optional:  Name of Dropbox Uploader shell script (defaults to dropbox_uploader.sh).
    --script_path        Required:  Path where dropbox_uploader.sh lives
    --tar                Optional:  Path to tar (defaults to /bin/tar).
    --rm                 Optional:  Path to rm (defaults to /bin/rm).
    --nocompress         Optional:  Do not compress file (tar and gzip). Folders HAVE to be compressed!
    --help               Optional:  Display this message.

*Tested On*

- Ubuntu Linux 12.04

TODO
----
- Update instructions (screencast).

Changelog
---------
- v0.1.2 - Current beta release.  Uses Dropbox Uploader v0.11.6.
- v0.1.1 - More stable release.  Operates under normal conditions.
- v0.1 - Unstable release.  Active development.


 