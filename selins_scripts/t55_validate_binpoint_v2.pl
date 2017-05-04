#! /usr/bin/perl
use strict;

# ---------------------------------------------------------------------------- #
# README:
#
# This piece of code extracts all the t55 lines from the given t55 file
# corresponding to the variables specified in file "var_list.file".
#
# PREREQUISITE:
#
#       1. Perl 5.8.8 or latest.
#       2. Variable list file var_list.file. One variable per line is allowed.
#          Comments can be inserted as a new line begining with hash symbol (#).
#          Use notepad or any text editor to edit this file.
#       3. T55 file in which the variable names need to be extracted.
#
# HOW TO USE:
#
#       1. Ensure the variable list file "var_list.file" and the input T55 file
#          are there in the same directory where this piece of code
#          (t55_get_variable.pl) is available.
#       2. Open command window and get this directory using cd command.
#       3. Execute the following command:
#              perl t55_get_variables.pl <input T55 file>
#              E.g. perl t55_get_variables.pl application_honda_dpro.t55
#       4. The t55 entries corresponding to the variables specified in
#          var_list.file will be copied in the output file "outfile.t55".
#
# ---------------------------------------------------------------------------- #

my $input_t55_file = $ARGV[0].".t55";

# Output file
my $output_t55_file = $ARGV[0]."_t55_errors.csv";
my @temp_array;

# Reading input files
open (INPUT_T55, $input_t55_file) or die "Unable to open input T55 file $input_t55_file!";

# Create output file-handle
open (OUTPUT_T55, ">$output_t55_file") or die "Unable to create output T55 file";


while (my $line=<INPUT_T55>)
{

   # Skip blank lines and commented lines
   #next if (m/^\s*$/ or m/^\*/);

   # Remove whitespaces and tabs.
   $line =~ s/\s|\t//g;

   chomp;

   #print $line;

   @temp_array = split (/;/, $line);

	my $bin_resolution = 0;
	my $resolution = 0;
        
	if ($temp_array[16] =~ m/NBIN(\d+)/)
	{
		$bin_resolution = 2**$1;
	}
	elsif ($temp_array[16] =~ m/BIN(\d+)/)
	{
		$bin_resolution = 2**-$1;
	}
	elsif ($temp_array[16] =~ m/NDEC(\d+)/)
	{
		$bin_resolution = 10**$1;
	}
	elsif ($temp_array[16] =~ m/DEC(\d+)/)
	{
		$bin_resolution = 10**-$1;
	}	

	print $temp_array[16], "\t bin_resolution = ", $bin_resolution, "\n";
	
	if ($temp_array[6] =~ m/1\/2\^(\d+)/)
	{
		$resolution = 2**-$1;
	}
	elsif ($temp_array[6] =~ m/1\/2\^-(\d+)/)
	{
		$resolution = 2**$1;
	}
	elsif ($temp_array[6] =~ m/1\/10\^(\d+)/)
	{
		$resolution = 10**-$1;
	}
	elsif ($temp_array[6] =~ m/1\/10\^-(\d+)/)
	{
		$resolution = 10**$1;
	}
	elsif ($temp_array[6] =~ m/1\/(\d+\.?\d?)/)
	{
#		if($1 != 0)
#		{
			$resolution = 1/$1;
#		}
		
	}
	else
	{
		$resolution = $temp_array[6];
	}
	
	print $temp_array[6], "\t resolution = ", $resolution, "\n\n\n";
	
	print OUTPUT_T55 $temp_array[0], ",", $temp_array[6], ",", $temp_array[16], "\n" if ( ($temp_array[16] ne "N/A") && (($bin_resolution < 0.99*$resolution) || ($bin_resolution > 1.01*$resolution)) );
	
}

        
# Close all opened filehandles
close OUTPUT_T55;
close INPUT_T55;
