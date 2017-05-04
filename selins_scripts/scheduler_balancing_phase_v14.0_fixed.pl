#! /usr/bin/perl

# ############################################################################ #
#
# AUTHOR  : Selin George
# DATE    : 27-Nov-2009
# VERSION : 14.0
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
my $version = "14.0";
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
my $cpu_load = 0;
my $calvars_path;
my $injectors = 1;
my $tasklist_file;
my $tasklist_path;
my $max_phase = 0;
my $sort_by = 'min';
my $number_of_teeth;
my $match_found = 0;
my $current_lp_teeth;
my $static_crank = 0;
my $header_found = 0;
my $engine_speed = 0;
my $cpu_load_max = 0;
my $dynamic_crank = 0;
my $sync_lp_tooth = 0;
my $async_regular = 0;
my $task_name_derived;
my $override_filepath;
my $delta_engine_speed;
my $cpu_load_count = 0;
my $dcm_type = "DCM2.5";
my $engine_speed_max = 0;
my $cpu_load_min = 65535;
my $engine_speed_tolerance;
my $one_tooth_passing_time;
my $engine_speed_count = 0;
my $lptooth_export = "FALSE";
my $engine_speed_min = 65535;
my $config_file = "config.inp";

# Column identifying keywords
my $time_str              = "Time";
my $engine_speed_str      = "IN_Engine_cycle_speed";
my $sync_lptooth_str      = "S_S_Sync_lp_tooth";
my $cpu_load_str          = "S_S_Cpu_load_percent";
my $task_ident_str        = "s_s_task_ident";
my $task_time_last_str    = "s_s_task_time_last";
my $task_time_max_str     = "s_s_task_time_max";
my $task_time_min_str     = "s_s_task_time_min";
my $tooth_ident_str       = "s_s_tooth_ident";
my $tooth_time_last_str   = "s_s_tooth_time_last";
my $tooth_time_max_str    = "s_s_tooth_time_max";
my $tooth_time_min_str    = "s_s_tooth_time_min";
my $async_hi_time_max_str = "s_s_sched_async_hi_time_max";
my $async_hi_time_min_str = "s_s_sched_async_hi_time_min";
my $async_lo_time_max_str = "s_s_sched_async_lo_time_max";
my $async_lo_time_min_str = "s_s_sched_async_lo_time_min";
my $sync_hi_time_max_str  = "s_s_sched_sync_hi_time_max";
my $sync_hi_time_min_str  = "s_s_sched_sync_hi_time_min";
my $sync_lo_time_max_str  = "s_s_sched_sync_lo_time_max";
my $sync_lo_time_min_str  = "s_s_sched_sync_lo_time_min";

my $time_col;
my $hi_lo_found;
my $cpu_load_col;
my $task_ident_col;
my $tooth_ident_col;
my $engine_speed_col;
my $sync_lptooth_col;
my $task_time_max_col;
my $task_time_min_col;
my $task_time_last_col;
my $tooth_time_max_col;
my $tooth_time_min_col;
my $tooth_time_last_col;
my $async_hi_time_max_col;
my $async_hi_time_min_col;
my $async_lo_time_max_col;
my $async_lo_time_min_col;
my $sync_hi_time_max_col;
my $sync_hi_time_min_col;
my $sync_lo_time_max_col;
my $sync_lo_time_min_col;


# Arrays
my @lp_tooth;
my @task_name;
my @temp_array;
my @phase_xaxis;
my @config_vars;
my @lp_key_array;
my @lp_value_array;
my @dyn_crank_tasks;

# Hashes
my %config;
my %s_s_phase;
my %s_s_tooth;
my %s_s_taskid;
my %static_lp_task;
my %s_s_phase_tasks;
my %s_s_function_table;
my %static_crank_tasks;
my %async_regular_tasks;

# ############################################################################ #
# Reading Configurtion
# ############################################################################ #

