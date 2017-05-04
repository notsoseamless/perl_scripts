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
#              long file names
#
#              John Oldman (18/08/2011)
#
########################################################################
use strict;
use Win32::OLE;
use Getopt::Long;
use FileHandle;
use File::Copy;
use File::Basename;
use Cwd;
use English;
use POSIX 'acos';


# Flush those buffers!
$| = 1;

#
# local variables
#
my $version             = "1.01";
my $current_dir         = cwd;
my $reader              = "readelf.exe";
my $reader_path			= "M:/task_oldmanj_gv45509/tcg_cots_tool_vob/gnu/";
my $exe_options			= "-s";
my $scratch_file_name	= "temp_scratch_file.txt";
my $outfile				= "var_name_lengths";
my $elf_name			= "oldman_45495_review.elf";
my $name_count          = 0;
my $max_variable_length = 32;
my @filelist            = ();
my @recordlist          = ();
my $count               = 0;
my $long_count          = 0;
my $start               = 0;
my $end                 = 0;



if ( $current_dir !~ /6_coding/g )
{
    print "Error: This program must be run from 6_coding\n";
    exit;
}

print "Routine to find variable names longer than $max_variable_length characters\n";
print "Version $version\n";
#print "May take some time, okay to continue  [Y/N]? ";
#my $key = getc(STDIN);
#($key =~ /y|Y/ ) or die("Not confirmed. Exiting...\n");
$start = (times)[0];

print "Current directory: $current_dir\n";

#report_reader_version();

print "Run $reader to get variable names\n";
# build the run string
my $run_string  = "$reader_path$reader $exe_options $elf_name > $scratch_file_name";

# call executable
#print "Run : $run_string\n";
my $temp = qx($run_string);
#print "$temp\n";

get_data_from_scratchfile();

print "Sort records\n";
@recordlist = sort(@filelist);

measure_file_names();

print "End\n";




##############################################################################
#    SUBROUTINES
##############################################################################



#
# dump reader version info
#
sub report_reader_version()
{
	print "Using elf reader:\n";
	my $run_string  = "$reader_path$reader -v";
	my $temp = qx($run_string);
	print "$temp\n";
}



#
# gets all file and variable names from scratch file
#
sub get_data_from_scratchfile()
{
	print "Open tempoary file $scratch_file_name\n";
	open( INFILE, $scratch_file_name ) or die "Can't open $scratch_file_name\n";
	print "Scan $scratch_file_name\n";

	while (<INFILE>)
	{
	    my @dataline = ();
        @dataline    =  split( " ", $_ );                   # split line using space
    	$dataline[7] =~ s/^\_/ /;                           # strip leading underscore
    	my $sstr = ".c";
    	$dataline[7] =~ s/$[\.c]/ /;                        # strip .c extents
        $filelist[$count] = $dataline[7];                   # store in filelist
	    $count ++;
	}
	close INFILE;
	print "Delete tempoary file\n";
	unlink($scratch_file_name); 
}



#
# measure collected file names in file list
#
sub measure_file_names()
{
	# prepare out file
	my $outfile_name = get_file_name($outfile);
	open (OUTFILE, ">$outfile_name") or die "Failed to open $outfile_name";

	for(my $i=1; $i<$count; $i++)
	{
		my $str_len = length($recordlist[$i]);
		$str_len--;

		if($str_len > $max_variable_length)
		{
			$long_count++;
			#print "$recordlist[$i]    $str_len\n";
	        print OUTFILE "NAME: $recordlist[$i]                  LENGTH: $str_len\n";		
	    }
	}
	close OUTFILE;
	print "Found $long_count suspects, stored in $outfile_name\n"; 
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







