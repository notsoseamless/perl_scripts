#! /usr/bin/perl

# ############################################################################ #
#
# AUTHOR : Selin George
# DATE   : 11-Jun-2009
#
# README:
#
# This code snippet is used to patch any number of data to the S3 file.
# This script is capable to patch data in any S-Record file or ULP file with
# a minimal change in the script. This script can either run in standalone
# mode or can be run through a build process.
#
# PREREQUISITE:
#
#       1. Perl 5.8.8 or latest.
#       2. Ensure write permission to the directory running this script. The
#          script uses this directory to write temporary files.
#
# HOW TO USE:
#
#       1. Open command window and get the directory where this script is
#          located.
#       2. Execute the following command:
#              perl patch_s3.pl --s3file <S3 File> --package <Package Name> --address <Address> --data <Data> --size <Size>
#
#              E.g. perl patch_s3.pl --s3file gv19912.s3 --package gv19912 --address 0x00C84000 --data PACKID --size 48
#              where,
#                S3 File - Valid Motorola S3 File
#                Package - Package Name. E.g. GV19000, X0A06A00, etc. Package
#                          Name is required only when PACKID is specified.
#                Address - Valid address in S3 File
#                Data    - Data to be written. If the keyword PACKID is given
#                          as data, the script replaces it with the pack id
#                          of format <Package Name> Jun 5 2009 11:54:10
#                Size    - Count of Data as a pair of hex digits.
#                          E.g. if the data is 0xFF113300, the size is 4.
#                          Remember the size should be given as integer.
#              Any number of address, data, size can be given using:
#              perl patch_s3.pl --s3file <S3 File> --address <Address 1> --data <Data 1> --size <Size 1> ... --address <Address n> --data <Data n> --size <Size n>
#
# KNOWN ISSUES:
#       1. Currently address can be patched only from the start of any line.
#       2. Script need to be generalised to patch any Motorola S-Record files
#          and ULP files. 
# ############################################################################ #

use strict;
use warnings;
use Getopt::Long;

# Declare local variables
my @address;
my @data;
my @size;
my @hex_string;
my @pack_string;

my $i;
my $addr;
my $s3file;
my $package;
my $match_found = 1;
my $fill1_size;
my $fill_size;
my $temp_data;
my $start_addr;
my $substring;

my %s3_data;

# Read input data
GetOptions("s3file:s"   => \$s3file,
           "package:s"  => \$package,
           "address:s"  => \@address,
           "data:s"     => \@data,
           "size:i"     => \@size);

# Assemble data
for ($i=0; $i<=$#address; $i++)
{
   $addr = hex($address[$i]);
   $s3_data{$addr}->{'data'} = $data[$i];
   $s3_data{$addr}->{'size'} = $size[$i];
}

# Read Input file 
open (S3_FILE, $s3file) or die "Unable to open S3 file $s3file!\n";

# Create output file
my $out_file = "outfile.tmp";
open (OUTFILE, ">$out_file") or die "Unable to create output file!\n";

# Read S3 file into an array
my @temp = <S3_FILE>;

# Close input file
close S3_FILE;

# Sort the S3 addresses
my @temp_address = sort {$a <=> $b} keys %s3_data;
my $num_address = $#temp_address+1;
   
foreach my $line (@temp)
{
   if ($match_found == 1 and $num_address > 0)
   {
      $start_addr  = shift @temp_address;
      $num_address--;
      
      $temp_data   = $s3_data{$start_addr}->{'data'};

      # Substitute PACKID if requested
      if ($temp_data eq "PACKID")
      {
         my @abbr = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

         # Get the current time
         (my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst) = localtime(time);

         # Adjust the year
         $year += 1900;

         # Get the time in format Jun 5 2009 11:54:10
         my $timestring = $abbr[$mon]." ".$mday." ".$year." ".$hour.":".$min.":".$sec;
         $timestring    = join('',$package,$timestring);
         my @ascii_value  = unpack("C*", $timestring);

         for ($i=0; $i<=$#ascii_value; $i++)
         {
            my $hex_value = sprintf("%X",$ascii_value[$i]);
            push @pack_string, $hex_value;
         }
         $temp_data = join('',@pack_string);
      }

      # Append zero at the end if the if the length requested exceeds the
      # actual length of data.
      $fill_size   = $s3_data{$start_addr}->{'size'};
      my $req_len = $fill_size * 2;
      my $act_len = length($temp_data);
      for($i = 0; $i < $req_len; $i += 2)
      {
         if ($i < $act_len)
         {
            push @hex_string, substr($temp_data, $i, 2);
         }
         else
         {
            push @hex_string, "00";
         }
      }
      $start_addr = sprintf ('%08X', $start_addr);
      $match_found = 0;
   }

   # Patch the data
   if ($match_found == 0)
   {
      if ($line =~ m/^S3([0-9A-F]{2})$start_addr/)
      {
         my $msg_length = hex($1) - 5;  # 5 = 4 bytes address + 1 byte checksum

         # Message spreads in one line of S3 file
         if ($msg_length > $fill_size)
         {
            $fill1_size = $fill_size * 2;
            my @patch_array  = splice(@hex_string, 0, $fill_size);
            
            my $patch_string = join('',@patch_array);
            $line =~ s/^S3([0-9A-F]{2})$start_addr[0-9A-F]{$fill1_size}/S3$1$start_addr$patch_string/;
            $match_found     = 1;
         }
         # Message spreads in more than one line of S3 file
         else
         {
            $fill1_size = $msg_length * 2;
            my @patch_array  = splice(@hex_string, 0, $msg_length);
            my $patch_string = join('',@patch_array);
            $line =~ s/^S3([0-9A-F]{2})$start_addr[0-9A-F]{$fill1_size}/S3$1$start_addr$patch_string/;
            $start_addr = hex($start_addr) + $msg_length;
            $start_addr = sprintf ('%08X', $start_addr);
            $fill_size  -= $msg_length;
            $match_found = 1 if ($fill_size <= 0);
         }
         # Fill the checksum
         my $line_length = $msg_length + 5;
         my $index = 2;
         my $checksum = 0;
         for($i = 0; $i<$line_length; $i++)
         {
            $substring = substr($line, $index, 2);
            $checksum += hex($substring);
            $index    += 2;
         }
         $checksum     = sprintf("%02X", $checksum);
         $checksum     = substr($checksum, -2) if (length($checksum) > 2);
         $checksum     = 0xFF - hex($checksum);
         $checksum     = sprintf("%02X", $checksum);
         substr($line, $index, 2, $checksum);
         print OUTFILE $line;
      }
      else
      {
         print OUTFILE $line;
      }
   }
   else
   {
      print OUTFILE $line;
   }
}
close OUTFILE;
rename $s3file, "$s3file.bak";
rename $out_file, $s3file;
