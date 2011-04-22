#!/usr/bin/perl -w

use strict;

# debug lines 155 and 182
# debug tok and comma 
# use named backreferences
# turn short, char, long into int
# replace tok and comma with 0 and 1
# transform a function to return void
# inline a function call

# add methods for removing
#   labels
#   ?:
#   += -= *= /= ++ -- etc.
#   lonely variables and numbers
#   U and L from constants
#   array dimension
#   pointer level of indirection
#   argument from function, including all calls

# assumption: we're processing code that has been run through 'indent'
# which adds white space around operators and in other places

my $INIT = "1";

my %function_prefixes = ("lshift_s_s" => $INIT,
			 "lshift_s_u" => $INIT,
			 "lshift_u_s" => $INIT,
			 "lshift_u_u" => $INIT,
			 "rshift_s_s" => $INIT,
			 "rshift_s_u" => $INIT,
			 "rshift_u_s" => $INIT,
			 "rshift_u_u" => $INIT,
			 "mod_rhs" => $INIT,
			 "div_rhs" => $INIT,
			 "safe_" => $INIT,
			 "sizeof" => $INIT,
			 "func_" => $INIT,
			 "self_assign_" => "",
			 "or_" => "",
			 "and_" => "",
			 "loop_" => "",
			 "load_only_" => "",
			 "store_only_" => "",
			 "crcBytes" => "",
			 "for" => "",
			 "if" => "",
			 "return" => "",
			 );

my @delete_strs = (
    "else", 
    "char",
    "volatile", 
    "const", 
    "static", 
    "+",
    "-",
    "inline", 
    "signed", 
    "unsigned", 
    "short", 
    "long");

my $prog;

sub find_match ($$$) {
    (my $p2, my $s1, my $s2) = @_;
    my $count = 1;
    die if (!(defined($p2)&&defined($s1)&&defined($s2)));
    while ($count > 0) {
	return -1 if ($p2 >= (length ($prog)-1));
	my $s = substr($prog, $p2, 1);
	if (!defined($s)) {
	    my $l = length($prog);
	    print "$p2 $l\n";
	    die;
	}
	$count++ if ($s eq $s1);
	$count-- if ($s eq $s2);
	$p2++;
    }
    return $p2-1;
}

sub find_match_no_div ($) {
    (my $p2) = @_;
    my $count = 1;
    while ($count > 0) {
	my $c = substr ($prog, $p2, 1);
	return -1 if ($count == 1 &&
		      (($c eq "/") || ($c eq "%")));
	$count++ if ($c eq "(");
	$count-- if ($c eq ")");
	$p2++;
	return -1 if ($p2 >= length ($prog));
    }
    return $p2-1;
}

sub killit ($$) {
    (my $pos, my $pref) = @_;
    my $p2 = $pos;
    $p2++ while (
		 substr($prog, $p2, 1) ne "(" &&
		 $p2 <= (length($prog)-1)
		 );
    $p2 = find_match ($p2+1,"(",")");
    return -1 if ($p2 == -1);
    $p2++;
    my $xx = substr ($prog, $pos, $p2-$pos);
    my $yy = $function_prefixes{$pref};
    print "repl '$xx' with '$yy' ";
    substr ($prog, $pos, $p2-$pos) = $function_prefixes{$pref};
    return ($p2-$pos);
}

sub read_file ($)
{
    (my $cfile) = @_;
    open INF, "<$cfile" or die;
    $prog = "";
    while (<INF>) {
	$prog .= $_;
    }
    close INF;
}

sub write_file ($)
{
    (my $cfile) = @_;
    open OUTF, ">$cfile" or die;
    print OUTF $prog;
    close OUTF;
}

my $num = "\\-?[xX0-9a-fA-F]+[UL]*";
my $var = "\\**[lgpt]_[0-9]+(\\\[$num\\\])*";
my $arith = "\\+|\\-|\\%|\\/|\\*";
my $comp = "\\<\\=|\\>\\=|\\<|\\>|\\=\\=|\\!\\=|\\=";
my $logic = "\\&\\&|\\|\\|";
my $bit = "\\||\\&|\\^|\\<\\<|\\>\\>";
my $binop = "$arith|$comp|$logic|$bit";
my $varnum = "$var|$num";