print "\nScheduler Balancing By Phase V$version\n\n";
print "\nReading Configuration file...\n";
open (CONFIG, $config_file) or die "Unable to open configuration file $config_file!\n";

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
      $config{"VIEW_LABEL"} = $temp;
      push @config_vars, "VIEW_LABEL";
   }
   elsif ($temp_array[0] =~ m/INPUT_S_S_FILE/)
   {
      $input_file = $temp;
      $config{"INPUT_S_S_FILE"} = $temp;
      push @config_vars, "INPUT_S_S_FILE";
   }
   elsif ($temp_array[0] =~ m/DCM_TYPE/)
   {
      $dcm_type = $temp;
      $config{"DCM_TYPE"} = $temp;
      push @config_vars, "DCM_TYPE";
   }
   elsif ($temp_array[0] =~ m/INJECTORS/)
   {
      $injectors = $temp;
      $config{"INJECTORS"} = $temp;
      push @config_vars, "INJECTORS";
   }
   elsif ($temp_array[0] =~ m/OVERRIDE_FILEPATH/)
   {
      $override_filepath = $temp;
      $config{"OVERRIDE_FILEPATH"} = $temp;
      push @config_vars, "OVERRIDE_FILEPATH";
   }
   elsif ($temp_array[0] =~ m/TASKLIST_ASC_PATH/)
   {
      $tasklist_path = $temp;
      $config{"TASKLIST_ASC_PATH"} = $temp;
      push @config_vars, "TASKLIST_ASC_PATH";
   }
   elsif ($temp_array[0] =~ m/CAL_SCHD_VARS_PATH/)
   {
      $calvars_path = $temp;
      $config{"CAL_SCHD_VARS_PATH"} = $temp;
      push @config_vars, "CAL_SCHD_VARS_PATH";
   }
   elsif ($temp_array[0] =~ m/ENGINE_SPEED_TOLERANCE/)
   {
      $engine_speed_tolerance = $temp;
      $config{"ENGINE_SPEED_TOLERANCE"} = $temp;
      push @config_vars, "ENGINE_SPEED_TOLERANCE";
   }
   elsif ($temp_array[0] =~ m/TOTAL_NUMBER_OF_CRANK_TEETH/)
   {
      $number_of_teeth = $temp;
      $config{"TOTAL_NUMBER_OF_CRANK_TEETH"} = $temp;
      push @config_vars, "TOTAL_NUMBER_OF_CRANK_TEETH";
   }
   elsif ($temp_array[0] =~ m/SORT_BY/)
   {
      $sort_by = lc($temp);
      $config{"SORT_BY"} = $temp;
      push @config_vars, "SORT_BY";
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
   $tasklist_file = "\\\\view\\$view_name\\gill_vob\\6_coding\\src\\s_s\\s_s_scheduler\\src\\tasklist.asc";
   $s_s_file = "\\\\view\\$view_name\\gill_vob\\6_coding\\src\\s_s\\s_s_scheduler\\out\\s_s_cal_sched_vars.h";
}
else
{
   $error_flag = 1;
   $tasklist_file = ($tasklist_path =~ m/^\s*$/) ? "tasklist.asc" : $tasklist_path."\\tasklist.asc";
   $s_s_file = ($calvars_path =~ m/^\s*$/) ? "s_s_cal_sched_vars.h" : $calvars_path."\\s_s_cal_sched_vars.h";
}

print "\nTesting Configuration...\n";
if (($error_flag == 1) and defined $input_file)
{
   print "A valid configuration is loaded...\n";
}
else
{
   die "Invalid configuration is identified! Check the configurations in file \"$config_file\"\n";
}


# ############################################################################ #
# Reading Required Files
# ############################################################################ #

