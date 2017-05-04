#!/usr/bin/perl
########################################################################
#                    Delphi Diesel Systems
#*
#*                   This document is the property of
#*                   Delphi Diesel Systems
#*                   It must not be copied (in whole or in part)
#*                   or disclosed without prior written consent
#*                   of the company. Any copies by any method
#*                   must also include a copy of this legend.
#######################################################################
# 
# Description: This program searches the t55 files looking for 
#              duplicate entries
#
#              John Oldman (27/07/2011)
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

#
# local variables
#
my $version             = "1.02";
my $current_dir         = cwd;
my $config              = "config.py";
my $outfile             = "t55_duplicates";
my @filelist            = ();
my @recordlist          = ();
my $count               = 0;
my $start               = 0;
my $end                 = 0;

if ( $current_dir !~ /6_coding/g )
{
    print "Error: This program must be run from 6_coding\n";
    exit;
}

print "Version $version\n";
print "Simple search in t55 files for duplicate variable names\n";
#print "May take some time, okay to continue  [Y/N]? ";
#my $key = getc(STDIN);
#($key =~ /y|Y/ ) or die("Not confirmed. Exiting...\n");
$start = (times)[0];


#
# get list of t55 file names from config file
#
print "Current directory: $current_dir\n";

open( CONFIG, $config ) or die "Can't open $config\n";
print "Scanning $config\n";
while (<CONFIG>)
{
    my($line) = $_;

    if ($line =~ /T55File\('([\w\/\.]+)'[\,\)]/)
    {
        # strip surrounding T55File(' ')
        $line =~ s/\T55File//g;
        $line =~ s/\(//g;
        $line =~ s/\)//g;
        $line =~ s/\'//g;

        # put into indexed list
        $filelist[$count] = $line;
        $count ++;
    }
}
close CONFIG;
print "Listed $count t55 file(s)\n";


#
# process each t55 file
#
print "Processing files\n";
foreach my $filepath (@filelist)
{
    process_file($filepath);
}

print "Sorting records\n";
@recordlist = sort(@recordlist);


print "Searching for duplicates\n";

my $duplicate_count = 0;

my $outfile_name = get_file_name($outfile);

open (OUTFILE, ">$outfile_name") or die "Failed to open $outfile_name";

my $array_size=@recordlist;
for(my $i=1; $i<$array_size; $i++)
{
    if($recordlist[$i] eq $recordlist[$i-1])
    {
        # debug    
        # print "Duplicate: $recordlist[$i]\n";
        print OUTFILE "Duplicate: $recordlist[$i]\n";
        $duplicate_count++;
    }
}
close OUTFILE;

if(0 != $duplicate_count)
{
    printf "Found %d suspects, stored in $outfile_name\n", $duplicate_count ; 
}
else
{
    printf "No duplicates found\n";
    unlink($outfile_name);
}

$end = (times)[0];
printf "Program ran in %d mins %d secs\n", ($end - $start)/60, ($end - $start)%60; 

print "End\n";




##############################################################################
#    SUBROUTINES
##############################################################################



##############################################################################
# step through each t55 file listing each record
##############################################################################
sub process_file()
{
    my($path) = shift;
 
    open( T55_FILE, $path ) or die "Can't open $path\n";

    # step through each line of the t55 file

	# debug
    #print "Processing: $path";

    my @dataline = ();

    while (<T55_FILE>)
    {
        next if /^(\s)*$/;                                # Skip blank lines using ';'.
        next if ( /^\#/ );                                # Skip # comments.
        next if ( /^\*/ );                                # Skip * comments.
        next if ( /^\FEATURE/ );                          # Skip FEATURE lines.
        next if ( /^\VERSION/ );                          # Skip VERSION lines.
        @dataline = split( ";", $_ );                     # split line using semicol;ons
        $dataline[0] =~ s/.*(\'.*\').*/$1/;               # strip any supplementary fields.
        $dataline[0] =~ s/\'//g;                          # strip surrounding inverted commas
        $dataline[0] =~ s/\;//g;                          # strip surrounding semi-colons
        $dataline[0] =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;   # strip all leading and trailing white space.
        push(@recordlist, $dataline[0]);                  # push the t55 name into the array
    }
    close T55_FILE;
}


#
# If suggested file exists, increments suffix until an unused filename is found
#
sub get_file_name()
{
    my($base_name)    = shift;    
    my $suffix        = 0;    
    my $new_file_name = $base_name . "_" . $suffix . ".txt";
    
    while(-e $new_file_name)
    {
	$new_file_name = $base_name . "_" . $suffix++ . ".txt";
    }
    
    return $new_file_name;
}