sub match_binop ($$) {
    (my $prog, my $pos) = @_;
    my $s = substr ($prog, $pos, -1);
    if (
	$s =~ /^([\s\(])($varnum)(\s+)($binop)/
	) {
	$pos += length($1);
	my $s2 = $2.$3.$4;
	return (1, $pos, $pos+length($s2),"");
    }
    if (
	$s =~ /^($binop)(\s+)($varnum)[\s\)\;]/ 
	) {
	my $s2 = $1.$2.$3;
	return (1, $pos, $pos+length($s2));
    }
    return (0,0,0);
}

sub match_id ($$) {
    (my $prog, my $pos) = @_;
    my $s = substr ($prog, $pos, -1);
    if (
	$s =~ /^([\s\(])($varnum)[\s\)\;]/
	) {
	my $s = $1;
	my $v = $2;
	if (($v ne "1") && ($v ne "0")) {
	    return (1, $pos+1, $pos+length($s.$v));
	}
    }
    if (
	$s =~ /^([\s\(])($varnum)(\s+)($binop)(\s+)($varnum)[\s\)\;]/
	) {
	my $s2 = $1.$2.$3.$4.$5.$6;
	return (1, $pos+1, $pos+length ($s2));
    }
    if (
	$s =~ /^($varnum)(\s*\?\s*)($varnum)(\s*\:\s*)($varnum)/
	) {
	my $s2 = $1.$2.$3.$4.$5;
	return (1, $pos+1, $pos+length ($s2));
    }
    return (0,0,0);
}

# FIXME!
sub match_tok_and_comma ($$) {
    (my $prog, my $pos) = @_;
    my $s = substr ($prog, $pos, -1);
    if (
	$s =~ /^(\s$varnum\s*\,)/
	) {
	my $v = $1;
	return (1, $pos, 1+$pos+length($v));
    }
    return (0,0,0);
}

sub match_mod_div ($$) {
    (my $prog, my $pos) = @_;
    my $s = substr ($prog, $pos, -1);
    if ($s =~ /^(\%|\/)/) {
	return (1, $pos);
    }
    return (0,0,0);
}

