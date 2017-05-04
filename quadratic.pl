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
# Description: Script makes start up faster
#
#              John Oldman 10/11/2011
#
########################################################################
# DATE       # DESCRIPTION                                       #     # 
#------------#---------------------------------------------------#-----#
# 10-11-2011 # Initial version                                   # JRO #                 
#            #                                                   #     #                 
#            #                                                   #     #                 
#            #                                                   #     #                 
#            #                                                   #     #                 
#            #                                                   #     #                 
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
my $version             = "0.01";
my $a_param             = 0;
my $b_param             = 0;
my $c_param             = 0;
my $x1                  = 0;
my $x2                  = 0;
my $a_sign              = "+";
my $b_sign              = "+";
my $c_sign              = "+";


# make sure we have a CR number
if(scalar @ARGV != 3)
{
    die "\nUsage: quadratic A B C\n";
}

print "Quadratic $version\n";
print "=========\n";

$a_param = $ARGV[0];
$b_param = $ARGV[1];
$c_param = $ARGV[2];

print_input();

my $temp1 = sqrt(($b_param * $b_param) - (4 * $a_param * $c_param));

$x1 = (-$b_param + $temp1)/(2*$a_param);

$x2 = (-$b_param - $temp1)/(2*$a_param);

print "x = $x1 and $x2\n";




sub print_input()
{
	# format text
	if(0 <= $a_param)
	{
		$a_sign = "+";
	}
	else
	{
		$a_sign = "";
	}

	if(0 <= $b_param)
	{
		$b_sign = "+";
	}
	else
	{
		$b_sign = "";
	}

	if(0 <= $c_param)
	{
		$c_sign = "+";
	}
	else
	{
		$c_sign = "";
	}


	my $tempa;
	if(1 < $a_param)
	{
		$tempa = $a_param;
	}
	else
	{
		$tempa = "";
	}


#	my $tstr = "\nInput:" . $tempa . "x^2" . $b_sign$b_param . "x" . $c_sign$c_param . "\n\n";

	my $tstr = "\n\nInput: " . $tempa . "x^2 " . $b_sign . $b_param . "x " . $c_sign.  $c_param . "\n\n";

	print $tstr;


}



