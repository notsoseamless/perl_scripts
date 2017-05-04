#! /usr/bin/perl

# ############################################################################ #
#
# AUTHOR  : Selin George
# DATE    : 10-July-2009
# VERSION : 12.0
#
# README:
#
# This code snippet generates a scheduler balancing report for Phase.
# The loading is reported for each phase. An optional list of tasks that
# that are being scheduled in each phase, Tooth Number are also reported.
#
# PREREQUISITE:
#
#       1. Perl 5.8.8 or latest.
#       2. Valid configuration file "config.inp". One configuration per line
#          is allowed. Comments can be inserted as a new line begining with
#          hash symbol (#).
#       3. Ensure write permission to the directory running this script. The
#          script generates a report file and an error file in this
#          directory.
#       4. Mount the intended view in M drive. (Script will be updated in
#          later stages to do this automatically).
#
# HOW TO USE:
#
#       1. Edit the required configuration in config.inp.
#       2. Open command window and get the directory where this script is
#          located.
#       3. Execute the following command:
#              perl scheduler_balancing_phase_v<version number>.pl
#
#       4. Check the output files <input_file>_scheduler_phase.txt,
#          <input_file>_error.txt in the same directory.
#
# KNOWN ISSUES:
#       N/A
#
# HISTORY:
#       See Footer of this code.
#
# ############################################################################ #

use strict;

# ############################################################################ #
# Variables
# ############################################################################ #

# Variables
my $version = "12.0";
my $last;
my $temp_id;
my $s_s_file;
my $next_slot;
my $view_name;
my $input_file;
my $teeth_span;
my $net_min = 0;
my $net_max = 0;
my $net_last = 0;
my $injectors = 1;
my $tasklist_file;
my $tasklist_path;
my $match_found = 0;
my $max_phase = 1023;
my $static_crank = 0;
my $current_lp_teeth;
my $lptooth_export = "FALSE";
my $dynamic_crank = 0;
my $sync_lp_tooth = 0;
my $task_name_derived;
my $override_filepath;
my $dcm_type = "DCM2.5";
my $report_tasks = "YES";
my $report_tooth = "NO";
my $output_format = "CSV";
my $config_file = "config.inp";
my $header_found = 0;
my $engine_speed = 0;
my $engine_speed_count = 0;
my $engine_speed_min = 10000;
my $engine_speed_max = 0;
my $engine_speed_tolerance;
my $delta_engine_speed;
my $one_teeth_passing_time;
my $number_of_teeth;

# Column identifying keywords
my $time_str            = "TimeStamp";
my $engine_speed_str    = "IN_Engine_cycle_speed";
my $sync_lptooth_str    = "S_S_Sync_lp_tooth";
my $task_ident_str      = "s_s_task_ident";
my $task_time_last_str  = "s_s_task_time_last";
my $task_time_max_str   = "s_s_task_time_max";
my $task_time_min_str   = "s_s_task_time_min";
my $tooth_ident_str     = "s_s_tooth_ident";
my $tooth_time_last_str = "s_s_tooth_time_last";
my $tooth_time_max_str  = "s_s_tooth_time_max";
my $tooth_time_min_str  = "s_s_tooth_time_min";

my $time_col;
my $engine_speed_col;
my $sync_lptooth_col;
my $task_ident_col;
my $task_time_last_col;
my $task_time_max_col;
my $task_time_min_col;
my $tooth_ident_col;
my $tooth_time_last_col;
my $tooth_time_max_col;
my $tooth_time_min_col;


# Arrays
my @lp_tooth;
my @temp_array;
my @phase_xaxis;
my @lp_key_array;
my @lp_value_array;
my @dyn_crank_tasks;

# Hashes
my %s_s_phase;
my %s_s_tooth;
my %s_s_taskid;
my %static_lp_task;
my %s_s_phase_tasks;
my %s_s_function_table;
my %static_crank_tasks;

# ############################################################################ #
# Reading Configurtion
# ############################################################################ #

print "\nScheduler Balancing By Phase V$version\n\n";
print "\nReading Configuration file...\n";
open (CONFIG, $config_file) or die "Unable to open configuration file!\n";