sub try_delete_one ($$$$$) {
    (my $number_to_delete, my $method, my $good_cnt, my $bad_cnt, my $pass) = @_;

    my $n = 0;

    for (my $pos=0; $pos < length($prog); $pos++) {

	if ($method eq "binop") {
	    (my $success, my $start, my $end) = 
		match_binop ($prog, $pos);
	    if ($success) {
		if ($n == $number_to_delete) {
		    my $del = substr ($prog, $start, $end-$start);
		    substr ($prog, $start, $end-$start) = "";
		    ($del =~ s/\s/ /g);
		    print "[$pass binop s:$good_cnt f:$bad_cnt] ";
		    print "deleting '$del' at $start--$end : ";
		    return 1;
		} else {
		    $n++;
		}
	    }
	} elsif ($method eq "tok_and_comma") {
	    (my $success, my $start, my $end) = 
		match_tok_and_comma ($prog, $pos);
	    if ($success) {
		if ($n == $number_to_delete) {
		    my $del = substr ($prog, $start, $end-$start);
		    substr ($prog, $start, $end-$start) = "";
		    ($del =~ s/\s/ /g);
		    print "[$pass del_tok_and_comma s:$good_cnt f:$bad_cnt] ";
		    print "deleting '$del' at $start--$end : ";
		    return 1;
		} else {
		    $n++;
		}
	    }	    
	} elsif ($method eq "repl_with_1") {
	    (my $success, my $start, my $end) = 
		match_id ($prog, $pos);
	    if ($success) {
		if ($n == $number_to_delete) {
		    my $del = substr ($prog, $start, $end-$start);
		    substr ($prog, $start, $end-$start) = "1";
		    ($del =~ s/\s/ /g);
		    print "[$pass repl_with_1 s:$good_cnt f:$bad_cnt] ";
		    print "replacing '$del' at $start--$end : ";
		    return 1;
		} else {
		    $n++;
		}
	    }	    
	} elsif ($method eq "repl_with_0") {
	    (my $success, my $start, my $end) = 
		match_id ($prog, $pos);
	    if ($success) {
		if ($n == $number_to_delete) {
		    my $del = substr ($prog, $start, $end-$start);
		    substr ($prog, $start, $end-$start) = "0";
		    ($del =~ s/\s/ /g);
		    print "[$pass repl_with_0 s:$good_cnt f:$bad_cnt] ";
		    print "replacing '$del' at $start--$end : ";
		    return 1;
		} else {
		    $n++;
		}
	    }	    
	} elsif ($method eq "repl_with_-1") {
	    (my $success, my $start, my $end) = 
		match_id ($prog, $pos);
	    if ($success) {
		if ($n == $number_to_delete) {
		    my $del = substr ($prog, $start, $end-$start);
		    substr ($prog, $start, $end-$start) = "-1";
		    ($del =~ s/\s/ /g);
		    print "[$pass repl_with_-1 s:$good_cnt f:$bad_cnt] ";
		    print "replacing '$del' at $start--$end : ";
		    return 1;
		} else {
		    $n++;
		}
	    }	    
	} elsif ($method eq "elim_mod_div") {
	    (my $success, my $start) = 
		match_mod_div ($prog, $pos);
	    if ($success) {
		if ($n == $number_to_delete) {
		    my $del = substr ($prog, $start, 1);
		    substr ($prog, $start, 1) = "+";
		    print "[$pass repl_mod_div s:$good_cnt f:$bad_cnt] ";
		    print "replacing '$del' at $pos : ";
		    return 1;
		} else {
		    $n++;
		}
	    }	    
	} elsif ($method eq "parens_inclusive") {
	    if (substr($prog, $pos, 1) eq "(") {
		if ($n == $number_to_delete) {
		    my $p2 = find_match_no_div ($pos+1);
		    if ($p2 != -1) {
			die if (substr($prog, $pos, 1) ne "(");
			die if (substr($prog, $p2, 1) ne ")");
			substr ($prog, $pos, $p2-$pos+1) = "";
			print "[$pass parens_inclusive s:$good_cnt f:$bad_cnt] ";
			print "deleting at $pos--$p2 : ";
			return 1;
		    }
		} else {
		    $n++;
		}
	    }
	} elsif ($method eq "parens_exclusive") {
	    if (substr($prog, $pos, 1) eq "(") {
		if ($n == $number_to_delete) {
		    my $p2 = find_match_no_div ($pos+1);
		    if ($p2 != -1) {
			die if (substr($prog, $pos, 1) ne "(");
			die if (substr($prog, $p2, 1) ne ")");
			substr ($prog, $p2, 1) = "";
			substr ($prog, $pos, 1) = "";
			print "[$pass parens_exclusive s:$good_cnt f:$bad_cnt] ";
			print "deleting at $pos--$p2 : ";
			return 1;
		    }
		} else {
		    $n++;
		}
	    }
	} elsif ($method eq "brackets_inclusive") {
	    if (substr($prog, $pos, 1) eq "{") {
		if ($n == $number_to_delete) {
		    my $p2 = find_match ($pos+1,"{","}");
		    if ($p2 != -1) {
			die if (substr($prog, $pos, 1) ne "{");
			die if (substr($prog, $p2, 1) ne "}");
			substr ($prog, $pos, $p2-$pos+1) = "";
			print "[$pass brackets_inclusive s:$good_cnt f:$bad_cnt] ";
			print "deleting at $pos--$p2 : ";
			return 1;
		    }
		} else {
		    $n++;
		}
	    }	    
	} elsif ($method eq "brackets_exclusive") {
	    if (substr($prog, $pos, 1) eq "{") {
		if ($n == $number_to_delete) {
		    my $p2 = find_match ($pos+1,"{","}");
		    if ($p2 != -1) {
			die if (substr($prog, $pos, 1) ne "{");
			die if (substr($prog, $p2, 1) ne "}");
			substr ($prog, $p2, 1) = "";
			substr ($prog, $pos, 1) = "";
			print "[$pass brackets_exclusive s:$good_cnt f:$bad_cnt] ";
			print "deleting at $pos--$p2 : ";
			return 1;
		    }
		} else {
		    $n++;
		}
	    }
	} elsif ($method eq "calls_wargs") {
	    foreach my $pref (keys %function_prefixes) {
		my $s = substr ($prog, $pos, length($pref));
		if ($s eq $pref) {
		    if ($n == $number_to_delete) {
			my $c = killit ($pos, $pref);
			if ($c != -1) {
			    print "[$pass call w/args s:$good_cnt f:$bad_cnt] ";
			    print " : ";
			    return 1;
			}
		    }
		    $n++;
		}
	    }
	} elsif ($method eq "calls_woargs") {
	    foreach my $pref (keys %function_prefixes) {
		my $s = substr ($prog, $pos, length($pref));
		if ($s eq $pref) {
		    if ($n == $number_to_delete) {
			my $p2 = $pos;
			while ($p2 <= length ($prog)) {
			    if (substr ($prog, $p2, 1) eq "(") {
				print "[$pass call w/o args s:$good_cnt f:$bad_cnt] ";
				my $c = $p2-$pos-1;
				my $deleted = substr ($prog, $pos, $c);
				substr ($prog, $pos, $c) = "";
				print "deleting '$deleted' : ";
				return 1;
			    }
			    $p2++;
			}
		    }
		    $n++;
		}
	    }
	} elsif ($method eq "useless_parens") {
	    if (substr($prog, $pos, 1) eq "(") {
		if ($n == $number_to_delete) {
		    my $p2 = find_match_no_div ($pos+1);
		    if ($p2 != -1) {
			die if (substr($prog, $pos, 1) ne "(");
			die if (substr($prog, $p2, 1) ne ")");
			my $middle = substr ($prog, $pos+1, $p2-$pos-1);
			#print "<$middle>\n";
			if (
			    $middle =~ /^\s*\((.*)\)\s*$/ ||
			    $middle =~ /^\s*($var)\s*$/ ||
			    $middle =~ /^\s*($num)\s*$/
			    ) {
			    print "[$pass useless_parens s:$good_cnt f:$bad_cnt] ";
			    print "deleting at $pos--$p2 : ";
			    substr($prog, $p2, 1) = "";
			    substr($prog, $pos, 1) = "";
			    return 1;
			}
		    }
		} else {
		    $n++;
		}
	    }
	} elsif ($method eq "delete_str") {
	    foreach my $str (@delete_strs) {
		if (substr($prog, $pos, length($str)) eq $str) {
		    if ($n == $number_to_delete) {
			print "[$pass delete_str s:$good_cnt f:$bad_cnt] ";
			print "deleting $str at $pos : ";
			substr($prog, $pos, length($str)) = "";
			return 1;
		    } else {
			$n++;
		    }
		}
	    }
	} elsif ($method eq "double_semic") {
	    my $rest = substr($prog, $pos, -1);
	    if ($rest =~ /^\;\s*;/) {
		if ($n == $number_to_delete) {
		    print "[$pass double_semic s:$good_cnt f:$bad_cnt] ";
		    print "deleting at $pos : ";
		    substr($prog, $pos, 1) = "";
		    return 1;
		} else {
		    $n++;
		}
	    }
	} elsif ($method =~ /^normalize_types_([0-9]+)$/) {
	    my $which = $1;
	    my $orig;
	    my $new;
	    
	    # FIXME-- int64_t probably matches uint64_t

	    if (1) {
		if ($which == 1) {
		    $orig = "uint64_t";
		    $new  = "uint32_t";
		} elsif ($which == 2) {
		    $orig = "int64_t";
		    $new  = "int32_t";
		} elsif ($which == 3) {
		    $orig = "uint32_t";
		    $new  = "uint16_t";
		} elsif ($which == 4) {
		    $orig = "int32_t";
		    $new  = "int16_t";
		} elsif ($which == 5) {
		    $orig = "uint16_t";
		    $new  = "uint8_t";
		} elsif ($which == 6) {
		    $orig = "int16_t";
		    $new  = "int8_t";
		} elsif ($which == 7) {
		    $orig = "int8_t";
		    $new  = "uint8_t";
		} else {
		    die;
		}
	    } else {
		if ($which == 1) {
		    $orig = "uint64_t";
		$new = "uint32_t";
		} elsif ($which == 2) {
		    $orig = "int64_t";
		    $new = "int32_t";
		} elsif ($which == 3) {
		    $orig = "int32_t";
		    $new = "uint32_t";
		} elsif ($which == 4) {
		    $orig = "uint16_t";
		    $new = "uint32_t";
		} elsif ($which == 5) {
		    $orig = "int16_t";
		    $new = "int32_t";
		} elsif ($which == 6) {
		    $orig = "uint8_t";
		    $new = "uint16_t";
		} elsif ($which == 7) {
		    $orig = "int8_t";
		    $new = "int16_t";
		} else {
		    die;
		}
	    }
	    my $rest = substr($prog, $pos, -1);
	    if ($rest =~ /^\s$orig/) {
		if ($n == $number_to_delete) {
		    print "[$pass normalize_types s:$good_cnt f:$bad_cnt] ";
		    print "replacing $orig with $new at $pos : ";
		    substr($prog, $pos, length($orig)+1) = " $new";
		    return 1;
		} else {
		    $n++;
		}
	    }
	} else {
	    die "unknown reduction method";
	}
    }
    return 0;
}