my $error_file    = $input_file."_error.txt";
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
         if (m/^SS_HIGH_TIMED_TASKS|^SS_LOW_TIMED_TASKS/)
         {
            $match_found   = 1;
            $async_regular = 1;
         }
         elsif (m/^SS_HIGH_EXTRA_TIMED_TASKS|^SS_LOW_EXTRA_TIMED_TASKS/)
         {
            $match_found = 1;
         }
      }
      # Other DCMs
      else
      {
         if (m/^SS_TIMED_TASKS|^SS_LOW_TIMED_TASKS/)
         {
            $match_found   = 1;
            $async_regular = 1;
         }
         elsif (m/^SS_EXTRA_TIMED_TASKS|^SS_LOW_EXTRA_TIMED_TASKS/)
         {
            $match_found = 1;
         }
      }
   }
   elsif ($match_found == 1)
   {
      s/\s*//g;

      # Skip the unwanted lines
      next if (m/\{|^#|^$/);
      if (m/\}/)
      {
         $match_found   = 0;
         $async_regular = 0;
         next;
      }

      # Get the slot, phase and task names
      @temp_array = split /,/;
      
      # Get Maximum Phase
      $max_phase = $temp_array[0] if ($temp_array[0] > $max_phase);

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

      # Record only the Asynchronous Regular Tasks
      if ($async_regular == 1)
      {
         if (exists $async_regular_tasks{$temp_array[2]})
         {
            push @{$async_regular_tasks{$temp_array[2]}->{'slot'}}, $temp_array[0];
            push @{$async_regular_tasks{$temp_array[2]}->{'phase'}}, $temp_array[1];

            # Maintain a count if tasks found with multiple slot and phase
            if (defined $async_regular_tasks{$temp_array[2]}->{'count'})
            {
               $async_regular_tasks{$temp_array[2]}->{'count'}++;
            }
            else
            {
               $async_regular_tasks{$temp_array[2]}->{'count'} = 1;
            }
         }
         else
         {
            $async_regular_tasks{$temp_array[2]}->{'slot'}[0] = $temp_array[0];
            $async_regular_tasks{$temp_array[2]}->{'phase'}[0] = $temp_array[1];
         }
      }
   }
}

close TASKLIST;

$max_phase--;

