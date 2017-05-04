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
# Description: This program compiles source files entered at run time
#              Looks in config.py for the source path.
#
#              John Oldman (16/11/10)
#
########################################################################
use strict;
use Win32::OLE;
use Getopt::Long;
use FileHandle;
use File::Copy;
use File::Basename;
use Cwd;


# Flush those buffers!
$| = 1;


my $debug               = 1;  
my $current_dir         = cwd;
my @dataline            = ();
my @pathline            = ();
my $pathcount           = 0;
my $numArgs             = 0;
my $argnum              = 0;
my $config              = "config.py";
my $crnumber            = 0;
my $root                = "m:\\task_oldmanj_gv";
my $path                = "\gill_vob\\6_coding";


if($debug)
{
    print "debug mode\n";
}


#
# read in the run-time source file(s)
#
# run time parameters:
#    CR number
#    file(s) to compile
#
$numArgs = $#ARGV + 1;
if( 1 < $numArgs )
{
    if($debug)
    {
        my $numoffiles = $numArgs-1;
        print "You gave $numoffiles source file(s) for compilation:\n";
        print "CR = $ARGV[0]\n";
        foreach $argnum (1 .. $#ARGV) 
        {
            print "$ARGV[$argnum]\n";
        }
    }
}
else
{
    print "Usage\n";
    print "Compile_file.pl <CR_NUMBER> <file_name> [<file_name>]\n";
    exit;   
}


$crnumber = $ARGV[0];
#
# set up root and path
#
$root = "$root$crnumber";
$path = "$root\\$path";


if($debug)
{
    print "root directory: $root\n";
    print "path directory: $path\n";
}


#
# step through config.py searching for source paths
#
print "Searching config.py for the compile command(s) for path data\n";
if($debug)
{
    print "Opening  $path\\$config\n";
}
open( CONFIG_PY, "$path\\$config" ) or die "Can't open config.py\n";
while (<CONFIG_PY>)
{
    next if /^(\s)*$/;               # Skip blank lines.
    next if ( /^\#/ );               # Skip comments.

    if ( /SourceFile/g )
    {
        @dataline = split( ",", $_ );
        $dataline[0] =~ s/.*(\'.*\').*/$1/;               # strip any supplementary fields
        $dataline[0] =~ s/\'//g;                          # strip surrounding inverted commas
        $dataline[0] =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;   # strip all leading and trailing white space
        
        foreach $argnum (1 .. $#ARGV) 
        {
            # look in each line for each source file
            my $tempstr = $ARGV[$argnum];
            if( $dataline[0] =~ m/\b$tempstr\b/ )
            {
                if($debug)
                {
                    print "Found $dataline[0]\n";
                }
                @pathline[$pathcount] = $dataline[0];
                $pathcount++;
            }
        }
    }
}
close CONFIG_PY;



#sub compile_file;


#
# compile the files
#
foreach $pathcount (0 .. $pathcount-1)
{
    my $sourcename = $pathline[$pathcount];
    my $objectname = $sourcename;
    $objectname    =~ s/\.c/\.o/g;          # replace .c for .o
    my $srcstr     = "/src/";
    my $objstr     = "/out/";
    $objectname    =~ s/$srcstr/$objstr/;   # replace src with out
    $objectname    =~ s/\//\\/g;            # replace all / for \\
    $sourcename    =~ s/\//\\/g;            # replace all / for \\


# note
# Replace back slash with slash for make
# $out_dir =~ s/\\/\//g ;




	# set up full source and object paths
    $sourcename = "$sourcename";
    $objectname = "$objectname";
    if($debug)
    {
        print "source path:    $sourcename\n"; 
        print "object path:    $objectname\n";
    }
    
    $sourcename = "$path\\$sourcename";
    $objectname = "$path\\$objectname";

	# set up full include paths
    my $autogen_path   = "-I$path\\src\\autogen\\src";
	my $scheduler_path = "-I$path\\src\\s_s\\s_s_scheduler\\src";
	my $include_path   = "-I$path\\src\\include";
    
    if($debug)
    {
        print "source path:    $sourcename\n"; 
        print "object path:    $objectname\n";
        print "autogen_path:   $autogen_path\n";
        print "scheduler_path: $scheduler_path\n";
        print "include_path:   $include_path\n";
    }	

   &compile_file($sourcename, $objectname, $autogen_path, $scheduler_path, $include_path );
}



##############################################################################
#    SUBROUTINES
##############################################################################

#
# call the compiler
#
sub compile_file()
{
    my $runstring = "$root\\ldcr_tools\\gnu\\GNUSH-ELF\\v0603\\sh-elf\\bin\\sh-elf-gcc.exe @_[2] @_[3] @_[4] -DMKF_SW_ID=\"$crnumber\" -DNUM_INJECTORS=4 -DAPP_MAX_NUMBER_OF_INJECTORS_CPV=NUM_INJECTORS -D_HWI_BASE_ -DINTEGER_CODE -DNO_FLOATS -Deg8157 -include types.h -include hwi_memory_section.h -include euro5_stubs.h -Os -g -g3 -gdwarf-2 -fshort-enums -fno-unit-at-a-time -finline-functions-called-once -misize -m2a-nofpu -mb -Wall -W -Wbad-function-cast -Wcast-align -Wmissing-declarations -Wmissing-prototypes -Wnested-externs -Wpointer-arith -Wredundant-decls -Wstrict-prototypes -fomit-frame-pointer -pipe -o @_[1] -c @_[0]";
    if($debug)
    {
        print "Runstring: [$runstring]\n";
    }
    qx($runstring);
}