sub runit ($) {
    (my $cmd) = @_;
    if ((system "$cmd") != 0) {
	return -1;
    }   
    return ($? >> 8);
}

sub run_test ($) {
    (my $test) = @_;
    my $res = runit "./$test";
    return ($res == 0);
}

# invariant: test always succeeds for $cfile.bak

sub delete_loop ($$$$) {
    (my $cfile, my $test, my $method, my $pass) = @_;
    
    my $worked = 0;
    my $n=0;
    my $good_cnt = 0;
    my $bad_cnt = 0;
    
    while (1) {
	read_file ($cfile);    
	my $delete_res = try_delete_one ($n, $method, $good_cnt, $bad_cnt, $pass);
	if (!$delete_res) {
	    print "no more to delete.\n";
	    return $worked;
	}
	write_file ($cfile);
	if (run_test ($test)) {
	    print "success\n";
	    system "cp $cfile $cfile.bak";
	    $good_cnt++;
	    $worked = 1;
	} else {
	    print "failure\n";
	    system "cp $cfile.bak $cfile";
	    $n++;
	    $bad_cnt++;
	}
    } 
}

my @all_methods = (
    "brackets_inclusive",
    "calls_wargs",
    "calls_woargs",
    "binop",
    "brackets_exclusive",
    "useless_parens",
    "repl_with_0",
    "elim_mod_div",
    "double_semic",
    "delete_str",
    "repl_with_1",
    "parens_inclusive",
    "parens_exclusive",
    # "tok_and_comma",
    "normalize_types_1",
    "normalize_types_2",
    "normalize_types_3",
    "normalize_types_4",
    "normalize_types_5",
    "normalize_types_6",
    "normalize_types_7",
    );
 