while (<CONFIG>)
{
   # Skip blank lines and commented lines
   next if (m/^\s*$/ or m/^#/);
   chomp;

   # Identify settings
   @temp_array = split /=/;
   my $temp = $temp_array[1];

   # Remove leading and trailing whitespaces.
   $temp =~ s/^\s*//g;
   $temp =~ s/\s*$//g;

   if ($temp_array[0] =~ m/VIEW_LABEL/)
   {
      $view_name = $temp;
   }
   elsif ($temp_array[0] =~ m/INPUT_S_S_FILE/)
   {
      $input_file = $temp;
   }
   elsif ($temp_array[0] =~ m/MAX_PHASE/)
   {
      $max_phase = $temp;
   }
   elsif ($temp_array[0] =~ m/DCM_TYPE/)
   {
      $dcm_type = $temp;
   }
   elsif ($temp_array[0] =~ m/OUTPUT_FORMAT/)
   {
      $output_format = $temp;
   }
   elsif ($temp_array[0] =~ m/REPORT_TASKS_IN_PHASE/)
   {
      $report_tasks = $temp;
   }
   elsif ($temp_array[0] =~ m/REPORT_TOOTH/)
   {
      $report_tooth = $temp;
   }
   elsif ($temp_array[0] =~ m/INJECTORS/)
   {
      $injectors = $temp;
   }
   elsif ($temp_array[0] =~ m/OVERRIDE_FILEPATH/)
   {
      $override_filepath = $temp;
   }
   elsif ($temp_array[0] =~ m/TASKLIST_ASC_PATH/)
   {
      $tasklist_path = $temp;
   }
   elsif ($temp_array[0] =~ m/ENGINE_SPEED_TOLERANCE/)
   {
      $engine_speed_tolerance = $temp;
   }
   elsif ($temp_array[0] =~ m/TOTAL_NUMBER_OF_CRANK_TEETH/)
   {
      $number_of_teeth = $temp;
   }
}

close CONFIG;
print "Completed reading configuration file.\n";


# ############################################################################ #
# Testing Configurtion
# ############################################################################ #

my $error_flag = 0;

if ($override_filepath eq "NO")
{
   $error_flag = 1 if (defined $view_name);
   $tasklist_file = "\\\\view\\$view_name\\blois_soft_vob\\Software\\S_S\\s_s_scheduler\\src\\tasklist.asc";
}
else
{
   $error_flag = 1;
   $tasklist_file = ($tasklist_path =~ m/^\s*$/) ? "tasklist.asc" : $tasklist_path."\\tasklist.asc";
}

print "\nTesting Configuration...\n";
if (($error_flag == 1) and defined $input_file and defined $max_phase)
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

my $error_file  = $input_file."_error.txt";
open(TASKLIST, $tasklist_file) or die "Unable to open \"tasklist.asc\"!\n";
open(ERR_FILE, ">$error_file") or die "Unable to create error file \"$error_file\"!\n";

# ############################################################################ #
# Reading tasklist.asc to identify task names, slot and phase
# ############################################################################ #

while (<TASKLIST>)
{
   chomp;
   if ($match_found == 0)
   {
      # Identify valid tasks
      # DCM 2.5
      if ($dcm_type eq "DCM2.5")
      {
         $match_found = 1 if (m/^SS_HIGH_EXTRA_TIMED_TASKS|^SS_HIGH_TIMED_TASKS|^SS_LOW_EXTRA_TIMED_TASKS|^SS_LOW_TIMED_TASKS/);
      }
      # Other DCMs
      else
      {
         $match_found = 1 if (m/^SS_HIGH_EXTRA_TIMED_TASKS|^SS_HIGH_TIMED_TASKS|^SS_LOW_EXTRA_TIMED_TASKS|^SS_LOW_TIMED_TASKS/);
      }
   }
   elsif ($match_found == 1)
   {
      s/\s*//g;

      # Skip the unwanted lines
      next if (m/\{|^#|^$/);
      $match_found = 0 if (m/\}/);
      next if (m/\}/);

      # Get the slot, phase and task names
      @temp_array = split /,/;
      if (exists $s_s_phase{$temp_array[2]})
      {
         push @{$s_s_phase{$temp_array[2]}->{'slot'}}, $temp_array[0];
         push @{$s_s_phase{$temp_array[2]}->{'phase'}}, $temp_array[1];

         # Maintain a count if tasks found with multiple slot and phase
         if (defined $s_s_phase{$temp_array[2]}->{'count'})
         {
            $s_s_phase{$temp_array[2]}->{'count'}++;
         }
         else
         {
            $s_s_phase{$temp_array[2]}->{'count'} = 1;
         }
      }
      else
      {
         $s_s_phase{$temp_array[2]}->{'slot'}[0] = $temp_array[0];
         $s_s_phase{$temp_array[2]}->{'phase'}[0] = $temp_array[1];
      }
   }
}

close TASKLIST;

# ############################################################################ #
# Reading Static And Dynamic Crank Tasks
# ############################################################################ #

if ($report_tooth eq "YES")
{
   open(TASKLIST, $tasklist_file) or die "Unable to open \"tasklist.asc\"!\n";

   $teeth_span = 120/$injectors;
   
   while (<TASKLIST>)
   {
      chomp;
      if ($static_crank == 0 && $dynamic_crank == 0 && $sync_lp_tooth == 0)
      {
         # Identify valid tasks
         # DCM 2.5
         if ($dcm_type eq "DCM2.5")
         {
            $static_crank = 1 if (m/^SS_STATIC_CRANK_TASKS/);
            $dynamic_crank = 1 if (m/^SS_DYNAMIC_CRANK_TASKS/);
            $sync_lp_tooth = 1 if (m/^SS_STATIC_CRANK_LOW_TASKS/);
         }
         # Other DCMs
         else
         {
            $static_crank = 1 if (m/^SS_STATIC_CRANK_TASKS/);
            $dynamic_crank = 1 if (m/^SS_DYNAMIC_CRANK_TASKS/);
            $sync_lp_tooth = 1 if (m/^SS_STATIC_CRANK_LOW_TASKS/);
         }
      }
      elsif ($static_crank == 1 || $dynamic_crank == 1 || $sync_lp_tooth == 1)
      {
         s/\s*//g;
   
         # Skip the unwanted lines
         next if (m/\{|^#|^$/);
         if (m/\}/)
         {
            $static_crank  = 0;
            $dynamic_crank = 0;
            $sync_lp_tooth = 0;
            next;
         }
   
         # Get the slot, phase and task names
         @temp_array = split /,/;

         # Collect Dynamic Crank Tasks
         if ($dynamic_crank == 1)
         {
            push @dyn_crank_tasks, $temp_array[0] if (!grep(/\b$temp_array[0]\b/,@dyn_crank_tasks));
         }

         # Collect Static Crank Tasks and Low Priority Crank Tasks
         elsif ($static_crank == 1)
         {
            for (my $i = 0; $i < $injectors; $i++)
            {
               $next_slot = $temp_array[0] + ($i * $teeth_span);
               $next_slot -= 120 if ($next_slot > 120);
               push @{$static_crank_tasks{$next_slot}}, $temp_array[1];
            }
         }
         else
         {
            push @{$static_lp_task{$temp_array[0]}}, $temp_array[1];
         }
      }
   }
   close TASKLIST;

   @lp_key_array   = keys %static_lp_task;
   @lp_value_array = @{$static_lp_task{$lp_key_array[0]}};
   if ($#lp_key_array > 0)
   {
      print ERR_FILE "ERROR: Multiple teeth entries found in SS_STATIC_CRANK_LOW_TASKS!\n";
      exit 1;
   }
}
else
{
   # Do Nothing
}

# ############################################################################ #
# Getting phase information
# ############################################################################ #

foreach my $key (keys %s_s_phase)
{
   # Process the tasks with multiple slot and phase.
   if (defined $s_s_phase{$key}->{'count'})
   {
      for (my $i = 0; $i<=$s_s_phase{$key}->{'count'}; $i++)
      {
         for (my $j = $s_s_phase{$key}->{'phase'}[$i]; $j<=$max_phase; $j = $j + $s_s_phase{$key}->{'slot'}[$i])
         {
            $phase_xaxis[$j]++;
            push @{$s_s_phase_tasks{$j}}, $key;
         }
      }
   }
   # Process the tasks with one slot and phase
   else
   {
      for (my $j = $s_s_phase{$key}->{'phase'}[0]; $j<=$max_phase; $j = $j + $s_s_phase{$key}->{'slot'}[0])
      {
         $phase_xaxis[$j]++;
         push @{$s_s_phase_tasks{$j}}, $key;
      }
   }
}


# ############################################################################ #
# Generating Report.
# ############################################################################ #

my $output_file = $input_file."_scheduler_phase.txt";
open (OUTFILE, ">$output_file") or die "Unable to create output file!\n";

# Get Timestamp
my @abbr = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

# Get the current time
(my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst) = localtime(time);

# Adjust the year
$year += 1900;

# Get the time in format Jun 5 2009 11:54:10
my $timestring = $abbr[$mon]." ".$mday." ".$year." ".$hour.":".$min.":".$sec;

print "\nGenerating output report...\n";
print OUTFILE "Scheduler Balancing by Phase:\n";
print OUTFILE "Version: $version\nDate: $timestring\n\n";

print OUTFILE "PHASE LOADING REPORT:\n\n";

# Print report in CSV format
if ($output_format eq "CSV")
{
   print OUTFILE "Slot,Loading\n";
   my $i = 0;

   foreach my $temp (@phase_xaxis)
   {
      print OUTFILE "$i,$temp\n";
      $i++;
   }
}
# Print report in TAB format
else
{
   print OUTFILE "Slot\tLoading\n";
   my $i = 0;

   foreach my $temp (@phase_xaxis)
   {
      print OUTFILE "$i\t$temp\n";
      $i++;
   }
}

# ############################################################################ #
# Reading input file to identify Task ID, Minimum Time, Maximum Time, Last Time.
# ############################################################################ #

open(INFILE, $input_file) or die "Unable to open input file \"$input_file\"!\n";

while (<INFILE>)
{
   chomp;
   next if m/^\s*$/;

   # Identify the header
   if (m/^\D/)
   {
      next if ($header_found == 1);
      next if (!m/\bs_s_task_ident\b/);
      s/\"//g;
      @temp_array = split /\t/;
      for(my $i = 0; $i <= $#temp_array; $i++)
      {
         if ($temp_array[$i] eq $time_str)
         {
            $time_col = $i;
         }
         elsif ($temp_array[$i] eq $engine_speed_str)
         {
            $engine_speed_col = $i;
         }
         elsif ($temp_array[$i] eq $sync_lptooth_str)
         {
            $sync_lptooth_col = $i;
            $lptooth_export   = "TRUE";
         }
         elsif ($temp_array[$i] eq $task_ident_str)
         {
            $task_ident_col = $i;
         }
         elsif ($temp_array[$i] eq $task_time_last_str)
         {
            $task_time_last_col = $i;
         }
         elsif ($temp_array[$i] eq $task_time_max_str)
         {
            $task_time_max_col = $i;
         }
         elsif ($temp_array[$i] eq $task_time_min_str)
         {
            $task_time_min_col = $i;
         }
         elsif ($temp_array[$i] eq $tooth_ident_str)
         {
            $tooth_ident_col = $i;
         }
         elsif ($temp_array[$i] eq $tooth_time_last_str)
         {
            $tooth_time_last_col = $i;
         }
         elsif ($temp_array[$i] eq $tooth_time_max_str)
         {
            $tooth_time_max_col = $i;
         }
         elsif ($temp_array[$i] eq $tooth_time_min_str)
         {
            $tooth_time_min_col = $i;
         }
         else
         {
            # Do Nothing
         }
      }

      if (!$task_ident_col || !$task_time_last_col || !$task_time_max_col || !$task_time_min_col)
      {
         print ERR_FILE "Error: Incorrect input file. Task ID/MIN/MAX/LAST time is missing!\n";
         exit 1;
      }

      if ($report_tooth eq "YES" && (!$tooth_ident_col || !$tooth_time_last_col || !$tooth_time_max_col || !$tooth_time_min_col))
      {
         print ERR_FILE "Error: Incorrect input file. Tooth ID/MIN/MAX/LAST time is missing!\n";
         exit 1;
      }
     
      $header_found = 1;
      next;
   }

   @temp_array = split /\t/;
   

   # Capture task informations
   if ($temp_array[$task_time_last_col] ne "65535" and $temp_array[$task_time_max_col] ne "65535" and $temp_array[$task_time_min_col] ne "65535")
   {
      if (exists ($s_s_taskid{$temp_array[$task_ident_col]}))
      {
         $s_s_taskid{$temp_array[$task_ident_col]}->{'min'} = $temp_array[$task_time_min_col] if
                           ($temp_array[$task_time_min_col] < $s_s_taskid{$temp_array[$task_ident_col]}->{'min'});
         $s_s_taskid{$temp_array[$task_ident_col]}->{'max'} = $temp_array[$task_time_max_col] if
                           ($temp_array[$task_time_max_col] > $s_s_taskid{$temp_array[$task_ident_col]}->{'max'});
         $s_s_taskid{$temp_array[$task_ident_col]}->{'last'} = $temp_array[$task_time_last_col] +
                                             $s_s_taskid{$temp_array[$task_ident_col]}->{'last'};
         $s_s_taskid{$temp_array[$task_ident_col]}->{'id_count'}++;
      }
      else
      {
         $s_s_taskid{$temp_array[$task_ident_col]}->{'min'} = $temp_array[$task_time_min_col];
         $s_s_taskid{$temp_array[$task_ident_col]}->{'max'} = $temp_array[$task_time_max_col];
         $s_s_taskid{$temp_array[$task_ident_col]}->{'last'} = $temp_array[$task_time_last_col];
         $s_s_taskid{$temp_array[$task_ident_col]}->{'id_count'} = 1;
      }
   }

   if ($engine_speed_col)
   {
      $engine_speed    += $temp_array[$engine_speed_col];
      $engine_speed_min = $temp_array[$engine_speed_col] if ($temp_array[$engine_speed_col] < $engine_speed_min);
      $engine_speed_max = $temp_array[$engine_speed_col] if ($temp_array[$engine_speed_col] > $engine_speed_max);
      $engine_speed_count++;
   }

   if ($report_tooth eq "YES")
   {
      if ($lptooth_export eq "TRUE")
      {
         # Capture the LP Tooth
         if (!$lp_tooth[0])
         {
            push @lp_tooth, $temp_array[$sync_lptooth_col];
         }
         else
         {
            if ($lp_tooth[0] != $temp_array[$sync_lptooth_col])
            {
               print ERR_FILE "ERROR: S_S_Sync_lp_tooth changed at time \"$temp_array[$time_col]\"\n";
               push @lp_tooth, $temp_array[$sync_lptooth_col];
               exit 1;
            }
         }
      }

      # Capture tooth informations
      if ($temp_array[$tooth_time_last_col] ne "65535" and $temp_array[$tooth_time_max_col] ne "65535" and $temp_array[$tooth_time_min_col] ne "65535")
      {
         if (exists ($s_s_tooth{$temp_array[$tooth_ident_col]}))
         {
            my $temp = $temp_array[$task_ident_col];
            push @{$s_s_tooth{$temp_array[$tooth_ident_col]}->{'taskid'}}, $temp if (!grep(/\b$temp\b/,@{$s_s_tooth{$temp_array[$tooth_ident_col]}->{'taskid'}}));
            $s_s_tooth{$temp_array[$tooth_ident_col]}->{'min'} = $temp_array[$tooth_time_min_col] if
                              ($temp_array[$tooth_time_min_col] < $s_s_tooth{$temp_array[$tooth_ident_col]}->{'min'});
            $s_s_tooth{$temp_array[$tooth_ident_col]}->{'max'} = $temp_array[$tooth_time_max_col] if
                              ($temp_array[$tooth_time_max_col] > $s_s_tooth{$temp_array[$tooth_ident_col]}->{'max'});
            $s_s_tooth{$temp_array[$tooth_ident_col]}->{'last'} = $temp_array[$tooth_time_last_col] +
                                                $s_s_tooth{$temp_array[$tooth_ident_col]}->{'last'};
            $s_s_tooth{$temp_array[$tooth_ident_col]}->{'id_count'}++;
         }
         else
         {
            $s_s_tooth{$temp_array[$tooth_ident_col]}->{'min'} = $temp_array[$tooth_time_min_col];
            $s_s_tooth{$temp_array[$tooth_ident_col]}->{'max'} = $temp_array[$tooth_time_max_col];
            $s_s_tooth{$temp_array[$tooth_ident_col]}->{'last'} = $temp_array[$tooth_time_last_col];
            $s_s_tooth{$temp_array[$tooth_ident_col]}->{'taskid'}[0] = $temp_array[$task_ident_col];
            $s_s_tooth{$temp_array[$tooth_ident_col]}->{'id_count'} = 1;
         }
      }
   }
}

close INFILE;


# ############################################################################ #
# Reading input file to validate engine speed.
# ############################################################################ #

if ($engine_speed_col)
{
   if(!$engine_speed_tolerance)
   {
      print ERR_FILE "No engine speed tolerance (ENGINE_SPEED_TOLERANCE) is specified in config.inp!\n";
      exit 1;
   }
   
   open(INFILE, $input_file) or die "Unable to open input file \"$input_file\"!\n";
   
   # Average engine speed
   $engine_speed /= $engine_speed_count;
   
   while (<INFILE>)
   {
      chomp;
      next if m/^\s*$/;
      next if (m/^\D/);
      @temp_array = split /\t/;
      if ($engine_speed > $temp_array[$engine_speed_col])
      {
         $delta_engine_speed = $engine_speed - $temp_array[$engine_speed_col];
      }
      else
      {
         $delta_engine_speed = $temp_array[$engine_speed_col] - $engine_speed;
      }
   
      if ($delta_engine_speed > $engine_speed_tolerance)
      {
         print ERR_FILE "ERROR: Speed change at time $temp_array[$time_col] is more than the allowable limit $engine_speed_tolerance!\n";
      }
   }
   
   close INFILE;
}


# ############################################################################ #
# Build a table for Task ID, Min, Last, and Max.
# ############################################################################ #

for my $key (sort keys %s_s_taskid)
{
   $last = $s_s_taskid{$key}->{'last'}/$s_s_taskid{$key}->{'id_count'};

   # Approximate to 2 decimal places.
   $last = (int($last * 100)/100);
   $s_s_function_table{$key}->{'min'} = $s_s_taskid{$key}->{'min'};
   $s_s_function_table{$key}->{'max'} = $s_s_taskid{$key}->{'max'};
   $s_s_function_table{$key}->{'last'} = $last;
}

# ############################################################################ #
# Report Tasks for each phase
# ############################################################################ #

if ($report_tasks eq "NO")
{
   # Do Nothing
}
else
{
   # Print report in CSV format
   if ($output_format eq "CSV")
   {
      print OUTFILE "\n\n# ############################################################################ #\n";
      print OUTFILE "TASKS SCHEDULED IN EACH PHASE:\n";
      print OUTFILE "Header: Slot,Total Min,Average Last,Total Max\n";
      print OUTFILE "Elements: Task Name,Min,Last,Max\n";
      print OUTFILE "# ############################################################################ #\n\n";
   
      for (my $i = 0; $i <= $max_phase; $i++)
      {
         foreach my $temp (@{$s_s_phase_tasks{$i}})
         {
            $task_name_derived = "S_S_SCH_".uc($temp)."_ID";
            $net_min = $net_min + $s_s_function_table{$task_name_derived}->{'min'};
            $net_last = $net_last + $s_s_function_table{$task_name_derived}->{'last'};
            $net_max = $net_max + $s_s_function_table{$task_name_derived}->{'max'};
         }
         print OUTFILE "Slot : $i,$net_min,$net_last,$net_max\n";
         
         # Reset the net variables
         $net_min = 0;
         $net_max = 0;
         $net_last = 0;

         foreach my $temp (@{$s_s_phase_tasks{$i}})
         {
            $task_name_derived = "S_S_SCH_".uc($temp)."_ID";
            print OUTFILE "\t\t$temp,$s_s_function_table{$task_name_derived}->{'min'},$s_s_function_table{$task_name_derived}->{'last'},$s_s_function_table{$task_name_derived}->{'max'}\n";
         }
      }
   }
   # Print report in TAB format
   else
   {
      print OUTFILE "\n\n# ############################################################################ #\n";
      print OUTFILE "TASKS SCHEDULED IN EACH PHASE:\n";
      print OUTFILE "Header: Slot\tTotal Min\tAverage Last\tTotal Max\n";
      print OUTFILE "Elements: Task Name\tMin\tLast\tMax\n";
      print OUTFILE "# ############################################################################ #\n\n";
   
      for (my $i = 0; $i <= $max_phase; $i++)
      {
         foreach my $temp (@{$s_s_phase_tasks{$i}})
         {
            $task_name_derived = "S_S_SCH_".uc($temp)."_ID";
            $net_min = $net_min + $s_s_function_table{$task_name_derived}->{'min'};
            $net_last = $net_last + $s_s_function_table{$task_name_derived}->{'last'};
            $net_max = $net_max + $s_s_function_table{$task_name_derived}->{'max'};
         }
         print OUTFILE "Slot : $i\t$net_min\t$net_last\t$net_max\n";

         # Reset the net variables
         $net_min = 0;
         $net_max = 0;
         $net_last = 0;

         foreach my $temp (@{$s_s_phase_tasks{$i}})
         {
            $task_name_derived = "S_S_SCH_".uc($temp)."_ID";
            print OUTFILE "\t\t$temp\t$s_s_function_table{$task_name_derived}->{'min'}\t$s_s_function_table{$task_name_derived}->{'last'}\t$s_s_function_table{$task_name_derived}->{'max'}\n";
         }
      }
   }
}

$a; $b;

if ($report_tooth eq "NO")
{
   # Do Nothing
}
else
{
   if ($lptooth_export eq "TRUE" and $lp_tooth[0])
   {
      $current_lp_teeth = $lp_tooth[0];
   }
   else
   {
      $current_lp_teeth = $lp_key_array[0];
   }


   # Append the SS_STATIC_CRANK_LOW_TASKS
   for (my $i = 0; $i < $injectors; $i++)
   {
      $next_slot = $current_lp_teeth + ($i * $teeth_span);
      $next_slot -= 120 if ($next_slot > 120);
      foreach my $temp (@lp_value_array)
      {
         push @{$static_crank_tasks{$next_slot}}, $temp;
      }
   }

   # Print report in CSV format
   if ($output_format eq "CSV")
   {
      print OUTFILE "\n\n# ############################################################################ #\n";
      print OUTFILE "STATIC CRANK TASKS:\n";
      print OUTFILE "Header: Tooth Number,Total Min,Average Last,Total Max\n";
      print OUTFILE "Elements: Task Name,Min,Last,Max\n";
      print OUTFILE "# ############################################################################ #\n\n";

      foreach my $key (sort {$a <=> $b} keys %s_s_tooth)
      {
         $last = $s_s_tooth{$key}->{'last'}/$s_s_tooth{$key}->{'id_count'};

         # Approximate to 2 decimal places.
         $last = (int($last * 100)/100);

         print OUTFILE "Tooth : $key,$s_s_tooth{$key}->{'min'},$last,$s_s_tooth{$key}->{'max'}\n";

         # Report Static Crank Tasks
         foreach my $temp (@{$static_crank_tasks{$key}})
         {
            $temp_id = "S_S_SCH_".uc($temp)."_ID";
            print OUTFILE "\t\t$temp,$s_s_function_table{$temp_id}->{'min'},$s_s_function_table{$temp_id}->{'last'},$s_s_function_table{$temp_id}->{'max'}\n";
         }
      }

      # Report Dynamic Crank Tasks
      print OUTFILE "\n\nDYNAMIC CRANK TASKS:\n\n";

      foreach my $temp (@dyn_crank_tasks)
      {
         $temp_id = "S_S_SCH_".uc($temp)."_ID";
         print OUTFILE "$temp,$s_s_function_table{$temp_id}->{'min'},$s_s_function_table{$temp_id}->{'last'},$s_s_function_table{$temp_id}->{'max'}\n";
      }
   }
   # Print report in TAB format
   else
   {
      print OUTFILE "\n\n# ############################################################################ #\n";
      print OUTFILE "STATIC CRANK TASKS:\n";
      print OUTFILE "Header: Tooth Number\tTotal Min\tAverage Last\tTotal Max\n";
      print OUTFILE "Elements: Task Name\tMin\tLast\tMax\n";
      print OUTFILE "# ############################################################################ #\n\n";

      foreach my $key (sort {$a <=> $b} keys %s_s_tooth)
      {
         $last = $s_s_tooth{$key}->{'last'}/$s_s_tooth{$key}->{'id_count'};

         # Approximate to 2 decimal places.
         $last = (int($last * 100)/100);

         print OUTFILE "Tooth : $key\t$s_s_tooth{$key}->{'min'}\t$last\t$s_s_tooth{$key}->{'max'}\n";

         # Report Static Crank Tasks
         foreach my $temp (@{$static_crank_tasks{$key}})
         {
            $temp_id = "S_S_SCH_".uc($temp)."_ID";
            print OUTFILE "\t\t$temp\t$s_s_function_table{$temp_id}->{'min'}\t$s_s_function_table{$temp_id}->{'last'}\t$s_s_function_table{$temp_id}->{'max'}\n";
         }
      }

      # Report Dynamic Crank Tasks
      print OUTFILE "\n\nDYNAMIC CRANK TASKS:\n\n";

      foreach my $temp (@dyn_crank_tasks)
      {
         $temp_id = "S_S_SCH_".uc($temp)."_ID";
         print OUTFILE "$temp\t$s_s_function_table{$temp_id}->{'min'}\t$s_s_function_table{$temp_id}->{'last'}\t$s_s_function_table{$temp_id}->{'max'}\n";
      }
   }
}

# ############################################################################ #
# Report Engine Cycle Speed
# ############################################################################ #

if ($engine_speed_col)
{
   # Approximate the speed to 2 decimal places
   $engine_speed = (int($engine_speed * 100)/100);
   $one_teeth_passing_time = (1/(($engine_speed/60) * $number_of_teeth)) * 1000000;
   print OUTFILE "\n\n# ############################################################################ #\n";
   print OUTFILE "ENGINE CYCLE SPEED:\n";
   print OUTFILE "# ############################################################################ #\n\n";
   print OUTFILE "\t\tAverage Engine Cycle Speed: $engine_speed\n";
   print OUTFILE "\t\tMaximum Engine Cycle Speed: $engine_speed_max\n";
   print OUTFILE "\t\tMinimum Engine Cycle Speed: $engine_speed_min\n";
   print OUTFILE "\t\tTime Taken For One Tooth To Pass: $one_teeth_passing_time Micro Seconds\n";
}

close OUTFILE;
close ERR_FILE;

__END__

HISTORY:
1.0 Initial version
2.0 Update to display Net Min, Net Max, Net Last in the report.
3.0 Data file output for MATLAB import.
4.0 Added MIN, LAST and MAX for tooth number.
5.0 Updated to latest tasklist.asc syntax (SS_HIGH_EXTRA_TIMED_TASKS, SS_HIGH_TIMED_TASKS, SS_LOW_EXTRA_TIMED_TASKS, SS_LOW_TIMED_TASKS).
6.0 Task names are reported for each Tooth Number. Static and Dynamic crank tasks are included in the report.
7.0 Reworked the tooth number based on number of injectors. Added new input configuration INJECTORS.
8.0 Minor update in output report header. Timestamp updated in the report.
9.0 Optional file paths for tasklist.asc and s_s_cal_sched_vars.h through config.inp.
10.0 Updates to recognise S_S_Sync_lp_tooth in the export, and SS_STATIC_CRANK_LOW_TASKS in the tasklist.asc.
11.0 MATLAB data export is removed. The script automatically identifies the columns of input data file
12.0 Engine cycle speed is processed, and time taken for one tooth to pass is reported.
