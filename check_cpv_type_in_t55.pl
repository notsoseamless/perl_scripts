#! /usr/bin/perl

use strict;

my $input_file = "SSY_UCA31_PHASE_10.t55";
my @temp_array;

open (INFILE, $input_file) or die "Unable to open the input T55 file $input_file!\n";
open OUTFILE, ">$input_file\.txt" or die "Unable to create output file!\n";

while (<INFILE>)
{
   if (/\b^[a-zA-Z0-9_]*_CPV\b/)
   {
      @temp_array = split /;/;
      print OUTFILE "$temp_array[0],$temp_array[7]\n";
   }
}

close INFILE;
close OUTFILE;

