#!/usr/bin/perl
########################################################################
#                   Delphi Diesel Systems
#
#                   This document is the property of
#                   Delphi Diesel Systems
#                   It must not be copied (in whole or in part)
#                   or disclosed without prior written consent
#                   of the company. Any copies by any method
#                   must also include a copy of this legend.
#######################################################################
# 
# Description: Crude S-Record Analyser
#
#              John Oldman 30/04/2012
#
########################################################################
use strict;
use Win32::OLE;
use Getopt::Long;
use FileHandle;
use File::Copy;
use File::Basename;
use Cwd;

# flush buffers!
$| = 1;

#
# local variables
#
my $version             = "0.0a";
my $debug               = 1;
my $instring		= "";
my $record_type         = "";
my $description         = "";
my $record_length 	= 0;
my $record_address	= 0;
my $record_data		= "";
my $record_checksum	= 0;
my $true_checksum       = 0;

# validate input
if(scalar @ARGV != 1)
{
	die "\nUsage: perl srec_cs.pl <s-record>\n";
}
else
{
	$instring = $ARGV[0];
}

print "\n\n\nDELPHI DIESEL SYSTEMS " . chr(0xB8) . "2012\n";
print "S-Record Analyser - $version\n\n";

# identify record type
if( $instring =~ /^(S0)/i )
{
	$record_type     = "S0";
	$description     = "Header for block of S-records";
	$record_length   = substr( $instring, 2, 2 ); 
}
elsif( $instring =~ /^(S1)/i )
{
	$record_type     = "S1";
	$description     = "Data and 2-byte address";
	$record_length   = substr( $instring, 2, 2 ); 
	$record_address  = substr( $instring, 4, 4 ); 
        $record_data     = substr( $instring, 8, (2 * hex($record_length)) - 6);
        $record_checksum = substr( $instring, (2 * hex($record_length)) + 2, 2); 
	$true_checksum   = calc_checksum(substr($instring, 2, (2 * hex($record_length))));
}
elsif( $instring =~ m/^S2/i )
{
	$record_type     = "S2";
	$description     = "Data and 3-byte address";
	$record_length   = substr( $instring, 2, 2 ); 
	$record_address  = substr( $instring, 4, 6 ); 
        $record_data     = substr( $instring, 10, (2 * hex($record_length)) - 8);
        $record_checksum = substr( $instring, (2 * hex($record_length)) + 2, 2); 
	$true_checksum   = calc_checksum(substr($instring, 2, (2 * hex($record_length))));
}
elsif( $instring =~ m/^S3/i )
{
	$record_type     = "S3";
	$description     = "Data and 4-byte address";
	$record_length   = substr( $instring, 2, 2 ); 
	$record_address  = substr( $instring, 4, 8 );
        $record_data     = substr( $instring, 12, (2 * hex($record_length)) - 10);	
        $record_checksum = substr( $instring, (2 * hex($record_length)) + 2, 2); 
	$true_checksum   = calc_checksum(substr($instring, 2, (2 * hex($record_length))));
}
elsif( $instring =~ m/^S5/i )
{
	$record_type    = "S5";
	$description    = "Number of S1, S2 and S3 records a block. Count in address field. No data";
	$record_length  = substr( $instring, 2, 2 ); 
}
elsif( $instring =~ m/^S7/i )
{
	$record_type    = "S7";
	$description - "Termination for S3 records. address may contain the 4-byte address
of the instruction to which control is passed. No data";
	$record_length  = substr( $instring, 2, 2 ); 
}
elsif( $instring =~ m/^S8/i )
{
	$record_type    = "S8";
	$description - "Termination for S2 records. address may contain the 4-byte address
of the instruction to which control is passed. No data";
	$record_length  = substr( $instring, 2, 2 ); 
}
elsif( $instring =~ m/^S9/i )
{
	$record_type    = "S9";
	$description    = "Termination for S1 records. address may contain the 4-byte address of the instruction to which control is passed. No data";
	$record_length  = substr( $instring, 2, 2 ); 
}
else
{
	die "\nERROR: $instring not an S-record\n";
}



# output report
print "Analysis of $instring:\n";
print "type        : $record_type\n";
print "description : $description\n"; 
print "length      : 0x$record_length bytes\n";
print "address     : 0x$record_address\n";
print "data        : 0x$record_data\n";
print "checksum    : 0x$record_checksum\n";

if(lc($true_checksum) ne lc($record_checksum))   # all lower case compare
{
	print "checksum error: replace last 0x$record_checksum by 0x$true_checksum\n"; 
}

print "\n\n\n";

# subroutines ################################################################


sub calc_checksum($)
{
	my @data_list = split( /(..)/, @_[0] );	# split into pairs
	my $length    = @data_list;		# count pairs
	my $checksum  = 0;

	for(my $i=0; $i<$length; $i++)
	{
		$checksum += hex(@data_list[$i]);
	}

	$checksum = (~($checksum));		# compliment
	$checksum = sprintf("%x", $checksum);	# convert to hex
	$checksum = substr($checksum, -2, 2);	# keep the low octet

	return $checksum;
}








