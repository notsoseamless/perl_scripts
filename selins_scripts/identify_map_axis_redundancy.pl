#! /usr/bin/perl

################################################################################
# README:
################################################################################
#
# File Name :
#          identify_map_axis_redundancy.pl
#
# Author    :
#          Selin George
#
# Version   :
#          1.0, 23-Sep-2009.
# Purpose:
#          This script is used to check whether any map axis are commonly used
#          across maps.
#
# Prerequisite:
#          1. Perl v5 or higher installed.
#          2. File list generator. (generate_filelist.exe)
#
# How to Run:
#          1. Map the desired view and get <Root Dir>/gill_vob/6_coding in
#             command window.
#          2. Run generate_filelist.exe to generate the file list
#             (generated_File_list.txt)
#          3. Run "perl identify_map_axis_redundancy.pl"
#
# Output File:
#          1. output.txt
#
# Sample Output:
#          ################################################################################
#          In file Q:/blois_soft_vob/Software/Appli/i_c/_i_c/src/i_c.c, the axis
#          I_C_MDP_TRIM_MAX_BPX of I_C_INJ_BAL_DSPEED_SCALE_APM is already used.
#          ################################################################################
#
################################################################################

use strict;
use Cwd;

my $file_list_name = "generated_File_list.txt";
my $file;
my $line;
my $root;
my $x_point;
my $count = 0;
my $working_dir;
my $current_map;
my $map_type = 0;
my $map_found = 0;
my $brace_found = 0;

my @axes_pts;
my @maps;
my @temp;


open(FILE_LIST, $file_list_name) or die "Unable to open source file list \"$file_list_name\"!\n";
open(OUTFILE, ">output.txt") or die "Unable to create output file!\n";

