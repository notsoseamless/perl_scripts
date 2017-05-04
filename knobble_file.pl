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
# Description: This program does things to a named file in same dir
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

my $file_name           = "nolines.c";
my @dataline            = ();

print "Opening $file_name\n";
open( SOURCE, $file_name ) or die "Can't open $file_name\n";

open OUTPUT, '>' . "new_$file_name";


print "Searching $file_name\n";
while (<SOURCE>)
{
	my($line) = $_;
	
	print $line;

	print OUTPUT "$line\n\n";
}
close SOURCE;
close OUTPUT;


