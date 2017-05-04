#! /usr/bin/perl

use strict;
use Cwd;

my $count;
my $file;
my $line;
my @temp;
my $root;
my $fn_found = 0;
my @res_line;
my $need_open_brace = 0;
my $need_close_brace = 0;
my $brace_count;
my $working_dir;
my $skip = 0;
my %maths_data;
my $file_list_name = "generated_File_list.txt";
my $out_file_name = "maths_count.txt";
my $waiting4fn = 1;

open(FILE_LIST, $file_list_name) or die "Unable to open source file list \"$file_list_name\"!\n";

while ($file = <FILE_LIST>)
{
   chomp $file;

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
   
   open (SOURCE_FILE, $file) or die "Unable to open source file \"$file\"!\n";
   $count = 0;
   $need_open_brace = 0;
   $need_close_brace = 0;
   $brace_count = 0;
   $fn_found = 0;

   while ($line = <SOURCE_FILE>)
   {
      chomp $line;
      next if ($line =~ m/^#/);
      next if (($skip == 1) and ($line !~ m/\*\//));

      if (($skip == 1) and ($line =~ m/\*\//))
      {
         @temp = split /\*\//, $line;
         $skip = 0;
         $line = $temp[1];
      }

      if ($line =~ m/\/\*/)
      {
         @temp = split /\/\*/, $line;
         $line = $temp[0];
         $skip = 1 if ($temp[1] !~ m/\*\//);
      }

      if ($fn_found == 0)
      {
         if ($need_open_brace == 1)
         {
            next if ($line !~ m/\{/);
            if ($line =~ m/\{/)
            {
               $fn_found = 1;
               $need_open_brace = 0;
               @res_line = split /\{/, $line;
               $line = $res_line[1];
               $need_close_brace = 1;
               $brace_count = 1;
            }
            else
            {
               $need_open_brace = 0;
               $need_close_brace = 0;
            }
         }
         if ($need_close_brace == 0)
         {
            next if ($line !~ m/[a-zA-Z0-9_](\s|\t)*\([a-zA-Z0-9_]?|\+\)(\s|\t)*/);
            @temp = split /[a-zA-Z0-9_](\s|\t)*\([a-zA-Z0-9_]?|\+\)(\s|\t)*/, $line;
            if ($temp[1] =~ m/\{/)
            {
               $fn_found = 1;
               @res_line = split /\{/, $temp[1];
               $line = $res_line[1];
               $need_close_brace = 1;
               $brace_count = 1;
            }
            else
            {
               $need_open_brace = 1;
            }
         }
      }

      next if ($fn_found == 0);

      if ($need_close_brace == 1)
      {
         while ($line =~ m/(\{|\})/g)
         {
            $brace_count++ if ($1 eq "{");
            $brace_count-- if ($1 eq "}");
            if ($brace_count == 0)
            {
               $need_close_brace = 0;
               $fn_found = 0;
               last
            }
         }
         
         @temp = split /\/\//, $line;
         $line = $temp[0];

         while ($line =~ m/\++|\-+|\/|\*+|\^/g)
         {
            $count++;
         }
      }
      
   }
   $maths_data{$file} = $count;
   close SOURCE_FILE;
}

$a; $b;
open (OUTFILE, ">$out_file_name") or die "Unable to create output file!\n";
print OUTFILE "File Name \t Maths Operator Count (Approx)\n";
foreach my $key (reverse sort {$maths_data{$b} <=> $maths_data{$a}} keys %maths_data)
{
   print OUTFILE "$key \t $maths_data{$key}\n";
}

close OUTFILE;
close FILE_LIST;
