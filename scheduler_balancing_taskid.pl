#!/usr/bin/perl

# ############################################################################ #
#
# AUTHOR : Selin George
# DATE   : 02-Mar-2009
#
# README:
#
# This code snippet generates a scheduler balancing report for Task ID.
# Minimum Time, Last Time and Maximum Time are reported against each Task ID.
#
# PREREQUISITE:
#
#       1. Perl 5.8.8 or latest.
#       2. Valid configuration file "config.inp". One configuration per line
#          is allowed. Comments can be inserted as a new line begining with
#          hash symbol (#).
#       3. Ensure write permission to the directory running this script. The
#          script generates a report file (scheduler_taskid.txt) in this
#          directory.
#
# HOW TO USE:
#
#       1. Edit the required configuration in config.inp.
#       2. Open command window and get the directory where this script is
#          located.
#       3. Execute the following command:
#              perl scheduler_balancing_taskid.pl
#
#       4. Check the output file scheduler_taskid.txt in the same directory.
#
# KNOWN ISSUES:
#       N/A
# ############################################################################ #

use strict;

# ############################################################################ #
# Variables
# ############################################################################ #

my %s_s_taskid;
my @temp_array;
my $last;
my @task_name;
my $view_name;
my $input_file;
my $output_format;
my $config_file = "config.inp";
my $match_found = 0;

# ############################################################################ #
# Reading Configurtion
# ############################################################################ #

print "\nReading Configuration file...\n";
open(CONFIG, $config_file) or die "Unable to open configuration file!\n";

while (<CONFIG>)
{
   # Skip blank lines and commented lines
   next if (m/^\s+$/ or m/^#/);
   chomp;

   # Remove all the unwanted whitespaces.
   s/\s+//g;

   # Identify settings
   @temp_array = split /=/;
   if ($temp_array[0] =~ m/VIEW_LABEL/)
   {
      $view_name = $temp_array[1];
   }
   elsif ($temp_array[0] =~ m/INPUT_S_S_FILE/)
   {
      $input_file = $temp_array[1];
   }
   elsif ($temp_array[0] =~ m/OUTPUT_FORMAT/)
   {
      $output_format = $temp_array[1];
   }
}

close CONFIG;
print "Completed reading configuration file.\n";


# ############################################################################ #
# Testing Configurtion
# ############################################################################ #

print "\nTesting Configuration...\n";
if (defined $view_name and defined $input_file)
{
   print "A valid configuration is loaded...\n";
}
else
{
   die "Invalid configuration is identified! Check the configurations in file \"config.inp\"\n";
}

# ############################################################################ #
# Reading Required Files
# ############################################################################ #

my $s_s_file = "\\\\view\\$view_name\\gill_vob\\6_coding\\src\\s_s\\s_s_scheduler\\out\\s_s_cal_sched_vars.h";

open(INFILE, $input_file) or die "Unable to open input file \"$input_file\"!\n";
open(S_S_FILE, $s_s_file) or die "Unable to open \"$s_s_file\"!\n";
open(OUTFILE, ">scheduler_taskid.txt") or die "Unable to create output file!\n";


# ############################################################################ #
# Reading s_s_cal_sched_vars.h to identify task names
# ############################################################################ #

while (<S_S_FILE>)
{
   chomp;
   if ($match_found == 0)
   {
      $match_found = 1 if (m/\s+S_S_NO_TASK_ID = 0,/);
      push (@task_name, "S_S_NO_TASK_ID") if (m/\s+S_S_NO_TASK_ID = 0,/);
   }
   elsif ($match_found == 1)
   {
      last if (m/\} S_S_TASK_ID;/);
      s/\s+|,//g;
      push(@task_name, $_);
   }
}
close S_S_FILE;


# ############################################################################ #
# Reading input file to identify Task ID, Minimum Time, Maximum Time, Last Time.
# ############################################################################ #

while (<INFILE>)
{
   chomp;
   next if (m/^\D/ or m/65535$/);
   @temp_array = split /;/;
   if (exists ($s_s_taskid{$temp_array[1]}))
   {
      $s_s_taskid{$temp_array[1]}->{'min'} = $temp_array[4] if ($temp_array[4] < $s_s_taskid{$temp_array[1]}->{'min'});
      $s_s_taskid{$temp_array[1]}->{'max'} = $temp_array[3] if ($temp_array[3] > $s_s_taskid{$temp_array[1]}->{'max'});
      $s_s_taskid{$temp_array[1]}->{'last'} = $temp_array[2] + $s_s_taskid{$temp_array[1]}->{'last'};
      $s_s_taskid{$temp_array[1]}->{'id_count'}++;
   }
   else
   {
      $s_s_taskid{$temp_array[1]}->{'min'} = $temp_array[4];
      $s_s_taskid{$temp_array[1]}->{'max'} = $temp_array[3];
      $s_s_taskid{$temp_array[1]}->{'last'} = $temp_array[2];
      $s_s_taskid{$temp_array[1]}->{'id_count'} = 1;
   }
}

# ############################################################################ #
# Generating Report.
# ############################################################################ #
print "\nGenerating output report...\n";
if ($output_format eq "CSV")
{
   print OUTFILE "Task Name,Task ID,Min,Last,Max\n";
   for my $key (sort keys %s_s_taskid)
   {
      $last = $s_s_taskid{$key}->{'last'}/$s_s_taskid{$key}->{'id_count'};
      # Approximate to 2 decimal places.
      $last = (int($last * 100)/100);
      print OUTFILE "$task_name[$key],$key,$s_s_taskid{$key}->{'min'},$last,$s_s_taskid{$key}->{'max'}\n";
   }
}
else
{
   print OUTFILE "Task Name \t\t\t\t\t Task ID \t Min \t Last \t Max\n";
   for my $key (sort keys %s_s_taskid)
   {
      $last = $s_s_taskid{$key}->{'last'}/$s_s_taskid{$key}->{'id_count'};
      # Approximate to 2 decimal places.
      $last = (int($last * 100)/100);
      print OUTFILE "$task_name[$key] \t\t $key \t\t $s_s_taskid{$key}->{'min'} \t $last \t $s_s_taskid{$key}->{'max'} \n";
   }
}

close INFILE;
close OUTFILE;


__END__
cleartool startview <view name> - creates the view
