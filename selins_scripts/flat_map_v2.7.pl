#! /usr/bin/perl

# ############################################################################ #
#
# AUTHOR  : Sai mahesh
# DATE    : 01-JUNE-2010
# VERSION : 2.7
#
# README:
#
# This code helps to flatten all the non-calibrated 2D/3D maps in Film file.
# Flattening of MAP is just assigning X[0]=X[1]=0.
#
# PREREQUISITE:
#
#       1. Perl 5.8.8 or latest.
#       2. Valid configuration file "config.inp" to feed the film name.
#          One configuration per line is allowed. Comments can be inserted
#          as a new line begining with hash symbol (#).
#       3. Ensure write permission to the directory running this script. The
#          script generates an output film of name flat_<input_film_name>.
#
# HOW TO USE:
#
#       1. Set the input film name in config.inp.
#       2. Open command window and get the directory where this script is
#          located.
#       3. Execute the following command:
#              perl flat_map.pl
#
#       4. Check the output file flat_<input_film_name> and report file
#          flat_map_report.txt in the same directory.
#
# KNOWN ISSUES:
#       1. The map requires minimum 2 axis points in X-Axis of each map.
#
# HISTORY:
#       See Footer of this code.
#
# ############################################################################ #

use strict;
use warnings;

my $x1;
my $x2;
my $key;
my $xcom;
my $xabs;
my $temp;
my $temp_flat;
my $dim_x;
my $dim_y;
my $map_name;
my $count = 0;
my $existing_count =0;
my $cur_map_val;
my $on_loop = 0;
my $x_found = 0;
my $temp_string;
my $skip_map = 0;
my $cur_map_name;
my $end2find = 0;
my $flat_type = 1;
my $map_found = 0;
my $total_maps = 0;
my $flat_index = 0;
my $loop_count = 0;
my $input_film_file;
my $maiden_find = 0;
my $add_newline = 0;
my $naming_error = 0;
my $flat_film_string;
my $film_file_type = 0;
my $naming_err_curr = 0;
my $create_flat_film = 0;
my $naming_convention = 0;
my $config_file = "config.inp";
my $existing_flat_maps = 0;
my $flap_map_exist_0=1;
my $flap_map_exist_1=1;

my @flat_maps;
my @exits_flat_maps;
my @temp_array;
my @temp_array1;
my @temp_array_exist;
my @invalid_flat_maps;

my %xcom_address;
my %xabs_address;
my %flat_map_data_val;

# ############################################################################ #
# Reading Configurtion
# ############################################################################ #

   open (DEBUG, ">debug.txt") or die "Debug failed\n";
