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
# Description: This program runs QAC on an input file
#
#              John Oldman (10/08/2011)
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
my $version             = "1.00";
my $current_dir         = cwd;
my $config              = "config.py";
my($source_file_name)   = shift; 
my $qac_dir             = "/tcg_cots_tool_vob/qac/QAC-7.0"



my @filelist            = ();
my @recordlist          = ();
my $count               = 0;
my $start               = 0;
my $end                 = 0;
   


# check input parameter


# check we are in the right place
if ( $current_dir !~ /6_coding/g )
{
    print "Error: This program must be run from 6_coding\n";
    exit;
}

print "Version $version\n";
print "Runs QAC on a single file\n";
$start = (times)[0];


#
# get file path from config.pl
#
print "Current directory: $current_dir\n";

open( CONFIG, $config ) or die "Can't open $config\n";
print "Scanning $config\n";
while (<CONFIG>)
{
    my($line) = $_;

    if ($line =~ /SourceFile\('([\w\/\.]+)'[\,\)]/)
    {
        # strip surrounding SourceFile(' ')
        $line =~ s/\T55File//g;
        $line =~ s/\(//g;
        $line =~ s/\)//g;
        $line =~ s/\'//g;

        # search line for source file name

    }
}
close CONFIG;
print "Found $source_file_name\n";











##############################################################################
#    SUBROUTINES
##############################################################################



##############################################################################
# step through each t55 file listing each record
##############################################################################


