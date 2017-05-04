#!/usr/bin/perl
########################################################################
#                    Delphi Diesel Systems
#*
#*                   This document is the property of
#*                   Delphi Diesel Systems
#*                   It must not be copied (in whole or in part)
#*                   or disclosed without prior written consent
#*                   of the company. Any copies by any method
#*                   must also include a copy of this legend.
#######################################################################
# 
# Description: Cleans and rebuilds
#
#              John Oldman 10/11/2011
#
########################################################################
# DATE       # DESCRIPTION                                       #     # 
#------------#---------------------------------------------------#-----#
# 02-02-2012 # Initial version                                   # JRO #                 
#            #                                                   #     #                 
#            #                                                   #     #                 
#            #                                                   #     #                 
#            #                                                   #     #                 
#            #                                                   #     #                 
########################################################################
use strict;
use Win32::OLE;
use Getopt::Long;
use FileHandle;
use File::Copy;
use File::Basename;
use Cwd;

# Flush buffers!
$| = 1;

#
# local variables
#
my $version             = "0.01";

# make sure we have a CR number
if(scalar @ARGV != 1)
{
    die "\nUsage: clean_rebuild <CR_NUMBER>\n";
}

my $cr_num = $ARGV[0];
my $project_dir         = "c:\\oldman\\CRs\\Projects\\GV000$cr_num";
my $outfile             = "buildlog";

print "clean_rebuild $version\n";
print "==================\n";
print "cr number gv$cr_num\n";

my $root_dir = "m:\\task_oldmanj_gv$cr_num\\gill_vob\\6_coding";
print "root directory: $root_dir\n";

print "cleaning build\n";
chdir("M:\\") or die "Can't change directory to M:\\";
chdir($root_dir) or die "Can't change directory to $root_dir";
my $runstring = "build clean";
system($runstring);

print "build\n";
my $logfile_name = get_file_name($outfile);
$runstring = "build GEN_QAC=no GEN_FILELIST=yes > $logfile_name 2>&1";
print "$runstring\n";
system($runstring);

print "duplicate checker\n";
$runstring = "copy C:\\oldman\\development\\perl_scripts\\list_t55_duplicates.pl $root_dir\\list_t55_duplicates.pl";
print "$runstring\n";
system($runstring);
chdir("M:\\") or die "Can't change directory to M:\\";
chdir($root_dir) or die "Can't change directory to $root_dir";
$runstring = "perl $root_dir\\list_t55_duplicates.pl";
print "$runstring\n";
system($runstring);

print "clean_rebuild ended...\n";

#send popup
my $popupbanner = "Rebuild_Completed_GV$cr_num";
$runstring = "perl c:\\oldman\\development\\perl_scripts\\popup.pl $popupbanner";
system($runstring);

# close the window
system("exit");


#
# If suggested file exists, increments suffix until an unused filename is found
#
sub get_file_name()
{
    my($base_name)    = shift;    
    my $suffix        = 0;    
    my $new_file_name = $base_name . "_" . $suffix . ".txt";
    
    while(-e $new_file_name)
    {
	$new_file_name = $base_name . "_" . $suffix++ . ".txt";
    }
    
    return $new_file_name;
}

