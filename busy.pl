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
# Description: print out build log
#
########################################################################
use strict;
use Win32::OLE;
use Getopt::Long;
use FileHandle;
use File::Copy;
use File::Basename;
use Cwd;

# flush buffers
$| = 1;

my $build_log	= "buildlog.txt";

my $time        = 0.25;

if(scalar @ARGV == 1)
{
	my $time = $ARGV[0];
}

open( LOG, $build_log) or die "Can't open $build_log\n";

while(1)
{
	while(<LOG>)
	{
		my($line) = $_;
		print $line;
		select(undef, undef, undef, get_time($time));
	}
}

sub get_time()
{
	my $t = $_;
		
	return $t + rand($t);

}