while ($file = <FILE_LIST>)
{
   chomp $file;

   # Identify build directory "M: or other drive letter".
   if ($file =~ m/^\//)
   {
      $working_dir = cwd();
      split /\//, $working_dir;
      if ($working_dir =~ m/M/i)
      {
         $root = @_[0]."/".@_[1];
      }
      else
      {
         $root = @_[0];
      }
      $file = $root.$file;
   }   
   
   # Check for file existance
   if (-e $file)
   {
      open (SOURCE_FILE, $file) or die "Unable to open source file \"$file\"!\n";
   }
   else
   {
      print OUTFILE ">>> ERROR: The file $file doen't exists!\n";
      next;
   }

   print OUTFILE "$file :\n";

   while ($line = <SOURCE_FILE>)
   {
      chomp $line;
      
      if ($map_found == 0)
      {
         # 2D new map
         if (($line =~ m/M_MAP2D_S16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/M_MAP2D_U16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/M_MAP2D_SU16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/M_MAP2D_US16\s+([a-zA-Z0-9_]*_APM)\s*=/))
         {
            push @maps, $1;
            $current_map = $1;
            $map_found = 1;
            $brace_found = 1 if ($line =~ m/=\s*\{/);
            $map_type = 1;
            print OUTFILE "\t$current_map\n";
            next;
         }
         # 2D old map
         elsif (($line =~ m/MAP2D_S16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/MAP2D_U16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/MAP2D_SU16\s+([a-zA-Z0-9_]*_APM)\s*=/))
         {
            push @maps, $1;
            $current_map = $1;
            $map_found = 1;
            $brace_found = 1 if ($line =~ m/=\s*\{/);
            $map_type = 2;
            print OUTFILE "\t$current_map\n";
            next;
         }
         # 3D new map
         elsif (($line =~ m/M_MAP3D_S16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/M_MAP3D_U16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/M_MAP3D_SUS16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/M_MAP3D_USS16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/M_MAP3D_SUU16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/M_MAP3D_USU16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/M_MAP3D_SSU16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/M_MAP3D_UUS16\s+([a-zA-Z0-9_]*_APM)\s*=/))
         {
            push @maps, $1;
            $current_map = $1;
            $map_found = 1;
            $brace_found = 1 if ($line =~ m/=\s*\{/);
            $map_type = 3;
            print OUTFILE "\t$current_map\n";
            next;
         }
         # 3D old map
         elsif (($line =~ m/MAP3D_S16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/MAP3D_U16\s+([a-zA-Z0-9_]*_APM)\s*=/) or ($line =~ m/MAP3D_SUS16\s+([a-zA-Z0-9_]*_APM)\s*=/))
         {
            push @maps, $1;
            $current_map = $1;
            $map_found = 1;
            $brace_found = 1 if ($line =~ m/=\s*\{/);
            $map_type = 4;
            print OUTFILE "\t$current_map\n";
            next;
         }
      }

      if ($map_found == 1 and $brace_found == 0)
      {
         if ($line !~ m/^(\s|\t)*$/)
         {
            # Non-empty line
            if ($line =~ m/\s*\{/)
            {
               $brace_found = 1;
               next;
            }
            else
            {
               $map_found = 0;
               next;
            }
         }
         else
         {
            # Empty line
            next;
         }
      }

      if ($map_found == 1 and $brace_found == 1)
      {
         $count++;
         $line =~ s/\s*//g;

         # 2D new map
         if ($map_type == 1)
         {
            next if ($count != 3);
            @temp = split /\)/, $line;
            $x_point = $temp[1];
            $x_point =~ s/\(|\)|,|\[0\]//g;
            if (!grep(/\b$x_point\b/, @axes_pts))
            {
               push @axes_pts, $x_point;
            }
            else
            {
               print OUTFILE "################################################################################\n";
               print OUTFILE "In file $file, the axis $x_point of $current_map is already used.\n";
               print OUTFILE "################################################################################\n";
            }
            $map_type = 0;
            $map_found = 0;
            $brace_found = 0;
            $count = 0;
            next;
         }
         # 2D old map
         elsif ($map_type == 2)
         {
            next if ($count != 2);
            $x_point = $line;
            $x_point =~ s/\(|\)|,|\[0\]//g;
            if (!grep(/\b$x_point\b/, @axes_pts))
            {
               push @axes_pts, $x_point;
            }
            else
            {
               print OUTFILE "################################################################################\n";
               print OUTFILE "In file $file, the axis $x_point of $current_map is already used.\n";
               print OUTFILE "################################################################################\n";
            }
            $map_type = 0;
            $map_found = 0;
            $brace_found = 0;
            $count = 0;
            next;
         }
         # 3D new map
         elsif ($map_type == 3)
         {
            next if ($count < 4);
            @temp = split /\)/, $line;
            $x_point = $temp[1];
            $x_point =~ s/\(|\)|,|\[0\]//g;
            if (!grep(/\b$x_point\b/, @axes_pts))
            {
               push @axes_pts, $x_point;
            }
            else
            {
               print OUTFILE "################################################################################\n";
               print OUTFILE "In file $file, the axis $x_point of $current_map is already used.\n";
               print OUTFILE "################################################################################\n";
            }
            if ($count == 5)
            {
               $map_type = 0;
               $map_found = 0;
               $brace_found = 0;
               $count = 0;
            }
            next;
         }
         # 3D old map
         elsif ($map_type == 4)
         {
            next if ($count < 3);
            $x_point = $line;
            $x_point =~ s/\(|\)|,|\[0\]//g;
            if (!grep(/\b$x_point\b/, @axes_pts))
            {
               push @axes_pts, $x_point;
            }
            else
            {
               print OUTFILE "################################################################################\n";
               print OUTFILE "In file $file, the axis $x_point of $current_map is already used.\n";
               print OUTFILE "################################################################################\n";
            }
            if ($count == 4)
            {
               $map_type = 0;
               $map_found = 0;
               $brace_found = 0;
               $count = 0;
            }
            next;
         }
      }
   }
   $map_type = 0;
   $map_found = 0;
   $brace_found = 0;
   $count = 0;
   close SOURCE_FILE;
}

close FILE_LIST;
close OUTFILE;