#################### main #####################

sub usage() {
    print "usage: custom_delta.pl test_script.sh file.c [method [method ...]]\n";
    print "available methods are --all or:\n";
    foreach my $method (@all_methods) {
	print "  --$method\n";
    }
    die;
}

my $test = shift @ARGV;
if (!(-x $test)) {
    print "'$test' not found, or not executable\n";
    usage();
}

my $cfile = shift @ARGV;
if (!(-e $cfile)) {
    print "'$cfile' not found\n";
    usage();
}

my %methods = ();
foreach my $arg (@ARGV) {
    if ($arg eq "--all") {
	foreach my $method (@all_methods) {
	    $methods{$method} = 1;
	}
    } else {
	my $found = 0;
	foreach my $method (@all_methods) {
	    if ($arg eq "--$method") {
		$methods{$method} = 1;
		$found = 1;
		last;
	    }
	}
	if (!$found) {
	    print "unknown method '$arg'\n";
	    usage();
	}
    }
}

print "making sure test succeeds on initial input...\n";
my $res = run_test ($test);
if (!$res) {
    die "test fails!";
}

system "cp $cfile $cfile.orig";
system "cp $cfile $cfile.bak";

# iterate to global fixpoint

my $pass = 0;
while (1) {
    my $success = 0;
    foreach my $method (keys %methods) {
	$success |= delete_loop ($cfile, $test, $method, $pass);
    }
    last if (!$success);
    $pass++;
}