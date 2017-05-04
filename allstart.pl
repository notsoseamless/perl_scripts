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
# Description: Script makes start up faster
#
#              John Oldman 10/11/2011
#
########################################################################
# DATE       # DESCRIPTION                                       #     # 
#------------#---------------------------------------------------#-----#
# 10-11-2011 # Initial version                                   # JRO #                 
#            #                                                   #     #                 
#            #                                                   #     #                 
#            #                                                   #     #                 
#            #                                                   #     #                 
#            #                                                   #     #                 
########################################################################
use strict
use Win32::OLE
use Getopt::Long
use FileHandle
use File::Copy
use File::Basename
use Cwd

# Flush those buffers!
$| = 1

#
# local variables
#
my $version             = "0.01"

# make sure we have a CR number
if(scalar @ARGV != 1)
{
    die "\nUsage: allstart <CR_NUMBER>\n"
}

my $cr_num = $ARGV[0]
my $project_dir         = "c:\\oldman\\CRs\\Projects\\GV000$cr_num"
my $outfile             = "buildlog"

print "Allstart $version\n"
print "=================\n"
print "cr number gv$cr_num\n"

print "set up environment\n"
# call the Delphi tstart script
my $runstring = "tstart $cr_num"
system($runstring)

my $root_dir = "m:\\task_oldmanj_gv$cr_num\\gill_vob\\6_coding"
print "root directory: $root_dir\n"

# CREATE PROJECT DIRECTORY FOR LOCAL DRIVE

print "create project directory\n"
$runstring = "m:"
system($runstring)
$runstring = "cd $root_dir"
system($runstring)
$runstring = "mkdir $project_dir"
system($runstring)

print "create notes file\n"
my $tempString = '_notes.txt'
$runstring = "copy C:\\oldman\\CRs\\cr_check_list.tex $project_dir\\GV000$cr_num$tempString"
system($runstring)

print "create spec branch info file\n"
my $tempString = '_SYMC_Spec_Branch.xls'
$runstring = "copy C:\\oldman\\CRs\\SYMC_Spec_Branch.xls $project_dir\\GV000$cr_num$tempString"
system($runstring)

print "create t55 template\n"
$runstring = "copy C:\\oldman\\CRs\\lowercase_file_name_dd.t55 $project_dir\\t55_template.t55"
system($runstring)

print "create resolution zip file\n"
$tempString = "_resolution.zip"
$runstring = "copy C:\\oldman\\CRs\\blank_resolution.zip $project_dir\\GV000$cr_num$tempString"
system($runstring)

print "create directory for any visu stuff\n"
$runstring = "mkdir $project_dir\\GV000$cr_num . visu"

print "build\n"
chdir("M:\\") or die "Can't change directory to M:\\"
chdir($root_dir) or die "Can't change directory to $root_dir"
my $logfile_name = get_file_name($outfile)
$runstring = "build GEN_QAC=no GEN_FILELIST=yes > $logfile_name 2>&1"
print "$runstring\n"
system($runstring)

print "duplicate checker\n"
$runstring = "copy C:\\oldman\\development\\perl_scripts\\list_t55_duplicates.pl $root_dir\\list_t55_duplicates.pl"
print "$runstring\n"
system($runstring)
chdir("M:\\") or die "Can't change directory to M:\\"
chdir($root_dir) or die "Can't change directory to $root_dir"
$runstring = "perl $root_dir\\list_t55_duplicates.pl"
print "$runstring\n"
system($runstring)

print "Allstart ended...\n"

#send popup
my $popupbanner = "Build_Completed_GV000$cr_num"
$runstring = "perl c:\\oldman\\development\\perl_scripts\\popup.pl $popupbanner"
system($runstring)

# close dos window
system("exit")


#
# If suggested file exists, increments suffix until an unused filename is found
#
sub get_file_name()
{
    my($base_name)    = shift    
    my $suffix        = 0    
    my $new_file_name = $base_name . "_" . $suffix . ".txt"
    
    while(-e $new_file_name)
    {
	$new_file_name = $base_name . "_" . $suffix++ . ".txt"
    }
    
    return $new_file_name
}