print "\nFlat 2D/3D Map:\n";
print "\nReading Configuration file...\n";
open (CONFIG, $config_file) or die "Unable to open configuration file!\n";
while (<CONFIG>)
{
   # Skip blank lines and commented lines
   next if (m/^\s*$/ or m/^#/);
   chomp;

   # Identify settings
   @temp_array = split /=/;
   $temp = $temp_array[1];

   # Remove leading and trailing whitespaces.
   $temp =~ s/^\s*//g;
   $temp =~ s/\s*$//g;

   if ($temp_array[0] =~ m/INPUT_FILM_FILE/)
   {
      $input_film_file = $temp;
   }
   elsif ($temp_array[0] =~ m/FILM_FILE_TYPE/)
   {
      $film_file_type = 1 if ($temp =~ m/DCM/);
   }
   elsif ($temp_array[0] =~ m/NAMING_CONVENTION/)
   {
      $naming_convention = 1 if ($temp =~m/DELPHI/);
   }
   elsif ($temp_array[0] =~ m/APPLY_FLAT_MAP_TO/)
   {
      $flat_type = 0 if ($temp =~m/ALL/);
   }
   elsif ($temp_array[0] =~ m/WRITE_EXTRA_FLAT_FILM/)
   {
      $create_flat_film = 1 if ($temp =~m/YES/);
   }
   elsif ($temp_array[0] =~ m/FIRST_TWO_BREAKPOINTS_LIST_REQUIRED/)
   {
       if ($temp =~m/YES/)
       {
           $existing_flat_maps = 1;
       }
       else
       {
           $existing_flat_maps = 0;
       }
   }
}

close CONFIG;
print "Completed reading configuration file.\n\n";

# ############################################################################ #
# Validating Configurtion
# ############################################################################ #

if (!$temp)
{
   print "Invalid film name in config.inp!\n";
   exit;
}

my $out_film_file = "flat_".$input_film_file;

# ############################################################################ #
# Collecting non-calibrated flat maps
# ############################################################################ #

print "Processing Film File...\n";

open (FILM, $input_film_file) or die "Unable to open film file \"$input_film_file\"!\n";

if ($film_file_type != 1)
{
   # Support to FIL Calibration film
   while (<FILM>)
   {
      if ($naming_convention == 1)
      {
         if (m/^FILM_FilmEle/)
         {
            chomp;
            @temp_array = split /=/;
            if ($temp_array[1] !~ m/^[A-Z][A-Z_][A-Z]_/)
            {
               $naming_error = 1;
            }
            else
            {
               $naming_error = 0;
            }
         }
      }
      if(m/_VISU_X_Adresse_Com=(\d+)/)
      {
         $xcom = $1;
      }
      elsif(m/_VISU_X_Adresse_Abs=(\d+)/)
      {
         $xabs = $1;
      }
   
      if (m/_ValeurMAP_/)
      {
         chomp;
         if ($map_found == 0)
         {
            $map_found = 1;
            $naming_err_curr = $naming_error;
            @temp_array = split /=/;
            $cur_map_name = $temp_array[0];
            $cur_map_val = $temp_array[1];
            #print DEBUG "$cur_map_name\n";
   
         }
         else
         {
            next if ($skip_map == 1);
            @temp_array = split /=/;
            $skip_map = 1 if ($temp_array[1] != $cur_map_val);
         }
      }
      else
      {
         collect_flat_map();
      }
   }

   collect_flat_map() if ($map_found == 1);


#   foreach $key (@flat_maps)
#   {
#     print DEBUG "$key\n";
#   }

}
else
{
   # Support to DCM Calibration film
   while (<FILM>)
   {
      if (m/^GRUPPENKENNFELD|GRUPPENKENNLINIE/)
      {
         chomp;
         @temp_array = split;
         $map_found = 1;
         $cur_map_name = $temp_array[1];
         if ($naming_convention == 1)
         {
            if ($temp_array[1] !~ m/^[A-Z][A-Z_][A-Z]_/)
            {
               $naming_error = 1;
            }
            else
            {
               $naming_error = 0;
            }
         }
      }

      if ($map_found == 1)
      {
         if (($x_found == 0) and m/^\s*ST\/X\s+-?(\d+(\.)?(\d*)?)\s+-?(\d+(\.)?(\d*)?)/)
         {
            $x_found = 1;
            $x1 = $1;
            $x2 = $4;
         }
         elsif (m/^\s*WERT/)
         {
            next if ($skip_map == 1);
            chomp;
            @temp_array  = split;
            $temp        = shift @temp_array;
            $cur_map_val = shift @temp_array unless (defined $cur_map_val);
            foreach $temp (@temp_array)
            {
               if ($temp != $cur_map_val)
               {
                  $skip_map = 1;
                  last;
               }
            }
         }
         elsif (m/^END/)
         {
            if ($naming_convention == 1)
            {
               if ($flat_type == 1)
               {
                  push @flat_maps, $cur_map_name if ($skip_map != 1 and $naming_error == 0);
               }
               else
               {
                  push @flat_maps, $cur_map_name if ($naming_error == 0);
               }
            }
            else
            {
               if ($flat_type == 1)
               {
                  push @flat_maps, $cur_map_name if ($skip_map != 1);
               }
               else
               {
                  push @flat_maps, $cur_map_name;
               }
            }

            push @invalid_flat_maps, $cur_map_name if (($skip_map == 1) && ($x2 == 0) && ($x1 == 0));
            $x_found = 0;
            undef $x1;
            undef $x2;

            $total_maps++;
            $map_found    = 0;
            $skip_map     = 0;
            $naming_error = 0;
            $flat_map_data_val{$cur_map_name} = $cur_map_val;
            undef $cur_map_val;
         }
         else
         {
            next;
         }
      }
   }
}

close FILM;

# Get maps that share common axis
foreach $key (keys %xcom_address)
{
   push @temp_array, @{$xcom_address{$key}->{'map'}} if ($xcom_address{$key}->{'flat'} == 0);
}

foreach $key (keys %xabs_address)
{
   push @temp_array, @{$xabs_address{$key}->{'map'}} if ($xabs_address{$key}->{'flat'} == 0);
}

foreach $temp (@flat_maps)
{
   push @temp_array1, $temp if (!grep(/\b$temp\b/,@temp_array));
}

@flat_maps = @temp_array1;

# ############################################################################ #
# Flattening of Maps
# ############################################################################ #

open (FILM, $input_film_file) or die "Unable to open film file \"$input_film_file\"!\n";
open (OUTFILM, ">$out_film_file") or die "Unable to create output film. The directory might not have write access!\n";
open (REPORT, ">flat_map_report.txt") or die "Unable to create report file!\n";
if ($create_flat_film == 1)
{
   $out_film_file = "flat_only_".$input_film_file;
   open (FLATFILM, ">$out_film_file") or die "Unable to create flat only output film. The directory might not have write access!\n";
}
if($existing_flat_maps ==1)
{
open (PRESENT_FLATMAPS, ">existing_flat_map_report.txt") or die "Unable to create report file!\n";
$out_film_file = "existing_flat_".$input_film_file;
open (EXIST_FLATFILM, ">$out_film_file") or die "Unable to create flat only output film. The directory might not have write access!\n";   
}

print REPORT "Flat Map Utility V2.7:\n\n";

$temp = int((($#flat_maps+1)/$total_maps)*10000)/100;

print REPORT "VALID MAPS FOUND AS FLAT MAPS:\n";
if ($#invalid_flat_maps >= 0)
{
   print REPORT "     $_\n" foreach (@invalid_flat_maps);
   print REPORT "\n";
}
else
{
   print REPORT "NONE\n\n";
}
print REPORT "SUMMARY:\n";
print REPORT "Total Maps          - $total_maps\n";
print REPORT "Total Flat Maps     - ", $#flat_maps+1, "\n";
print REPORT "Total Flat Maps (%) - ", $temp, " %\n\n";
print REPORT "COMPLETE REPORT:\n";

if ($film_file_type != 1)
{
   my $index = 0;
   my $index_flat = 0;
   my $index_flat_exist = 0;
   my $match_string_flat;

   my $match_string = $flat_maps[$index] if ($index <= $#flat_maps);
   
   # debug
#   open (DEBUG, ">debug.txt") or die "Debug failed\n";
#   foreach $key (@flat_maps)
#   {
#     print DEBUG "$key\n";
#   }
#   close DEBUG;
   @temp_array = split /_/, $match_string;
   $temp = $temp_array[0];
   $match_string = $temp."_ValeurAxeX_";
   my $temp_copy = $temp;
   my $dim_copy =0;
   my $dim_copy_flat=0;

   if ($create_flat_film == 1)
   {
      $flat_film_string = $temp_array[0];
      $match_string_flat = $temp."_ValeurAxeX_";
   }
   if($existing_flat_maps ==1)
   {
      print PRESENT_FLATMAPS "COMPLETE LIST OF EXISTING FLAT MAPS WITH FIRST TWO BREAKPOINTS SET TO ZERO:\n\n";
   }
   while (<FILM>)
   {
      chomp;

      # MAP name
      $map_name = $1 if (m/FILM_$temp_copy=([a-zA-z0-9_]+)/);
   
       # X-length
      $dim_x = $1 if (m/$temp_copy\_Dim_X=(\d+)/);
   
      # Y-Length
      $dim_y = $1 if (m/$temp_copy\_Dim_Y=(\d+)/);

      if($existing_flat_maps ==1)
      {

           if(m/$temp_copy\_ValeurAxeX_0=(-?\d+)/)
           {
               $flap_map_exist_0 =$1;
               

           }
           if(m/$temp_copy\_ValeurAxeX_1=(-?\d+)/)
           {
               $flap_map_exist_1 =$1;
               
           }
           if(($flap_map_exist_0 == 0) and ($flap_map_exist_1 == 0) )
           {
               if (m/$temp_copy\_ValeurMAP_0_0=(-?\d+)/)
               {
                 
                   $existing_count++;
                   push @exits_flat_maps, $temp_copy; 
                   print PRESENT_FLATMAPS "$existing_count\. $map_name, X-Size: $dim_x, Y-Size: $dim_y, Value: $1\n";                   
                   $flap_map_exist_0 =1;                           
                   $flap_map_exist_1 =1;
               }
           }
      }
      # MAP Value
      if (m/$temp_copy\_ValeurMAP_0_0=(-?\d+)/)
      {

         $count++;
         print REPORT "$count\. $map_name, X-Size: $dim_x, Y-Size: $dim_y, Value: $1\n";
         $temp_copy = $temp;   

      }



      # Flattening Map
      if(m/$match_string/)
      {
         @temp_array = split /=/;
         print OUTFILM $temp_array[0],"=0\n";
         $dim_copy = $dim_copy +1;
         if($dim_copy >= $dim_x)
         { 
            $index++;
            $match_string = $flat_maps[$index] if ($index <= $#flat_maps);
            @temp_array = split /_/, $match_string;
            $temp = $temp_array[0];
            $match_string = $temp."_ValeurAxeX_";
            $dim_copy =0;
         }
      }
      else
      {
         print OUTFILM "$_\n";
      }

      if ($create_flat_film == 1)
      {
         if (m/GENERAL_Commentaire=|GENERAL_VersionVISU=/)
         {
            print FLATFILM "$_\n";
            next;
         }
         
         if (m/FILM_NombreElem=/)
         {
            @temp_array = split /=/;
            print FLATFILM "$temp_array[0]=",$#flat_maps+1,"\n";

         }
         if (m/$flat_film_string(_|=)/)
         {
              # Flattening Map
              if(m/$match_string_flat/)
              {               

                
                 @temp_array = split /=/;
                 print FLATFILM $temp_array[0],"=0\n";
                 $dim_copy_flat = $dim_copy_flat +1;
                 if($dim_copy_flat >= $dim_x)
                 { 
                    $index_flat++;
                    $match_string_flat = $flat_maps[$index_flat] if ($index_flat <= $#flat_maps);
                    @temp_array = split /_/, $match_string_flat;
                    $temp_flat = $temp_array[0];
                    $match_string_flat = $temp_flat."_ValeurAxeX_";
                    $dim_copy_flat =0;
                 }

              }
              else
              {
                 print FLATFILM "$_\n";
              }

              $on_loop = 1 if ($on_loop != 1);
    
         }

         if($on_loop == 1 and !m/$flat_film_string(_|=)/)
         {
            $on_loop = 0;
            $flat_index++;
            $flat_film_string = $flat_maps[$flat_index] if ($flat_index <= $#flat_maps);
            @temp_array = split /_/, $flat_film_string;
            $flat_film_string = $temp_array[0];
   
            if (m/$flat_film_string(_|=)/)
            {
              if(m/$match_string_flat/)
              {

                 
                 @temp_array = split /=/;
                 print FLATFILM $temp_array[0],"=0\n";
                 $dim_copy_flat = $dim_copy_flat +1;
                 if($dim_copy_flat >= $dim_x)
                 { 
                    $index_flat++;
                    $match_string_flat = $flat_maps[$index_flat] if ($index_flat <= $#flat_maps);
                    @temp_array = split /_/, $match_string_flat;
                    $temp_flat = $temp_array[0];
                    $match_string_flat = $temp_flat."_ValeurAxeX_";
                    $dim_copy_flat =0;
                 }

              }
              else
              {
                 print FLATFILM "$_\n";
              }

            }

                 
         }
   
      }
   }
   close FILM;
   open (FILM, $input_film_file) or die "Unable to open film file \"$input_film_file\"!\n";   
  if($existing_flat_maps == 1)
  {
   my $exist_match_string = $exits_flat_maps[$index_flat_exist] if ($index_flat_exist < $existing_count);                     
   my $exist_loop =0;
       while(<FILM>)
       {
             chomp;
             if (m/GENERAL_Commentaire=|GENERAL_VersionVISU=/)
             {
                print EXIST_FLATFILM  "$_\n";
                next;
             }
             
             if (m/FILM_NombreElem=/)
             {
                @temp_array = split /=/;
                print EXIST_FLATFILM "$temp_array[0]=",$existing_count,"\n";
             }

             if (m/$exist_match_string/)
             {
                print EXIST_FLATFILM "$_\n";
                $exist_loop =1 if ($exist_loop != 1);
             }        
             if(($exist_loop ==1 ) && (!m/$exist_match_string/))
             {
                 $exist_loop =0;
                 $index_flat_exist++;
                 $exist_match_string = $exits_flat_maps[$index_flat_exist] if ($index_flat_exist < $existing_count);
                 if(m/$exist_match_string/)
                 {
                     print EXIST_FLATFILM "$_\n";
                 }
             }

       }
       if($existing_count == 0)
       {
          print PRESENT_FLATMAPS "NONE\n";                   
       }
 }
}
else
{
   my $index = 0;
   my $match_string = $flat_maps[$index] if ($index <= $#flat_maps);
   $count = 0;
   $existing_count = 0;
   
   while (<FILM>)
   {
      chomp;

      # Flattening Map
      if ($loop_count == 0)
      {
         if (m/[GRUPPENKENNFELD|GRUPPENKENNLINIE]\s$match_string\s(\d+)\s?(\d*)?/)
         {
            if($2)
            {
               $end2find = 3;
            }
            else
            {
               $end2find = 2;
            }
            $maiden_find = 1;
            $loop_count  = 1;
            $count++;
            print REPORT "$count\. $match_string, X-Size: $1, Y-Size: $2, Value: $flat_map_data_val{$match_string}\n";
         }
      }

      if ($loop_count > 0)
      {
         # Process APM block
         if ($loop_count == 1)
         {
            if ($maiden_find == 1 and m/^\s*ST\/X\s+-?\d+(\.)?(\d*)?/)
            {
               if ($1)
               {
                  $temp = $2;
                  $temp =~ s/\d/0/g;
                  $temp_string = "X   0\.$temp   0\.$temp";
               }
               else
               {
                  $temp_string = "X   0   0";
               }
               $temp = $_;
               $temp =~ s/X\s+-?\d+\.?(\d*)?\s+-?\d+\.?(\d*)?/$temp_string/;
               print OUTFILM "$temp\n";
               print FLATFILM "$temp\n" if ($create_flat_film == 1);
               $maiden_find = 0;
            }
            else
            {
               if (m/^END/)
               {
                  $loop_count++;
                  $maiden_find = 1;
               }
               print OUTFILM "$_\n";

               if ($create_flat_film == 1 and $add_newline == 1)
               {
                  print FLATFILM "\n";
                  $add_newline = 0;
               }

               print FLATFILM "$_\n" if ($create_flat_film == 1);
            }
         }
         # Process BPX block
         elsif ($loop_count == 2)
         {
            if ($maiden_find == 1 and m/^\s*WERT\s+-?\d+(\.)?(\d*)?/)
            {
               if ($1)
               {
                  $temp = $2;
                  $temp =~ s/\d/0/g;
                  $temp_string = "WERT   0\.$temp   0\.$temp";
               }
               else
               {
                  $temp_string = "WERT   0   0";
               }
               $temp = $_;
               $temp =~ s/WERT\s+-?\d+\.?(\d*)?\s+-?\d+\.?(\d*)?/$temp_string/;
               print OUTFILM "$temp\n";
               print FLATFILM "$temp\n" if ($create_flat_film == 1);
               $maiden_find = 0;
            }
            else
            {
               if (m/^END/)
               {
                  if ($loop_count < $end2find)
                  {
                     $loop_count++;
                  }
                  else
                  {
                     $loop_count  = 0;
                     $end2find    = 0;
                     $maiden_find = 0;
                     $add_newline = 1 if ($create_flat_film == 1);
                     $index++;
                     $match_string = $flat_maps[$index] if ($index <= $#flat_maps);
                  }
               }
               print OUTFILM "$_\n";
               print FLATFILM "$_\n" if ($create_flat_film == 1);
            }
         }
         # Process BPY block
         elsif ($loop_count == 3)
         {
            if (m/^END/)
            {
               $loop_count  = 0;
               $maiden_find = 0;
               $end2find    = 0;
               $add_newline = 1 if ($create_flat_film == 1);
               $index++;
               $match_string = $flat_maps[$index] if ($index <= $#flat_maps);
            }
            print OUTFILM "$_\n";
            print FLATFILM "$_\n" if ($create_flat_film == 1);
         }
      }
      else
      {
         print OUTFILM "$_\n";
      }
   }
}

close FLATFILM if ($create_flat_film == 1);
close FILM;
close EXIST_FLATFILM  if ($existing_flat_maps == 1);
close REPORT;
close OUTFILM;
close PRESENT_FLATMAPS if ($existing_flat_maps == 1);
print "Film file is processed and all 2D/3D maps are flatten!\n\n";
sub collect_flat_map {
  if ($map_found == 1)
  {
     if ($naming_convention == 1)
     {
        if ($flat_type == 1)
        {
           push @flat_maps, $cur_map_name if ($skip_map != 1 and $naming_err_curr == 0);
        }
        else
        {
           push @flat_maps, $cur_map_name if ($naming_err_curr == 0);
        }
     }
     else
     {
        if ($flat_type == 1)
        {
           push @flat_maps, $cur_map_name if ($skip_map != 1);
        }
        else
        {
           push @flat_maps, $cur_map_name;
        }
     }

     print DEBUG "$cur_map_name\n";

     # COM Address
     if (exists $xcom_address{$xcom})
     {
        # Flat Maps
        $xcom_address{$xcom}{'flat'} = 0 if ($skip_map == 1);
        push @{$xcom_address{$xcom}->{'map'}}, $cur_map_name;
     }
     else
     {
        # Flat Maps
        if ($skip_map == 0)
        {
           $xcom_address{$xcom}{'flat'} = 1;
        }
        # Non-Flat Maps
        else
        {
           $xcom_address{$xcom}{'flat'} = 0;
        }
        $xcom_address{$xcom}->{'map'}[0] = $cur_map_name;
     }

     # ABS Addresses
     if (exists $xabs_address{$xabs})
     {
        # Flat Maps
        $xabs_address{$xabs}{'flat'} = 0 if ($skip_map == 1);
        push @{$xabs_address{$xabs}->{'map'}}, $cur_map_name;
     }
     else
     {
        # Flat Maps
        if ($skip_map == 0)
        {
           $xabs_address{$xabs}{'flat'} = 1;
        }
        # Non-Flat Maps
        else
        {
           $xabs_address{$xabs}{'flat'} = 0;
        }
        $xabs_address{$xabs}->{'map'}[0] = $cur_map_name;
     }

     $total_maps++;
     $skip_map = 0;
     $map_found = 0;
     $naming_err_curr = 0;
  }
}

__END__
# Version History
1.0 - Initial Revision
2.0 - Flatening only Non-Calibrated Maps
2.1 - Added new features to display name, x-size, y-size and value.
2.11 - Total number of maps are displayed in the report
2.2  - Added Delphi Naming convention. Option to flat map everything.
       Option to write out extra flat map film.
2.3  - Added support to DCM calibration film types.
2.4  - Added provision to report Non-flat maps with axis X[0], X[1] set to Zero (Ford Request).
2.5  - Detected maps sharing common axis value. None of those maps will be flatten if any
       one map is not a flat map.
2.6  - SAI ->Flat mapped all the x axis breakpoint instead of only x[0] and x[1], introduced list of existing flatmaps with x[0] and x[1] set to        zero.
2.7  - The flat_only_<input file name>.FIL contains the maps which have been flatmapped only.