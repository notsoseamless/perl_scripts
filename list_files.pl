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
# Description: file list generator for source insight
#
#              John Oldman (01/12/2011)
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

#
# local variables
#
my $version             = "1.02";
my $current_dir         = cwd;
my $config              = "config.py";
my $outfile             = "si_file_list";
my @src_filelist        = ();
my @header_filelist     = ();
my @t55_filelist        = ();
my @recordlist          = ();
my $src_count           = 0;
my $header_count        = 0;
my $t55_count           = 0;
my $start               = 0;
my $end                 = 0;

if ( $current_dir !~ /6_coding/g )
{
    print "Error: This program must be run from 6_coding\n";
    exit;
}

print "Version $version\n";
print "simple file listing routine\n";
$start = (times)[0];


# list all t55 files
# list all header files
# list all c files
# identify symbolic links and replace with real file


#
# get list of source file names from config file
#
print "Current directory: $current_dir\n";

open( CONFIG, $config ) or die "Can't open $config\n";
print "Scanning $config\n";
while (<CONFIG>)
{
	my($line) = $_;

	if ($line =~ /SourceFile\('([\w\/\.]+)'[\,\)]/)
	{
		# strip surrounding SourceFile(' ')
		$line =~ s/\SourceFile//g;
		$line =~ s/\(//g;
		$line =~ s/\)//g;
		$line =~ s/\'//g;
		

		# put into indexed list
		$src_filelist[$src_count] = $line;
		print $line;
		print "\n";
	        $src_count++;
	}
	elsif ($line =~ /HeaderFile\('([\w\/\.]+)'[\,\)]/)
	{
		# strip surrounding HeaderFile(' ')
		$line =~ s/\HeaderFile//g;
		$line =~ s/\(//g;
		$line =~ s/\)//g;
		$line =~ s/\'//g;

		# put into indexed list
		$header_filelist[$header_count] = $line;
		$header_count++;
	}
	elsif ($line =~ /T55File\('([\w\/\.]+)'[\,\)]/)
	{
		# strip surrounding T55File(' ')
		$line =~ s/\T55File//g;
		$line =~ s/\(//g;
		$line =~ s/\)//g;
		$line =~ s/\'//g;

		# put into indexed list
		$t55_filelist[$t55_count] = $line;
		$t55_count++;
	}
	else
	{
		# do nothing
	}

}
close CONFIG;
print "Listed $src_count src file(s)\n";
print "Listed $header_count header file(s)\n";
print "Listed $t55_count t55 file(s)\n";





#
# get list of header file names from config file
#




#
# process each file
#
print "Processing files\n";
#foreach my $filepath (@src_filelist)
#{
#    process_file($filepath);
#}

#print "Sorting records\n";
#@recordlist = sort(@recordlist);


#print "Searching for duplicates\n";

my $name_count = 0;

my $outfile_name = get_file_name($outfile);

#open (OUTFILE, ">$outfile_name") or die "Failed to open $outfile_name";

#my $array_size=@recordlist;
#for(my $i=1; $i<$array_size; $i++)
#{
#    if($recordlist[$i] eq $recordlist[$i-1])
#    {
#        # debug    
#        # print "Duplicate: $recordlist[$i]\n";
#        print OUTFILE "Duplicate: $recordlist[$i]\n";
#        $name_count++;
#    }
#}
#close OUTFILE;

#printf "Found %d file names, stored in $outfile_name\n", $name_count ; 

$end = (times)[0];
printf "Program ran in %d mins %d secs\n", ($end - $start)/60, ($end - $start)%60; 

print "End\n";




##############################################################################
#    SUBROUTINES
##############################################################################



##############################################################################
# step through each file listing each record
##############################################################################
sub process_file()
{
    my($path) = shift;
 
    open( T55_FILE, $path ) or die "Can't open $path\n";

    # step through each line of the t55 file

	# debug
    #print "Processing: $path";

    my @dataline      = ();

    while (<T55_FILE>)
    {
        next if /^(\s)*$/;                                # Skip blank lines using ';'.
        next if ( /^\#/ );                                # Skip # comments.
        next if ( /^\*/ );                                # Skip * comments.
        next if ( /^\FEATURE/ );                          # Skip FEATURE lines.
        next if ( /^\VERSION/ );                          # Skip VERSION lines.
        @dataline = split( ";", $_ );                     # split line using semicol;ons
        $dataline[0] =~ s/.*(\'.*\').*/$1/;               # strip any supplementary fields.
        $dataline[0] =~ s/\'//g;                          # strip surrounding inverted commas
        $dataline[0] =~ s/\;//g;                          # strip surrounding semi-colons
        $dataline[0] =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;   # strip all leading and trailing white space.
        push(@recordlist, $dataline[0]);                  # push the t55 name into the array
    }
    close T55_FILE;
}


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
