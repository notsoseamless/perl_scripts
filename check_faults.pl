#!/usr/bin/perl
########################################################################
#                    Delphi Diesel Systems
#*
#*                    This document is the property of
#*                    Delphi Diesel Systems
#*                    It must not be copied (in whole or in part)
#*                    or disclosed without prior written consent
#*                    of the company. Any copies by any method
#*                    must also include a copy of this legend.
#######################################################################
# 
# Description: This program verifies that all faults listed within 
#              config.py are actually referenced in the code.
#
#              Eddie Basson (10/03/10)
#
########################################################################

use strict;
use Win32::OLE;
use Getopt::Long;
use FileHandle;
use File::Copy;
use File::Basename;
use Cwd;


# Flush those buffers!
$| = 1;

my $debug               = 0;  
my $current_dir         = cwd;
my @dataline            = ();
my @faults              = ();
my %faults_found        = ();
my $found               = 0;
my $count               = 0;
my $start               = 0;
my $end                 = 0;



################################################################
# START OF: User-defined values. All these below are configurable!
################################################################


# List of file extensions to be searched through (everything else is ignored). 
# Edit this list as required.
#
my @file_extensions =
(
    "\.c", 
    "\.h", 
);

#
# List of directories to ignore. Remembering that some files are symbolic links to 
# other files, and that sCons makes copies of files during the build process, there's 
# little point in processing the same files twice. Edit this list as required. 
#
my @ignore_dirs =
(
    "out",
    "6_coding",
    "include",
    "autogen",
    "lost\+found",
);


################################################################
# END OF: User-defined values.
################################################################


#
# Prototypes.
#
sub scan_directory();
sub report_on_file();

if ( $current_dir !~ /6_coding/g )
{
    print "Error: This program must be run from 6_coding\n";
    exit;
}


print "This program analyses the fault entries within config.py and checks\n";
print "for any that are not referenced in the code. Approximate\n";
print "running time for this program is 25 minutes. Note, no files or code is\n";
print "altered. This program only reports on it's findings.\n";

print "\nOkay to continue  [Y/N]? ";
my $key = getc(STDIN);
($key =~ /y|Y/ ) or die("Not confirmed. Exiting...\n");
$start = (times)[0];


print "Current directory is: $current_dir\n";
open( CONFIG_PY, "config.py" ) or die "Can't open config.py\n";
while (<CONFIG_PY>)
{
    next if /^(\s)*$/;               # Skip blank lines.
    next if ( /^\#/ );               # Skip comments.
    if ( /NewFault/g )
    {
        @dataline = split( ",", $_ );
        $dataline[0] =~ s/.*(\'.*\').*/$1/;               # strip any supplementary fields.
        $dataline[0] =~ s/\'//g;                          # strip surrounding inverted commas
        $dataline[0] =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;   # strip all leading and trailing white space.
        $dataline[0] = $dataline[0] . "_FLT_CFG";
        $faults_found{uc($dataline[0])} = 0;
        $count++;
    }
    if ( /FaultGroup/g )
    {
        @dataline = split( ",", $_ );
        $dataline[0] =~ s/.*(\'.*\').*/$1/;               # strip any supplementary fields.
        $dataline[0] =~ s/\'//g;                          # strip surrounding inverted commas
        $dataline[0] =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;   # strip all leading and trailing white space.
        $dataline[0] = $dataline[0] . "_FLT_GRP_CFG";
        $faults_found{uc($dataline[0])} = 0;
        $count++;
    }
}

print "$count fault entries found within config.py\n";
&scan_directory(".");

$count = 0;
print "\n\n";
foreach my $key ( keys %faults_found ) 
{     
    $found = 0;
    if ( $faults_found{$key} == 0 )
    {
        $count++;
        printf "Fault %-40s: %s\n", $key, "NOT found!";
    }
}
if ( 0 == $count )
{
    print "All entries in config.py are valid and are referenced in the code.\n";
}
else
{
    print "$count entries (listed above) are redundant and are NOT referenced in the code.\n";
}
$end = (times)[0];
printf "Program ran in %d mins %d secs\n", ($end - $start)/60, ($end - $start)%60; 


##############################################################################
#    SUBROUTINES
##############################################################################



#
# A simple "walk the directories" routine. Note, this routine is recursive to
# cater for all the sub-directories.
#
sub scan_directory()
{
    my ($workdir)    = shift; 
    my ($startdir)   = &cwd; # keep track of where we began
    my $valid_entry  = 0;
    
    
    chdir($workdir)   or die("ERROR:   Unable to enter dir $workdir\n");
    opendir(DIR, ".") or die("ERROR:   Unable to open $workdir\n");
    print "DIRECTORY: $startdir...\n";
    my @names = readdir(DIR);
    closedir(DIR);
 
    foreach my $name (@names)
    {
        $valid_entry = 1;   # Default to a valid entry at the top of this main loop.
        next if ($name eq "."); 
        next if ($name eq "..");

        # Is the current engry a directory, and is it in the list of those we should ignore?        
        foreach my $ignore(@ignore_dirs)
        {
            if ( -d $name && $name eq $ignore )
            {
                # This directory is to be ignored.
                if (1 == $debug ) { print "$name matches item in ignore_dirs array. Skipping!\n"; }
                $valid_entry = 0;
                last;
            }
        }
        next if ( 0 == $valid_entry );
        
        if ( -f $name )
        {
            # Is the current entry a file, and is it in the list of those we are interested in? 
            $valid_entry = 0;  # Assume for the moment that we won't find a match.        
            foreach my $extension(@file_extensions)
            {
                if ( $name =~ /$extension$/ )
                {
                    print "    Parsing $name\n";
                    $valid_entry =  1;
                    last;
                }
            }
        }
        next if ( 0 == $valid_entry );

        
        # If we get here, we have either a valid file or a valid directory.
        if (-d $name)    # Is this a directory?
        {
            if (1 == $debug ) { print "Calling scan_directory() on $name!\n"; }
            &scan_directory($name);    # Note, this call is recursive.
            next;
        }

        &report_on_file($name);
    }
    chdir($startdir) or die("ERROR:   Unable to change to dir $startdir\n");
}

sub report_on_file()
{
    my($name)  = shift;
    my $found  = 0;
    my $str    = "";

    open( F, $name ) or die("ERROR:   Unable to open file $name\n");
    while (<F>)
   	{
        next if /^(\s)*$/;               # Skip blank lines.
        foreach my $fault ( keys %faults_found ) 
        {
            if ( $_ =~ /$fault/g )
            {
                # Mark this fault as found within the hash.
                $faults_found{$fault} = 1;
                last;
            }                
        }
    }
    close( F ); 
    return 1;
}

