#######################################################################
# ddsLogParser.pl
# A.R.Rees 14-Sep-2010
# 28-Oct-'10 Added detection of Control Frames
# 09-Jun='11 Improved CAN Ident selection in Process #1
#            Corrected tokens indices.
#            Added 'Sequence Number Error' detection.
#
#----------------------------------------------------------------------
$out1 = "c:\\temp\\temp.txt";   # temp o/p file
$first = 6;     # start position of CAN message

%udsHash =
(
	'10'    =>    'Session Control',
	'11'    =>    'Reset Command',
	'22'    =>    'Read Data by LID',
	'27'    =>    'Security Access',
	'2E'    =>    'Write Data by LID',
	'31'    =>    'Routine Control-',
	'FF00'  =>    'Erase',
	'0203'  =>    'Check Preconds',
	'0202'  =>    'check Memory',
	'FF01'  =>    'Check Dependancies',
	'34'    =>    'Request Download',
	'35'    =>    'Request Upload',
	'36'    =>    'Data Transfer',
	'37'    =>    'Transfer Exit',
	'3E'    =>    'Tester Present',
	'85'    =>    'DTC Control'
);

#--------------------------------------------------------------
# main
#--------------------------------------------------------------

if (2 != (scalar (@ARGV)))
{
    print "Two arguements are required:\n";
    print "Usage: ddsLogParser.pl inputFile.trc ouputFile.txt\n";
    die;
}

open IN, "$ARGV[0]" or die "Cannot open $ARGV[0] for read :$!";
open OUT1, ">$out1" or die "Cannot open $out1 for write :$!";

#--------------------------------------------------------------
# Process #1
# Only include lines containing 07E0, 07E8, 0700, 0703 or 07DF.
#--------------------------------------------------------------
# Read lines from IN, remove newline and assign to $line
while ($line = <IN>)
{
    if (($line =~ / 7E0 /) or ($line =~ / 7E8 /) or ($line =~/ 700 /) or ($line =~ / 703 /)) # or ($line =~ / 07DF /))
    {
        $line =~ s/^\s+//;    # Remove leading spaces
        print OUT1 $line;
    }
}
close IN;
close OUT1;
#die
#--------------------------------------------------------------
# Process#2
# Scan entries in temp.txt, append UDS commands and write
# to OUT2.
#--------------------------------------------------------------
open OUT1, "$out1" or die "Cannot open $out1 for read :$!";
open OUT2, ">$ARGV[1]" or die "Cannot open $ARGV[1] for write :$!";

$prev_byte_1 = 0x20;

while ($line = <OUT1>)
{
    chomp $line;
	@tokens = split /\s+/, $line;		# split $line into whitespace separated fields
    $byte_1 = $tokens[$first];
    $byte_2 = $tokens[$first+1];
    $byte_3 = $tokens[$first+2];

	if ($byte_1 =~ /0./)    # Single Frame (SF) received...
	{
	    if (exists $udsHash{$byte_2})   # ...so UDS Cmd is in byte_2
	    {
	        $udsCmd = $udsHash{$byte_2};
	    }
	    else {$udsCmd = " "};
	}
	elsif ($byte_1 =~ /1./)    # First Frame (FF) received...
	{
	    if (exists $udsHash{$byte_3})   # ...so UDS Cmd is in byte_3
	    {
	        $udsCmd = $udsHash{$byte_3};
	        $prev_byte_1 = 0x20;
	    }
	    else {$udsCmd = " "};
	}
	elsif ($byte_1 =~ /2./)     # Consecutive Frame (CF) received...
	{
	    if ((hex($byte_1) - $prev_byte_1) == 1)
	    {
	        $udsCmd = " ";
	    }
	    else
	    {
	        $udsCmd = "bad message sequence";
	    }
    	if ($byte_1 eq "2F")
        {
            $prev_byte_1 = 0x1F;
        }
        else
        {
            $prev_byte_1 = hex($byte_1);
        }
	}
	elsif ($byte_1 =~ /3./)     # Control Frame (FC) received...
	{
	    $udsCmd = "Control Frame";
	}
	else {$udsCmd = " "};
	
    print OUT2 "$line......$udsCmd\n";
}

close OUT1;
close OUT2;
#system ("del c:\\temp\\temp.txt");
print "\nAll done, press return to exit";
<STDIN>;
