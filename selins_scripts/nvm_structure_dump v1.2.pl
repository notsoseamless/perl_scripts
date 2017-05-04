#!/usr/bin/perl
########################################################################
#                   Delphi Diesel Systems
#
#                   This document is the property of
#                   Delphi Diesel Systems
#                   It must not be copied (in whole or in part)
#                   or disclosed without prior written consent
#                   of the company. Any copies by any method
#                   must also include a copy of this legend.
#######################################################################
# 
# Description: Prints the NVV variables within each object of the NVM
#              structure. Note, this is not just the NVV variables that
#              appear within each object, but also those associated
#              NVV variables that also appear within each recovery_obj
#              block alongside them. The data is printed to the file 
#              nvm_structure_dump.txt.
#
# Usage      : perl nvm_structure_dump.pl (Best run from within the 
#              6_coding directory).
#
########################################################################
#
# Version History:
# ----------------
#
# Date     | Developer  | Version | Description
# ----     | ---------  | ------- | -----------
# 02/03/10   E.Basson      1.0      Initial version.
# 29/04/10   E.Basson      1.1      Make non path-dependent. If not in 
#                                   the 6_coding dir, will ask for path.
#                                   Also now writes output to file.
# 06/05/10   E.Basson      1.2      Correct recover_obj logic so that 
#                                   all associated NVVs are printed.
#
########################################################################

use strict;
use Win32::OLE;
use Getopt::Long;
use FileHandle;
use File::Copy;
use File::Basename;
use Cwd;
use Fcntl qw[ :seek ];


# Flush buffers.
$| = 1;


my $orig_nvm_data_path   = "src/p_l/p_l_nvm/src/p_l_nvm_data.c";
my $orig_nvm_server_path = "src/p_l/p_l_nvm/src/p_l_nvm_server.c";
my $orig_app_h_path      = "src/appli/_appli/src/app.h";
my $six_coding_dir       = "/gill_vob/6_coding/";
my $nvm_filename         = "nvm_structure_dump.txt";
my $list_object          = "P_L_NVM_OBJ_CFG_PTR_LIST";
my $current_dir          = cwd;


my $nvm_outputfile             = "";
my $nvm_data_path              = "";
my $nvm_server_path            = "";
my $app_h_path                 = "";
my $debug                      = 0;
my $found                      = 0;
my $found_struct               = 0;
my $found_struct_ltv           = 0;
my $app_pulse_count_fitted_cpv = 0;
my $app_pulse_count_found      = 0;
my $count                      = 0;
my $total_objects              = 0;
my $objs                       = 0;
my $i                          = 0;
my @data_structs               = (); 
my @temp_array                 = ();
my %nvv_assignments            = ();
my %data_objs                  = ();


#
# If the user is sitting in the 6_coding directory then we'll just
# run this program without any further intervention. However if the
# user is anywhere else we're not going to try and second-guess what
# they want. We'll simply ask where they want the program to be run from.
#
if ( -f "build.bat" && $current_dir =~ /6_coding$/ )
{
    # 
    # We're in the right place to run this program.
    #
    $nvm_data_path   = $orig_nvm_data_path;
    $nvm_server_path = $orig_nvm_server_path;
    $app_h_path      = $orig_app_h_path;
    $nvm_outputfile  = $nvm_filename;
}
else
{
    print "\nEnter your required view name, excluding any drive letters.\n";
    print "For example U1A92B00 or task_user_gv1234.\n";
    print "\nView Name: ";
    my $view_name = <>;
    chomp $view_name;
    my $view_path = "M:/" . $view_name . "/";
    if ( -d $view_path )
    {
        #
        # Append the given path to our paths.
        #
        $nvm_data_path   = $view_path . $six_coding_dir  . $orig_nvm_data_path;
        $nvm_server_path = $view_path . $six_coding_dir  . $orig_nvm_server_path;
        $app_h_path      = $view_path . $six_coding_dir  . $orig_app_h_path;
        $nvm_outputfile  = $view_path . $six_coding_dir  . $nvm_filename;
        print "Please wait...\n";
    }
    else
    {
        print "Error, cannot find this path. Exiting.\n";
        exit;
    }
}
    

