#!/usr/bin/perl
########################################################################
#                    Delphi Diesel Systems
#
#                    This document is the property of
#                    Delphi Diesel Systems
#                    It must not be copied (in whole or in part)
#                    or disclosed without prior written consent
#                    of the company. Any copies by any method
#                    must also include a copy of this legend.
#######################################################################
#
# Description: callable pop-up box using tk
#              John Oldman
#
########################################################################
use English;
require Tk;
use POSIX 'acos';
use Tk;
#use Tk::StayOnTop;


# Flush
$| = 1;

my $on_top = 0;


###############################################################################
# defaults
###############################################################################
my $Version="0.2";

###############################################################################
# tk gui
###############################################################################

# the main window
my $mw = MainWindow->new();
$mw->title("Delphi Deisel Systems");
$mw->minsize(qw(1100 150));
$mw->maxsize(qw(1100 150));
$mw->geometry('1100x1500+100+300');
$mw->fontCreate('big',-family=>'arial',-size=>int(-30*30/14)); 
#$mw->stayOnTop;
#$mw->attributes(-topmost=>1); 
my $banner = $ARGV[0];
my $note = $mw->Label(-font=>'big', -text=> $banner)->pack(); 

MainLoop; 