# ############################################################################ #
# Reading Static And Dynamic Crank Tasks
# ############################################################################ #

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
if (@lp_key_array)
{
   @lp_value_array = @{$static_lp_task{$lp_key_array[0]}};
   if ($#lp_key_array > 0)
   {
      print ERR_FILE "ERROR: Multiple teeth entries found in SS_STATIC_CRANK_LOW_TASKS!\n";
      exit 1;
   }
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

print OUTFILE "CONFIGURATION:\n\n";
foreach my $key (@config_vars)
{
   print OUTFILE "$key: $config{$key}\n";
}
print OUTFILE "MAX_PHASE: $max_phase\n";

print OUTFILE "\n\nPHASE LOADING REPORT:\n\n";

# Print report in CSV format
print OUTFILE "Slot,Loading\n";
my $i = 0;

foreach my $temp (@phase_xaxis)
{
   print OUTFILE "$i,$temp\n";
   $i++;
}

# ############################################################################ #
# TASK ID PARAMETERS
# Reading s_s_cal_sched_vars.h to identify task names
# ############################################################################ #

open(S_S_FILE, $s_s_file) or die "Unable to open \"$s_s_file\"!\n";

while (<S_S_FILE>)
{
   chomp;
   if ($match_found == 0)
   {
      $match_found = 1 if (m/\s*S_S_NO_TASK_ID = 0,/);
      push (@task_name, "S_S_NO_TASK_ID") if (m/\s*S_S_NO_TASK_ID = 0,/);
   }
   elsif ($match_found == 1)
   {
      last if (m/\} S_S_TASK_ID;/);
      s/\s*|,//g;
      push(@task_name, $_);
   }
}
close S_S_FILE;


# ############################################################################ #
# Reading input file to identify Task ID, Minimum Time, Maximum Time, Last Time.
# ############################################################################ #

open(INFILE, $input_file) or die "Unable to open input file \"$input_file\"!\n";

while (<INFILE>)
{
   chomp;

   # Identify the header
   if (m/^\D/)
   {
      next if ($header_found == 1);
      next if (!m/\bs_s_task_ident\b/);
      @temp_array = split /;/;
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
         elsif ($temp_array[$i] eq $cpu_load_str)
         {
            $cpu_load_col = $i;
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
         elsif ($temp_array[$i] eq $async_hi_time_max_str)
         {
            $async_hi_time_max_col = $i;
         }
         elsif ($temp_array[$i] eq $async_hi_time_min_str)
         {
            $async_hi_time_min_col = $i;
         }
         elsif ($temp_array[$i] eq $async_lo_time_max_str)
         {
            $async_lo_time_max_col = $i;
         }
         elsif ($temp_array[$i] eq $async_lo_time_min_str)
         {
            $async_lo_time_min_col = $i;
         }
         elsif ($temp_array[$i] eq $sync_hi_time_max_str)
         {
            $sync_hi_time_max_col = $i;
         }
         elsif ($temp_array[$i] eq $sync_hi_time_min_str)
         {
            $sync_hi_time_min_col = $i;
         }
         elsif ($temp_array[$i] eq $sync_lo_time_max_str)
         {
            $sync_lo_time_max_col = $i;
         }
         elsif ($temp_array[$i] eq $sync_lo_time_min_str)
         {
            $sync_lo_time_min_col = $i;
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

      if ($tooth_ident_col)
      {
         if (!$tooth_time_last_col || !$tooth_time_max_col || !$tooth_time_min_col)
         {
            print ERR_FILE "Error: Incorrect input file. Tooth ID/MIN/MAX/LAST time is missing!\n";
            exit 1;
         }
      }

      if (!$async_lo_time_min_col || !$async_lo_time_max_col || !$async_hi_time_min_col || !$async_hi_time_max_col || !$sync_lo_time_min_col || !$sync_lo_time_max_col || !$sync_hi_time_min_col || !$sync_hi_time_max_col)
      {
         $hi_lo_found = 1;
      }
      else
      {
         $hi_lo_found = 0;
      }

      $header_found = 1;
      next;
   }

   @temp_array = split /;/;

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
         if($hi_lo_found == 1)
         {
            # Asynchronouse HI and LO time
            $s_s_taskid{$temp_array[$task_ident_col]}->{'async_lo_min'} = $temp_array[$async_lo_time_min_col] if
                           ($temp_array[$async_lo_time_min_col] < $s_s_taskid{$temp_array[$task_ident_col]}->{'async_lo_min'});
            $s_s_taskid{$temp_array[$task_ident_col]}->{'async_lo_max'} = $temp_array[$async_lo_time_max_col] if
                           ($temp_array[$async_lo_time_max_col] > $s_s_taskid{$temp_array[$task_ident_col]}->{'async_lo_max'});
            $s_s_taskid{$temp_array[$task_ident_col]}->{'async_hi_min'} = $temp_array[$async_hi_time_min_col] if
                           ($temp_array[$async_hi_time_min_col] < $s_s_taskid{$temp_array[$task_ident_col]}->{'async_hi_min'});
            $s_s_taskid{$temp_array[$task_ident_col]}->{'async_hi_max'} = $temp_array[$async_hi_time_max_col] if
                           ($temp_array[$async_hi_time_max_col] > $s_s_taskid{$temp_array[$task_ident_col]}->{'async_hi_max'});

            # Synchronouse HI and LO time
            $s_s_taskid{$temp_array[$task_ident_col]}->{'sync_lo_min'} = $temp_array[$sync_lo_time_min_col] if
                           ($temp_array[$sync_lo_time_min_col] < $s_s_taskid{$temp_array[$task_ident_col]}->{'sync_lo_min'});
            $s_s_taskid{$temp_array[$task_ident_col]}->{'sync_lo_max'} = $temp_array[$sync_lo_time_max_col] if
                           ($temp_array[$sync_lo_time_max_col] > $s_s_taskid{$temp_array[$task_ident_col]}->{'sync_lo_max'});
            $s_s_taskid{$temp_array[$task_ident_col]}->{'sync_hi_min'} = $temp_array[$sync_hi_time_min_col] if
                           ($temp_array[$sync_hi_time_min_col] < $s_s_taskid{$temp_array[$task_ident_col]}->{'sync_hi_min'});
            $s_s_taskid{$temp_array[$task_ident_col]}->{'sync_hi_max'} = $temp_array[$sync_hi_time_max_col] if
                           ($temp_array[$sync_hi_time_max_col] > $s_s_taskid{$temp_array[$task_ident_col]}->{'sync_hi_max'});
         }

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

   if ($cpu_load_col)
   {
      $cpu_load    += $temp_array[$cpu_load_col];
      $cpu_load_min = $temp_array[$cpu_load_col] if ($temp_array[$cpu_load_col] < $cpu_load_min);
      $cpu_load_max = $temp_array[$cpu_load_col] if ($temp_array[$cpu_load_col] > $cpu_load_max);
      $cpu_load_count++;
   }

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
            print ERR_FILE "ERROR: $sync_lptooth_str changed at time \"$temp_array[$time_col]\"\n";
            push @lp_tooth, $temp_array[$sync_lptooth_col];
            exit 1;
         }
      }
   }

   if ($tooth_ident_col)
   {
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
      print ERR_FILE "No engine speed tolerance (ENGINE_SPEED_TOLERANCE) is specified in $config_file!\n";
      exit 1;
   }
   
   open(INFILE, $input_file) or die "Unable to open input file \"$input_file\"!\n";
   
   # Average engine speed
   $engine_speed /= $engine_speed_count;
   
   while (<INFILE>)
   {
      chomp;
      next if (m/^\D/);
      @temp_array = split /;/;
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
   $s_s_function_table{$task_name[$key]}->{'min'} = $s_s_taskid{$key}->{'min'};
   $s_s_function_table{$task_name[$key]}->{'max'} = $s_s_taskid{$key}->{'max'};
   $s_s_function_table{$task_name[$key]}->{'last'} = $last;
}


# ############################################################################ #
# Report Tasks for each phase
# ############################################################################ #

# Print report in CSV format
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

# ############################################################################ #
# List the Tasks under each phase
# ############################################################################ #

$a; $b;

if ($lptooth_export eq "TRUE" and $lp_tooth[0])
{
   $current_lp_teeth = $lp_tooth[0];
}
else
{
   $current_lp_teeth = $lp_key_array[0] if (@lp_key_array);
}

if (@lp_value_array)
{
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
}

if ($tooth_ident_col)
{
   # Print report in CSV format
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
}

# Report Dynamic Crank Tasks
print OUTFILE "\n\n# ############################################################################ #\n";
print OUTFILE "DYNAMIC CRANK TASKS:\n";
print OUTFILE "# ############################################################################ #\n\n";

foreach my $temp (@dyn_crank_tasks)
{
   $temp_id = "S_S_SCH_".uc($temp)."_ID";
   print OUTFILE "$temp,$s_s_function_table{$temp_id}->{'min'},$s_s_function_table{$temp_id}->{'last'},$s_s_function_table{$temp_id}->{'max'}\n";
}

# ############################################################################ #
# Report Engine Cycle Speed
# ############################################################################ #

if ($engine_speed_col)
{
   # Approximate the speed to 2 decimal places
   $engine_speed = (int($engine_speed * 100)/100);
   if ($engine_speed != 0)
   {
      $one_tooth_passing_time = (1/(($engine_speed/60) * $number_of_teeth)) * 1000000;
   }
   else
   {
      $one_tooth_passing_time = 0;
   }
   print OUTFILE "\n\n# ############################################################################ #\n";
   print OUTFILE "ENGINE CYCLE SPEED:\n";
   print OUTFILE "# ############################################################################ #\n\n";
   print OUTFILE "AVERAGE_ENGINE_CYCLE_SPEED: $engine_speed\n";
   print OUTFILE "MAXIMUM_ENGINE_CYCLE_SPEED: $engine_speed_max\n";
   print OUTFILE "MINIMUM_ENGINE_CYCLE_SPEED: $engine_speed_min\n";
   print OUTFILE "TIME_TAKEN_FOR_ONE_TOOTH_TO_PASS: $one_tooth_passing_time Micro Seconds\n";
}

# ############################################################################ #
# Report CPU LOAD
# ############################################################################ #

if ($cpu_load_col)
{
   $cpu_load /= $cpu_load_count;
   print OUTFILE "\n\n# ############################################################################ #\n";
   print OUTFILE "AVERAGE CPU LOAD:\n";
   print OUTFILE "# ############################################################################ #\n\n";
   print OUTFILE "AVERAGE_CPU_LOAD_PERCENTAGE: $cpu_load\n";
   print OUTFILE "MAXIMUM_CPU_LOAD_PERCENTAGE: $cpu_load_max\n";
   print OUTFILE "MINIMUM_CPU_LOAD_PERCENTAGE: $cpu_load_min\n";
}

# ############################################################################ #
# VW Specific Informations
# ############################################################################ #

my $temp;
my $temp_min;
my $temp_max;
my $temp_last;
my $temp_period;
my $task_period;
my $total_min = 0;
my $total_max = 0;
my $total_last = 0;
my %async_task_loads;

foreach my $key (keys %async_regular_tasks)
{
   $temp_id = "S_S_SCH_".uc($key)."_ID";
   if (exists $s_s_function_table{$temp_id})
   {
      foreach (@{$async_regular_tasks{$key}->{'slot'}})
      {
         $temp_min    = ($s_s_function_table{$temp_id}->{'min'}/$_);
         $temp_max    = ($s_s_function_table{$temp_id}->{'max'}/$_);
         $temp_last   = ($s_s_function_table{$temp_id}->{'last'}/$_);

         push @{$async_task_loads{$key}->{'min'}}, $temp_min;
         push @{$async_task_loads{$key}->{'max'}}, $temp_max;
         push @{$async_task_loads{$key}->{'last'}}, $temp_last;
         push @{$async_task_loads{$key}->{'rate'}}, $_;

         $total_min  += $temp_min;
         $total_max  += $temp_max;
         $total_last += $total_last;
      }
   }

  else
  {
     # print WARNING $key (or $temp_id) is not available in the recording
  }
}

my $async_task_report  = $input_file."_async_task_report.csv";
open (ASYNC_REPORT, ">$async_task_report") or die "Unable to create Async Task Loads report!\n";
print ASYNC_REPORT "Task Name,Task Rate,Task Period,Task Async Load % (min),Task Async Load % (avg last),Task Async Load % (max)\n";

foreach my $key (keys %async_task_loads)
{
   my $i = 0;
   foreach (@{$async_task_loads{$key}->{'rate'}})
   {
      $temp_min    = $async_task_loads{$key}->{'min'}[$i];
      $temp_max    = $async_task_loads{$key}->{'max'}[$i];
      $temp_last   = $async_task_loads{$key}->{'last'}[$i];
      $task_period = 1/$_;

      print ASYNC_REPORT "$key,$_,$task_period,$temp_min,$temp_last,$temp_max\n";
      $i++;
   }
}

close ASYNC_REPORT;
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
12.1 Tabs in the output are removed. Corrected typo in TOLERANCE.
12.2 Configurations are printed in the output file.
12.3 Removed configuration inputs OUTPUT_FORMAT, REPORT_TASKS_IN_PHASE, REPORT_TOOTH, and MAX_PHASE. MAX_PHASE is calculated from the tasklist.asc. REPORT_TASKS_IN_PHASE, REPORT_TOOTH are by default printed in the output. Added support to S_S_Cpu_load_percent in the export file.
12.4 Handled empty SS_STATIC_CRANK_LOW_TASKS in tasklist.asc
12.5 Fixed divide by zero error at 0 eRPM.
13.0 Async HI, LO and Sync HI, LO are supported.
14.0 VW Specific Async task loads are supported.