# Prototypes
sub set_pulse_count_fitted_cpv();
sub select_objs_in_list_struct();
sub populate_obj_details();
sub populate_nvv_details();


#############################################################################
#
#  START OF PROGRAM 
#
#############################################################################
print "Generating a dump of the NVM structure. Please wait...\n";
    
print "DEBUG: Checking value of APP_PULSE_COUNT_FITTED_CPV define\n" if ( 1 == $debug );
&set_pulse_count_fitted_cpv();

#
# Now open pl_nvm_data.c and search for our struct.
#
print "DEBUG: Opening $nvm_data_path\n" if ( 1 == $debug );
open( NVM, $nvm_data_path ) or die "Cannot open nvm data module: $!\n"; 

print "DEBUG: Selecting objects within list struct\n" if ( 1 == $debug );
&select_objs_in_list_struct( *NVM);

#
# We'll go through this file again as many of the structs within P_L_NVM_OBJ_CFG_PTR_LIST
# are defined here too. 
#
print "DEBUG: Seeking to start of file\n" if ( 1 == $debug );
seek NVM, 0, SEEK_SET or die "Cannot seek on nvm data module: $!\n";
$. = 1;    # reset the line count.
print "DEBUG: Populating object details from $nvm_data_path\n" if ( 1 == $debug );
&populate_obj_details( *NVM);

# 
# Okay, we'll go through the file one more time. This time we'll pick-up all the 
# NVV variable assignments. Note, we could have processed this file in one go, but
# then it makes it more difficult to componentise this program, and thus it becomes
# less manageable and less mantainable. The overhead of processing the same file is
# neglible anyway.
#
print "DEBUG: Seeking to start of file\n" if ( 1 == $debug );
seek NVM, 0, SEEK_SET or die "Cannot seek on nvm data module: $!\n";
$. = 1;    # reset the line count.
print "DEBUG: Populating NVV details from $nvm_data_path\n" if ( 1 == $debug );
&populate_nvv_details( *NVM);
close( NVM );

#
# We'll now open the second file that contains the object definitions to complete
# our population (p_l_nvm_server.c).
#
print "DEBUG: Opening $nvm_server_path\n" if ( 1 == $debug );
open( NVM, $nvm_server_path ) or die "Cannot open nvm server module: $!\n"; 
print "DEBUG: Populating object details from $nvm_server_path\n" if ( 1 == $debug );
&populate_obj_details( *NVM);
close( NVM );

#
# Finally, we'll print off the results.
#
&print_results();
print "Program complete. Output can be found in $nvm_outputfile\n";

#
# Sanity check. This should never print out!
#
if ( $count != $total_objects )
{
    print "\n\nWarning, found $total_objects objects within $list_object, but populated $count objects\n";
}    



#############################################################################
#
#  SUBROUTINES
#
#############################################################################

#
# There is a #define within the P_L_NVM_OBJ_CFG_PTR_LIST struct.
# To see if it is actually defined, we need to look inside app.h
#
sub set_pulse_count_fitted_cpv()
{
    open( APP, $app_h_path ) or die "Cannot open app header: $!\n"; 
    while (<APP>)
    {
        next if ( $_ !~ /APP_PULSE_COUNT_FITTED_CPV/ );
        $app_pulse_count_fitted_cpv = 1;
        last;
    }
    close( APP );
}



