#! /usr/bin/perl

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

$input_t55_file = $ARGV[0];
$input_var_file = "var_list.file";

# Output file
$output_t55_file = "outfile.t55";

# Reading input files
open (INPUT_T55, $input_t55_file) or die "Unable to open input T55 file $input_t55_file!";
open (VAR_LIST, $input_var_file) or die "Unable to open file $input_var_file!";

# Create output file-handle
open (OUTPUT_T55, ">$output_t55_file") or die "Unable to create output T55 file";

while (<VAR_LIST>)
{
	next if /^#/;        # Skips all commented lines.
	next if /^\s+$/;     # Skips all blank lines.
	push @var_array, $_; 
}

while ($line=<INPUT_T55>)
{
	foreach $var (@var_array)
	{
		chomp $var;
		print OUTPUT_T55 $line if ($line =~ m/^\b$var\b/);
	}
}

print "\nThe variables processed are:\n\n";
foreach $var (@var_array)
{
	print "$var\n";
}

# Close all opened filehandles
close OUTPUT_T55;
close INPUT_T55;