#
# Find the list struct and store all the main objects found within.
#
sub select_objs_in_list_struct()
{
    local *FH = shift; 
    while (<FH>)
    {
        next if /^extern/g;                          # Ignore externs.
        next if /^(\s)*$/;                           # Skip blank lines.
        next if $_ =~ m/^\/\*/g;                     # Ignore comments.
    
        # Check for start of define.
        if ( $_ =~ /APP_PULSE_COUNT_FITTED_CPV/g )
        {
            $app_pulse_count_found = 1;
            next;
        }

        # Check for end of define.    
        if ( $_ =~ m/\#endif/g )
        {
            $app_pulse_count_found = 0;
            next;
        }
    
        # Act on result of define.
        if ( 1 == $app_pulse_count_found )
        {
            # skip this if it's not defined.
            next if ( 0 == $app_pulse_count_fitted_cpv );
        }
    
        if ( $_ =~ m/P_L_NVM_OBJ_CFG_PTR_LIST/g )
        {
            $found = 1;
            next;
        }
    
        if ( 1 == $found && $_ =~ m/\}\;/ )
        {
            $found = 0;
        }
    
        if ( 1 == $found )
        {
            # If we're here, then we're inside the list struct
            # and have a valid object. Now store the object name.
            $_ =~ s/\&//g;                           # Strip off address operator.
            $_ =~ s/\,//g;                           # Strip trailing comma. 
            $_ =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;    # Strip white space.
            $_ =~ s/(\S*).*/$1/;
            $total_objects++;
            printf "DEBUG: %-2d - \"$_\"\n", $total_objects if ( 1 == $debug );
            push (@data_structs, $_); 
        }
    }
 
    if ( 1 == $debug )
    {    
        printf "DEBUG: Sizeof \@data_structs is %d elements\n", ($#data_structs +1);
        for ( my $i = 0; $i < $#data_structs + 1; $i++ )
        {
            print "DEBUG: $i - $data_structs[$i]\n";
        }
    }
}



#
# Searches the opened file for definitions listed within $data_structs. If found
# it is added to a hash of arrays, providing all the variables within that object.
#
sub populate_obj_details()
{
    local *FH = shift; 

    while (<FH>)
    {
        $found_struct_ltv = $found_struct;
        next if /^extern/g;                                  # Ignore externs.
        next if /^(\s)*$/;                                   # Skip blank lines.
        next if ( /^\/\*/ || /^\*\*/ || /^\*/ || /^\#/ );    # Skip comments and defines.
    
        # 
        # This time we want to ignore the definition of P_L_NVM_OBJ_CFG_PTR_LIST
        # because we're searching for the definition of the structs within it.    
        #
        if ( $_ =~ m/$list_object/g )
        {
             $found = 1;
             next;
        }
    
        $found = 0 if ( 1 == $found && $_ =~ m/\}\;/ );
        next if ( 1 == $found );

        if ( 0 == $found_struct && $#data_structs > 0 && 0 == $found )
        {
            for( $count = 0; $count <= $#data_structs; $count++ )
            {
                # Have we found a definition of a struct defined within P_L_NVM_OBJ_CFG_PTR_LIST?
                if ( $_ =~ /$data_structs[$count]/g )
                {
                    $_ =~ s/^\s*(\S*(?:\s+\S+)*)/$1/;    # Strip leading white space.
                    my @dataline = split( / /, $_ );
                    push( @temp_array, $dataline[1] );    # Type Name
                    $found_struct = 1;
                    last;
                }
            }
        }
        next if ( 1 == $found_struct && $_ =~ m/\{/ );
        if ( 1 == $found_struct && $_ =~ m/\}\;/ )
        {
            $found_struct = 0;
            # 
            # The temporary array is fully populated now with all the structure details.
            # Buffer it into the data_objs hash and clear the array.
            #
            $data_objs{$data_structs[$count]} = [ @temp_array ];
            @temp_array = ();
            next;
        }

        $_ =~ s/\,(.*)$//g;                      # Strip trailing comma and any junk on end. 
        $_ =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;    # Strip white space.
        push( @temp_array, $_ ) unless (0 == $found_struct_ltv);       # Data member
    }
}



#
# Searches the opened file for nvv assignments. If found they are added to a
# hash of arrays, with the principal nvv for each recover_obj block acting as
# the key. 
#
sub populate_nvv_details()
{
    local *FH = shift; 
    my @recover_block          = ();
    my $recover_obj_found      = 0;
    my $indent_count           = 0;
    my $nvm_data_section_count = 0;
    my $nvm_data_section_found = 0;
    my $nvv_name               = "";
    my @temp                   = ();    
    
    while (<FH>)
    {
        next if /^(\s)*$/;                                   # Skip blank lines.
        next if ( /^\/\*/ || /^\*\*/ || /^\*/ || /^\#/ );    # Skip comments and defines.

        if ( 0 == $nvm_data_section_found && /NVM_DATA_SECTION/ && /padding/ )
        {
            $nvm_data_section_found = 1;
            next;
        }

        #
        # The NVM_DATA_SECTION declaration for the NVV comes directly after
        # the padding declaration.
        if ( 1 == $nvm_data_section_found && /NVM_DATA_SECTION/ )
        {
            @temp = split( " ", $_ );
            $nvv_name = $temp[2];
            $nvv_name =~ s/(\w*)(.*)/$1/;   # Strip array indexes.
            $nvm_data_section_found = 0;
            next;
        }
        
        next if ( 1 == $nvm_data_section_found );
        
        
        
        # Pick up all nvv assignments if they are within the recover_obj block.
        if ( /TRUE\s\=\=\srecover_obj/g )
        {
            # Start of "TRUE == recover_obj" block
            $recover_obj_found = 1;
            next;
        }
        if ( 1 == $recover_obj_found && /\{/g )
        {
            # Maintain count of nests within "TRUE == recover_obj" block
            $indent_count++;
            next;
        }
        if ( 1 == $recover_obj_found && /\}/g )
        {
            # Maintain count of nests within "TRUE == recover_obj" block
            $indent_count--;
        }
        if ( 1 == $recover_obj_found && 0 == $indent_count )
        { 
            #
            # No longer in "TRUE == recover_obj" block. Buffer any NVV 
            # assignments that we have found.
            #
            $recover_obj_found = 0;
            $nvv_assignments{$nvv_name} = [ @recover_block ];
            @recover_block = ();
        }
        
        next if (0 == $recover_obj_found );
        
        
        # Check for assignments not within a conditional.
        if ( $_ =~ /\=/ && $_ !~ /\<|\+|corrupted/ )
        {
            $_ =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;    # Strip white space.
            push ( @recover_block, $_ );
        }
    }
    if ( 1 == $debug )
    {    
        foreach my $nvv ( keys %nvv_assignments )
        {
            print "DEBUG: $nvv\n"; 
            foreach my $i ( 0 .. $#{ $nvv_assignments{$nvv} } ) 
            {   
                print "    DEBUG: $i - $nvv_assignments{$nvv}[$i]\n";
            }
        }
    }
}



#
# Print out our results.
#
sub print_results()
{
    $count         = 0;
    my $found      = 0;
    my $nvv_count  = 0;
    my $nvv_match  = 0;
    my $nvv;
    my @counts_matched = ();

    open( F, ">$nvm_outputfile" ) or die "Cannot open $nvm_outputfile: $!\n"; 
    
    #
    # Dump each key in the hash followed by all the associated array contents.
    #
    for ( my $j = 0; $j < $#data_structs +1; $j++ )
    {     
        $count++;
        print F "\n$count: $data_structs[$j]\n"; 
        foreach $i ( 0 .. $#{ $data_objs{$data_structs[$j]} } ) 
        {   
            $found = 0;
            if ( 1 == $i )
            {
                #
                # The second item in the array is the nvv. Here we need to also dump
                # out any associated nvv assignments.
                # To make an accurate comparison with our nvv data, we
                # need to modify the nvv item stored in our hash of arrays.
                #
                $data_objs{$data_structs[$j]}[$i] =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;    # Strip white space.
                $data_objs{$data_structs[$j]}[$i] =~ s/^\&//g;                          # Strip off address operator.
                $data_objs{$data_structs[$j]}[$i] =~ s/(\w*)(.*)/$1/;                   # Strip array indexes.

                foreach $nvv (keys %nvv_assignments )
                {
                    $found = 0;
                    if ( $nvv =~ /$data_objs{$data_structs[$j]}[$i]/ )
                    {
                        $found = 1;
                    }
                    
                    if ( 1 == $found )
                    {
                        #
                        # The NVV declared within the NVM object has been found.
                        #
                        foreach my $i ( 0 .. $#{ $nvv_assignments{$nvv} } ) 
                        {   
                            $nvv_assignments{$nvv}[$i] =~ s/^\s*(\S*(?:\s+\S+)*)/$1/;    # Strip white space.
                            chomp $nvv_assignments{$nvv}[$i];
                            print F "    $nvv_assignments{$nvv}[$i]\n";
                        }                            
                    }                    
                }
            }
        }
    }
    
    close(F);
}
