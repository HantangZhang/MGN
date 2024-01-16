#!/usr/bin/perl -w
use strict;
no warnings 'experimental::smartmatch';

my $ARGC = scalar @ARGV;
if ($ARGC < 1) {
	print "\nusage: perl contech_weighted.pl <a file you want to instrument> <arguments required by the file>\n\n";
	exit 1;
}

my $file = $ARGV[0];
my @arguments = @ARGV[1..$ARGC - 1];
#print "arguments: @arguments\n";
my %BBs;
my $index = -1;
my $BB = 0;
my @global;
my @str;
###################Instrument the file##############################
my $numOfStr = 0;
my $isStr = 0;
my $isPrinted = 0;
my $doNotPrint = 0;
my $numOfSL = 0;
my $main = 0;
my $hasPrint = 0;
my %func;
my %callFunc;

system("clang -emit-llvm -S -c $file -o llvm.ll");

open(IN, "llvm.ll");
open(OUT, ">llvm_instrumented.ll");

while (<IN>) {
	chomp;
	if (/define \w+ \@(.*)\((.*)\)/) {
		#print "$2\n";
		my $fncName = $1;
		#print "qwert\t$1\n";
		my @args = split /,/, $2;
		#print "args: $#args\n";
		#print "@args\n";
		#push @{$func{$1}}, ($#args + 1);
		push @{$func{$fncName}}, @args;
		#foreach my $pair (@args) {
		#	my @temp = split/ /, $pair;
		#	foreach my $item (@temp) {
		#		#print "temp: $item\n";
		#		if ($item =~ /^%/) {
		#			#print "$item\n";
		#			push @{$func{$fncName}}, $item;
		#		}
		#	}
		#}
	}
	if (/call .* \@(.*)\((.*)\)/) {
		#print "$2\n";
		my $fncName = $1;
		my @args = split /,/, $2;
		#print "args: $#args\n";
		#print "@args\n";
		#push @{$func{$1}}, ($#args + 1);
		push @{$callFunc{$fncName}}, @args;
		#foreach my $pair (@args) {
		#	my @temp = split/ /, $pair;
		#	foreach my $item (@temp) {
		#		#print "temp: $item\n";
		#		if ($item =~ /^%/) {
		#			#print "$item\n";
		#			push @{$callFunc{$fncName}}, $item;
		#		}
		#	}
		#}
	}
	if (/global/) {
		push @global, $_;
		#print;
		#next;
	}
	if (/private unnamed_addr/) {
		push @str, $_;
	}
	if (/^@.str/) {
		$numOfStr++;
		$isStr = 1;
	}
	$hasPrint = 1 if (/printf/);
	if (/^(?!@)/gm && $isStr) {
		$isStr = 0;
		print OUT "\@.str." . "$numOfStr" ." = private unnamed_addr constant [17 x i8] c\"counter is %lli\\0A\\00\", align 1\n";
		$isPrinted = 1;
	}
	if (/; Function Attrs:/ && !$isPrinted && !$doNotPrint) {
		print OUT "\@.str.$numOfStr = private unnamed_addr constant [17 x i8] c\"counter is %lli\\0A\\00\", align 1\n\n";
		$doNotPrint = 1;
	}
	if (/store|load/) { #before load/store instr, instrument rdsc()
		$numOfSL++;
		#print OUT "  %SL" . "$numOfSL" . " = call i64 \@rdtsc()\n";
	}
	print OUT;
	print OUT "\n";

	if (/store|load/) {
		$numOfSL++;
		#print OUT "  %SL" . "$numOfSL" . " = call i64 \@rdtsc()\n";
		$numOfSL++;
		my $temp1 = $numOfSL - 1;
		my $temp2 = $numOfSL - 2;
		#print OUT "  %SL" . "$numOfSL" . " = sub i64 %SL$temp1, %SL$temp2\n";
		$numOfSL++;
		$temp1 = $numOfSL - 1;
		#print OUT "  %SL$numOfSL = call i32 (i8*, ...) \@printf(i8* getelementptr inbounds ([17 x i8], [17 x i8]* \@.str.$numOfStr, i32 0, i32 0), i64 %SL$temp1)\n";	
	}

	if (/define (.*) \@main\(.*\) \#\d+/) {
		$main = 1;
	}
	if (/^}/ && $main) {
		$main = 0;
		print OUT "\n\n; Function Attrs: nounwind uwtable\n";
		print OUT "define i64 \@rdtsc() #0 {\n";
		print OUT "  %lo = alloca i32, align 4\n";
		print OUT "  %hi = alloca i32, align 4\n";
		print OUT "  %1 = call { i32, i32 } asm sideeffect \"rdtsc\", \"={ax},={dx},~{dirflag},~{fpsr},~{flags}\"() #2, !srcloc !1\n";
		print OUT "  %2 = extractvalue { i32, i32 } %1, 0\n";
		print OUT "  %3 = extractvalue { i32, i32 } %1, 1\n";
		print OUT "  store i32 %2, i32* %lo, align 4\n";
		print OUT "  store i32 %3, i32* %hi, align 4\n";
		print OUT "  %4 = load i32, i32* %hi, align 4\n";
		print OUT "  %5 = zext i32 %4 to i64\n";
		print OUT "  %6 = shl i64 %5, 32\n";
		print OUT "  %7 = load i32, i32* %lo, align 4\n";
		print OUT "  %8 = zext i32 %7 to i64\n";
		print OUT "  %9 = or i64 %6, %8\n";
		print OUT "  ret i64 %9\n";
		print OUT "}\n";
		print OUT "\n!1 = !{i32 330}\n";
		print OUT "\ndeclare i32 \@printf(i8*, ...) #0\n\n" if !$hasPrint;
	}

}

close(IN);
close(OUT);

########################END#########################################
#print "str = @str\n";

my @timing;
my @printf;
#system("lli llvm_instrumented.ll @arguments > timing");
#if (defined $ARGV[1]) {
#	system("lli llvm_instrumented.ll $ARGV[1] > timing");
# else {
#	system("lli llvm_instrumented.ll > timing");
#}
open(IN, "timing");
while(<IN>) {
	chomp;
	if (/counter is (\d+)/) {
		unshift @timing, $1;
	} else {
		unshift @printf, $_;
	}
}


close(IN);

system("rm -f output/*");
system("nice -n -19 ./contech_wrapper_par.py $file -lm > log");
my $currentFunctionName;
my @skipStore;

open(IN, "log");
while (<IN>) {
	chomp;
	if (/current function name: (\w+)/) {
		$currentFunctionName = $1;
		next if ($currentFunctionName eq "main");
		my $bbAhead = $index + 1;
		foreach my $i (0..$#{$func{$currentFunctionName}}) {
			#print "i = $i\n";
			#print "$currentFunctionName: \n";
			#print "${$func{$currentFunctionName}}[$i] - ${$callFunc{$currentFunctionName}}[$i]\n";
			my @temp1;
			${$func{$currentFunctionName}}[$i] =~ s/^\s*//;
			my $flag1 = 0;
			my $flag2 = 0;
			if (${$func{$currentFunctionName}}[$i] =~ /^%/) {
				@temp1 = split / +/, ${$func{$currentFunctionName}}[$i];
				$flag1 = 1;
			} else {
				@temp1 = split /%/, ${$func{$currentFunctionName}}[$i];
				$flag2 = 1;
			}
			$temp1[0] =~ s/\s+$//;
			my @temp2 = ${$callFunc{$currentFunctionName}}[$i];
			#print "func name : $currentFunctionName\t@temp2\n";
			if (defined $temp2[0]) {
				if ($flag2) {
					push @skipStore, "store @temp2, $temp1[0]* \%$temp1[1], align 8";
					push @{$BBs{$bbAhead}}, "store @temp2, $temp1[0]* \%$temp1[1], align 8";
				} elsif ($flag1) {
					push @skipStore, "store @temp2, $temp1[0]* $temp1[1], align 8";
					push @{$BBs{$bbAhead}}, "store @temp2, $temp1[0]* $temp1[1], align 8";			
				}
			}
		}
	}
	if ($BB) {
		#if ($currentFunctionName ~~ keys %func)
		#push @{$BBs{$index}}, $_ unless (/br|#BasicBlock|END|ret|current|SKIP/);
		push @{$BBs{$index}}, $_ unless (/#BasicBlock|END|current|SKIP|is struct|ret|br/);
		#print "$_\n" if (/br/);
		#print;
		#print "\n";
	}
	if (/#BasicBlock/) {
		$index++;
		$BB = 1;
		#print "--------------BB: $index---------------\n";
	}
	if (/END/) {
		$BB = 0;
	}
}	
close(IN);
#print "#BB : $index\n";

=comment
#print "global: @global\n";
#@printf;
open(OUT, ">temp.ll");

foreach my $instruction (@str) {
	#print "$instruction\n";
	if ($instruction =~ /c\"(.*)\"/) {
		my $match = $1;
		$match =~ s/\\0A|\\00|\\09|\\\d\w|\\\w\d|\\\d\d/ /gi;
		$match =~ s/^\s+|\s+$//g;
		$match =~ s/\.$//g;
		#print "match = $match\n";
		my @str1 = split / +/, $match;
		#print "str1 = @str1\n";
		foreach my $ins (@printf) {
			my $counter1 = 0;
			my $counter2 = 0;
			$ins =~ s/^\s+|\s+$//g;
			my @str2 = split / +/, $ins;
			#print "str2 = @str2\n";
			foreach my $i (0..$#str2) {
				$counter1++;
				if (defined $str1[$i] && defined $str2[$i] && $str1[$i] =~ /%d/ && $str2[$i] =~ /\d+/) {
					$counter2++;
				} elsif (defined $str1[$i] && defined $str2[$i] && $str1[$i] =~ /%f/ && $str2[$i] =~ /\d*\.\d*/) {
					$counter2++;
				} elsif (defined $str1[$i] && defined $str2[$i] && $str1[$i] =~ /%c/ && $str2[$i] =~ /\w/) {
					$counter2++;
				} elsif (defined $str1[$i] && defined $str2[$i] && $str1[$i] =~ /%s/ && $str2[$i] =~ /\w+/) {
					$counter2++;
				} elsif (defined $str1[$i] && defined $str2[$i] && $str1[$i] eq $str2[$i]) {
					$counter2++;
				}
			}
			#print OUT "$instruction\n";
			print OUT "$instruction\n" if ($counter1 == $counter2);
		}

	}
	
}

foreach my $string (@global) {
	print OUT "$string\n";
}

foreach my $i (0..($index)) {
	foreach my $bb (@{$BBs{$i}}) {
		print OUT "$bb\n";
	}
}

close(OUT);
=cut
#=cut
my @space;
system("./a.out @arguments");
#if (defined $ARGV[1]) {
#	system("./a.out $ARGV[1]");
# else {
#	system("./a.out");
#}
system("nice -n -19 ../middle/middle /tmp/contech_fe Sta > temp");
open(IN, "temp");

open(OUT, ">$file.ll");

#print "global: @global\n";
foreach my $instruction (@global) {
	print OUT "$instruction\n";
}
foreach my $instruction (@str) {
	#print "$instruction\n";
	if ($instruction =~ /c\"(.*)\"/) {
		my $match = $1;
		$match =~ s/\\0A|\\00|\\09|\\\d\w|\\\w\d|\\\d\d/ /gi;
		$match =~ s/^\s+|\s+$//g;
		$match =~ s/\.$//g;
		#print "match = $match\n";
		my @str1 = split / +/, $match;
		#print "str1 = @str1\n";
		foreach my $ins (@printf) {
			my $counter1 = 0;
			my $counter2 = 0;
			$ins =~ s/^\s+|\s+$//g;
			my @str2 = split / +/, $ins;
			#print "str2 = @str2\n";
			foreach my $i (0..$#str2) {
				$counter1++;
				if (defined $str1[$i] && defined $str2[$i] && $str1[$i] =~ /%d/ && $str2[$i] =~ /\d+/) {
					$counter2++;
				} elsif (defined $str1[$i] && defined $str2[$i] && $str1[$i] =~ /%f/ && $str2[$i] =~ /\d*\.\d*/) {
					$counter2++;
				} elsif (defined $str1[$i] && defined $str2[$i] && $str1[$i] =~ /%c/ && $str2[$i] =~ /\w/) {
					$counter2++;
				} elsif (defined $str1[$i] && defined $str2[$i] && $str1[$i] =~ /%s/ && $str2[$i] =~ /\w+/) {
					$counter2++;
				} elsif (defined $str1[$i] && defined $str2[$i] && $str1[$i] eq $str2[$i]) {
					$counter2++;
				}
			}
			#print "$instruction\n";
			if ($counter1 == $counter2) {
				print OUT "$instruction\n";
				last;
			}
		}

	}
	
}

while(<IN>) {
	chomp;
	if (/BasicBlock# = (\d+)/) {
		#my $bb = $1;
		if (defined $BBs{$1}) {
			for my $instr (@{$BBs{$1}}) {
				print OUT "$instr\n";
			}
		}
	}
	unshift @space, $1 if (/size is (\d+)/);
}
close(OUT);

close(IN);
#=comment

##################################
# Free some memories
##################################
undef %func;
undef %callFunc;
undef %BBs;
undef @global;
undef @str;
undef @printf;
##################################

my %des;
my %src;

open(IN, "$file.ll");
#open(IN, "test.ll");
#open(IN, "temp.ll");
print "Starting...\n";
my $node = 0;
my $edge = 0;
my %dep1;
#print "skipStore: @skipStore\n";
while(<IN>) {
	chomp;
	if (/\s*br (\w+|\w+\d+) (\%(\d+|\w+\d+))/) {
#		print "$2\n";
		my $source = $2;
		$dep1{$node}[0] = $node - 1;
		$dep1{$node}[1] = $node + 1;
		$edge += 2;
	} elsif (/\s*(.*) = call (.*) \@printf\((.*) \w+ \w+ (.*)\* (.*), i\d+ \d+, i\d+/) {
#		print;
#		print "16\n$1\t$5\n";
		my $dest = $1;
		my $source = $5;
		$dep1{$node}[0] = $node - 1;
		foreach my $i (keys %des) {
			if ($source eq $i) {
				$dep1{$node}[1] = $des{$source};
				last;
			}
		}
		$src{$source} = $node;
		$des{$dest} = $node;
		$edge += 2;
	} elsif (/\s*(.*) = \w+ i\d+ \@\w+\(i\d+(\*)? (.*), i\d+(\*)? (.*)\)/) {
#		print;
#		print "10\n";
		my $dest = $1;
		my $source = $3;
		my $source2 = $5;
		$dep1{$node}[0] = $node - 1;
		foreach my $i (keys %des) {
			if ($source eq $i) {
				if (!defined ${$dep1{$node}}[1]) {
					${$dep1{$node}}[1] = $des{$source};
				} else {
					${$dep1{$node}}[2] = $des{$source};
				}
				$src{$source} = $node;
				$source = "XXXX";
			} 
			if ($source2 eq $i) {
				if (!defined ${$dep1{$node}}[1]) {
					${$dep1{$node}}[1] = $des{$source2};
				} else {
					${$dep1{$node}}[2] = $des{$source2}; 
				}
				$src{$source2} = $node;
				$source2 = "XXXX";
			}
			last if ($source eq "XXXX" && $source2 eq "XXXX");
		}
		$des{$dest} = $node;
		$edge += 3;
	} elsif (/\s*(.*) = call.*\@(fopen|.*fscanf|.*alloc)\(.*\* (.*), i\d+\* \w+?/) {
#		print;
#		print "13\n";
		my $dest = $1;
		my $source = $3;
#		print "dest: $1\tsrc: $3\n";
		$dep1{$node}[0] = $node - 1;
		foreach my $i (keys %des) {
			if ($source eq $i) {
				$dep1{$node}[1] = $des{$source};
				last;
			}
		}
		$src{$source} = $node;
		$des{$dest} = $node;
		$edge += 2;
	} elsif (/\s*(.*) = call .*\@.*\(\w+ (.*), \w+ (.*), \w+ .*, \w+ .*, \w+ .*, i\d+ .*,.*/) {
#		print;
#		print "17\n";
#		print "src: $2\t$3\n";
		my $dest = $1;
		my $source = $2;
		my $source2 = $3;
		$dep1{$node}[0] = $node - 1;
		foreach my $i (keys %des) {
			if ($source eq $i) {
				if (!defined ${$dep1{$node}}[1]) {
					${$dep1{$node}}[1] = $des{$source};
				} else {
					${$dep1{$node}}[2] = $des{$source};
				}
				$src{$source} = $node;
				$source = "XXXX";
			} 
			if ($source2 eq $i) {
				if (!defined ${$dep1{$node}}[1]) {
					${$dep1{$node}}[1] = $des{$source2};
				} else {
					${$dep1{$node}}[2] = $des{$source2}; 
				}
				$src{$source2} = $node;
				$source2 = "XXXX";
			}
			last if ($source eq "XXXX" && $source2 eq "XXXX");
		}
		$des{$dest} = $node;
		$edge += 3;
	} elsif (/\s+(.*) = call \w+ i\d+\*? \@.*\(i\d+ (.*), i\d+ (.*)\)/) {
#		print;
#		print "17\n";
#		print "$2\t$3\n";
		my $dest = $1;
		my $source = $2;
		my $source2 = $3;
		$dep1{$node}[0] = $node - 1;
		foreach my $i (keys %des) {
			if ($source eq $i) {
				if (!defined ${$dep1{$node}}[1]) {
					${$dep1{$node}}[1] = $des{$source};
				} else {
					${$dep1{$node}}[2] = $des{$source};
				}
				$src{$source} = $node;
				$source = "XXXX";
			} 
			if ($source2 eq $i) {
				if (!defined ${$dep1{$node}}[1]) {
					${$dep1{$node}}[1] = $des{$source2};
				} else {
					${$dep1{$node}}[2] = $des{$source2}; 
				}
				$src{$source2} = $node;
				$source2 = "XXXX";
			}
			last if ($source eq "XXXX" && $source2 eq "XXXX");
		}
		$des{$dest} = $node;
		$edge += 3;
	} elsif (/\s*(.*) = call [\s\S]*\@\w+\((.*,)?\s*.*\*? (.*)\)/) {
#		print;
#		print "8\n";
		my $dest = $1;
		my $source = $3;
		$dep1{$node}[0] = $node - 1;
#		print "dest: $1\tsrc: $3\n";
		foreach my $i (keys %des) {
			if ($source eq $i) {
				$dep1{$node}[1] = $des{$source};
				last;
			}
		}
		$src{$source} = $node;
		$des{$dest} = $node;
		$edge += 2;
	} elsif (/\s*(.*) = alloca/) {
		$des{$1} = $node;
	} elsif (/\s*(.*) = private unnamed_addr/) {
		$des{$1} = $node;
	} elsif (/store\s+(.*)\s+(.*),\s+(.*)\s+(.*), align/) {
#		print;
		#print "\n";
#		print "1\n";
#		print "source: $2; des: $4\n";
		my $dest = $4;
		my $size; my $time; my $latency;
		#print "dest node : $dest\n";
		my $source = $2;
		my $sourceM = $2; my $destM = $4;
		my $inst = $_;
		my $firstWord = 0;
		if ($inst ~~ @skipStore) {
			$latency = 1;
		} else {
			$size = 8;#shift @space;
			$time = 1;#shift @timing;
			$latency = $time * (2 ** $size);
		}
		if ($source =~ /\%argc/) {
			#print "$latency\n";
			$firstWord = 1;
			${$dep1{$node}}[0] = "store";
			${$dep1{$node}}[1] = $node + 1;
			#print "$node \t ${$dep1{$node}}[1]\n";
			#print "$des{$dest}\n";
			${$dep1{$node}}[2] = $latency;
			$edge += 1;
			$node += 1;
			next;
		}
		if ($source =~ /^\d+$/) {
			foreach my $i (keys %des) {
				#print "loop: $i\n";
				if ($dest eq $i) {
					${$dep1{$node}}[0] = "store";
					${$dep1{$node}}[1] = $des{$dest};
					#print "$des{$dest}\n";
					${$dep1{$node}}[2] = $latency;
					$edge += 1;
					last;
				}
			}
		} else {
			
			foreach my $i (keys %des) {
				if ($source eq $i) {
					if (!$firstWord) {
						push @{$dep1{$node}}, "store";
						$firstWord = 1;
					}
					push @{$dep1{$node}}, $des{$source};
					push @{$dep1{$node}}, $latency;
					#${$dep1{$node}}[0] = "store";
					#${$dep1{$node}}[1] = $des{$source};
					#print "$des{$dest}\n";
					#${$dep1{$node}}[2] = $latency;
					$source = "XXXX";
				}
				if ($dest eq $i) {
					if (!$firstWord) {
						push @{$dep1{$node}}, "store";
						$firstWord = 1;
					}
					push @{$dep1{$node}}, $des{$dest};
					push @{$dep1{$node}}, $latency;
					#${$dep1{$node}}[3] = $des{$dest};
					#print "$des{$dest}\n";
					#${$dep1{$node}}[4] = $latency;
					$dest = "XXXX";
				}
				last if ($source eq "XXXX" && $dest eq "XXXX");

			}
			$edge += 2;
			$src{$sourceM} = $node;
		}
		#print "store latency = $latency\n";
		#print "dep = $des{$dest}\n";
		$des{$destM} = $node;
		#print "$dest = $node\n";
	} elsif (/\s*(.*) = (load) (.*), (.*) (.*), align/) { # load
#		print;
#		print "\n";
#		print "2\n";
		#print "$1\t$5\n";
		my $dest = $1;
		my $source = $5;
		#print "src : $5\n";
		my $size = 8;#shift @space;
		my $time = 1;#shift @timing;
		my $latency = $time * (2 ** $size);
		foreach my $i (keys %des) {
			#print "$i\n";
			if ($source eq $i) {
				${$dep1{$node}}[0] = "latency";
				${$dep1{$node}}[1] = $des{$source};
				#print "$des{$source}\n";
				${$dep1{$node}}[2] = $latency;
				#print "load latency = $latency\n";
				last;
			}
		}
		$src{$source} = $node;
		$des{$dest} = $node;
		$edge += 1;
	} elsif (/\s*(.*) = (\w+) (\w+) i(\d+) (.*), (.*)\s*/) { # add
#		print;
#		print "3\n";
		my $dest = $1;
		my $source = $5;
		my $source2 = $6;
		foreach my $i (keys %des) {
			if ($source eq $i) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source};
				} else {
					${$dep1{$node}}[1] = $des{$source};
				}
				$src{$source} = $node;
				$source = "XXXX";
				#last;
			} 
			if ($source2 eq $i) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source2};
				} else {
					${$dep1{$node}}[1] = $des{$source2}; 
				}
				$src{$source2} = $node;
				$source2 = "XXXX";
				#last;;
			}
			last if ($source eq "XXXX" && $source2 eq "XXXX");
		}
		#$src{$source} = $node;
		#$src{$source2} = $node;
		$des{$dest} = $node;
		$edge += 2;
	} elsif (/\s*(.*) = \w+ (.*) (.*) to (.*)/) { # sext
#		print;
#		print "4\n";
		my $dest = $1;
		my $source = $3;
		#print $5;
		foreach my $i (keys %des) {
			if ($source eq $i) {
				$dep1{$node} = $des{$source};
				last;
			}
		}
		$src{$source} = $node;
		$des{$dest} = $node;
		$edge += 1;
	} elsif (/\s*(.*) = \w+ \w+ \[.*\], \[.*\]\* (.*), i\d+ \d+, i\d+ (.*)\s*/) {
#		print;
#		print "5\n";
		my $dest = $1;
		my $source = $2;
		my $source2 = $3;
		foreach my $i (keys %des) {
			if ($source eq $i) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source};
				} else {
					${$dep1{$node}}[1] = $des{$source};
				}
				$src{$source} = $node;
				$source = "XXXX";
			} 
			if ($source2 eq $i) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source2};
				} else {
					${$dep1{$node}}[1] = $des{$source2}; 
				}
				$src{$source2} = $node;
				$source2 = "XXXX";
			}
			last if ($source eq "XXXX" && $source2 eq "XXXX");
		}
		$des{$dest} = $node;
		$edge += 2;
	} elsif (/\s*(.*) =( common)? global/) {
#		print;
#		print "\n21\n$1\n";
		$des{$1} = $node;
	} elsif (/\s*(.*) = getelementptr inbounds (.*), (.*) (.*), (.*) (.*), (.*) (.*)/) { 
#		print;
#		print "7\n";
		my $dest = $1;
		my $source = $4;
		my $source2 = $6;
#		print "source1: $4, source2: $6\n";
		foreach my $i (keys %des) {
			if ($source eq $i) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source};
				} else {
					${$dep1{$node}}[1] = $des{$source};
				}
				$src{$source} = $node;
				$source = "XXXX";
			} 
			if ($source2 eq $i) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source2};
				} else {
					${$dep1{$node}}[1] = $des{$source2}; 
				}
				$src{$source2} = $node;
				$source2 = "XXXX";
			}
			last if ($source eq "XXXX" && $source2 eq "XXXX");
		}
		$des{$dest} = $node;
		$edge += 2;
	} elsif (/\s*(.*) = \w+ i\d+ (.*), i\d+ (.*), i\d+/) {
#		print;
#		print "14\n";
#		print "$1\t$2\t$3\n";
		my $dest = $1;
		my $source = $2;
		my $source2 = $3;
		foreach my $i (keys %des) {
			if ($source eq $i) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source};
				} else {
					${$dep1{$node}}[1] = $des{$source};
				}
				$src{$source} = $node;
				$source = "XXXX";
			} 
			if ($source2 eq $i && $source2 =~ /^%/) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source2};
				} else {
					${$dep1{$node}}[1] = $des{$source2}; 
				}
				$src{$source2} = $node;
				$source2 = "XXXX";
			}
			last if ($source eq "XXXX" && $source2 eq "XXXX");
		}
		$des{$dest} = $node;
		$edge += 2;
	} elsif (/\s*(.*) = \w+ \w+ (.*) (.*), (.*)? (.*)/) {
#		print;
#		print "11\n";
		#print "$1\t$3\t$5\n";
		my $dest = $1;
		my $source = $3;
		my $source2 = $5;
		foreach my $i (keys %des) {
			if ($source eq $i) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source};
				} else {
					${$dep1{$node}}[1] = $des{$source};
				}
				$src{$source} = $node;
				$source = "XXXX";
			} 
			if ($source2 eq $i && $source2 =~ /^%/) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source2};
				} else {
					${$dep1{$node}}[1] = $des{$source2}; 
				}
				$src{$source2} = $node;
				$source2 = "XXXX";
			}
			last if ($source eq "XXXX" && $source2 eq "XXXX");
		}
		$des{$dest} = $node;
	 	$edge += 2;
	} elsif (/\s*(.*) = \w+ \w+ (.*) (.*), (.*)/) {
#		print;
#		print "12\n";
#		print "$1\t$3\t$4\n";
		my $dest = $1;
		my $source = $3;
		my $source2 = $4;
		foreach my $i (keys %des) {
			if ($source eq $i) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source};
				} else {
					${$dep1{$node}}[1] = $des{$source};
				}
				$src{$source} = $node;
				$source = "XXXX";
			} 
			if ($source2 eq $i) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source2};
				} else {
					${$dep1{$node}}[1] = $des{$source2}; 
				}
				$src{$source2} = $node;
				$source2 = "XXXX";
			}
			last if ($source eq "XXXX" && $source2 eq "XXXX");
		}
		$des{$dest} = $node;
		$edge += 2;
	} elsif (/\s*(.*) = \w+ \w+ (.*), (.*)/) {
#		print;
#		print "6\n";
#		print "$1\t$2\t$3\n";
		my $dest = $1;
		my $source = $2;
		my $source2 = $3;
		foreach my $i (keys %des) {
			if ($source eq $i) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source};
				} else {
					${$dep1{$node}}[1] = $des{$source};
				}
				$src{$source} = $node;
				$source = "XXXX";
			} 
			if ($source2 eq $i) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source2};
				} else {
					${$dep1{$node}}[1] = $des{$source2}; 
				}
				$src{$source2} = $node;
				$source2 = "XXXX";
			}
			last if ($source eq "XXXX" && $source2 eq "XXXX");
		}
		$des{$dest} = $node;
		$edge += 2;
	} elsif (/\s*call .* \@.*\(.* \w+ \w+ \(.*, .* (.*), .*, .*\), .* (.*)\)/) {
#		print;
#		print "20\n";
#		print "src: $1\t$2\n";
		my $source = $1;
		my $source2 = $2;
		$dep1{$node}[0] = $node - 1;
		foreach my $i (keys %des) {
#			print "i = $i\n";
			if ($source eq $i) {
				if (!defined ${$dep1{$node}}[1]) {
#					print "HAHA1\n";
					${$dep1{$node}}[1] = $des{$source};
				} else {
#					print "HAHA2\n";
					${$dep1{$node}}[2] = $des{$source};
				}
				$src{$source} = $node;
				$source = "XXXX";
			} 
			if ($source2 eq $i) {
				if (!defined ${$dep1{$node}}[1]) {
#					print "HAHA3\n";
					${$dep1{$node}}[1] = $des{$source2};
				} else {
#					print "HAHA4\n";
					${$dep1{$node}}[2] = $des{$source2}; 
				}
				$src{$source2} = $node;
				$source2 = "XXXX";
			}
			last if ($source eq "XXXX" && $source2 eq "XXXX");
		}
		$edge += 3;
	} elsif (/\s*call .* \@.*\(.* (.*)\)/) {
#		print;
#		print "15\n";
#		print "$1\n";
		my $source = $1;
		my $source2 = $node - 1;
		if (!defined ${$dep1{$node}}[0]) {
			${$dep1{$node}}[0] = $source2;
		} else {
			${$dep1{$node}}[1] = $source2; 
		}
		foreach my $i (keys %des) {
			if ($source eq $i) {
				if (!defined ${$dep1{$node}}[0]) {
					${$dep1{$node}}[0] = $des{$source};
				} else {
					${$dep1{$node}}[1] = $des{$source} if ($des{$source} != ${$dep1{$node}}[0]);
				}
				$src{$source} = $node;
				#$source = "XXXX";
				last;
			}
		}
		$edge += 2;
	} elsif (/\s*(.*) = \w+ (.*) (.*), \d+/) {
#		print "$_\n";
#		print "21\n";
#		print "$1\t$3\n";
		my $dest = $1;
		my $source = $3;
		#print $5;
		foreach my $i (keys %des) {
			if ($source eq $i) {
				$dep1{$node} = $des{$source};
				last;
			}
		}
		$src{$source} = $node;
		$des{$dest} = $node;
		$edge += 1;
	}
	$node++ if defined;
}
#foreach my $index (keys %dep1) {
#	if (ref($dep1{$index}) eq 'ARRAY') {
#		print "$index -> ${$dep1{$index}}[0]\n";
#		print "$index -> ${$dep1{$index}}[1]\n" if defined ${$dep1{$index}}[1];
#		next;
#	}
#	print "$index -> $dep1{$index}\n";
#}
close(IN);

undef %src;
undef %des;

#=cut
my @arr1; my @arr2;
foreach my $index (keys %dep1) {
	if (ref($dep1{$index}) eq 'ARRAY') {
		if (${$dep1{$index}}[0] ne "latency" && ${$dep1{$index}}[0] ne "store") {
			push @arr1, [$index, ${$dep1{$index}}[0], 1];
			push @arr2, [${$dep1{$index}}[0], $index, 1];
			if (defined ${$dep1{$index}}[1]) {
				push @arr1, [$index, ${$dep1{$index}}[1], 1];
				push @arr2, [${$dep1{$index}}[1], $index, 1];	
				if (defined ${$dep1{$index}}[2]) {
					push @arr1, [$index, ${$dep1{$index}}[2], 1];
					push @arr2, [${$dep1{$index}}[2], $index, 1];	
				}
			}
			
		} elsif (${$dep1{$index}}[0] eq "latency") {
			push @arr1, [$index, ${$dep1{$index}}[1], ${$dep1{$index}}[2]];
			push @arr2, [${$dep1{$index}}[1], $index, ${$dep1{$index}}[2]];
		} elsif (${$dep1{$index}}[0] eq "store") {
			push @arr1, [$index, ${$dep1{$index}}[1], ${$dep1{$index}}[2]];
			push @arr2, [${$dep1{$index}}[1], $index, ${$dep1{$index}}[2]];
			if (defined ${$dep1{$index}}[3]) {
				push @arr1, [$index, ${$dep1{$index}}[3], ${$dep1{$index}}[4]];
				push @arr2, [${$dep1{$index}}[3], $index, ${$dep1{$index}}[4]];
			}
		}
		next;
	}
	push @arr1, [$index, $dep1{$index}, 1];
	push @arr2, [$dep1{$index}, $index, 1];
}

undef %dep1;
#foreach my $i (@arr1) {
#	foreach my $j (@{$i}) {
#		print "arr1: $j\n";
#	}
#	print "*************\n";
#}

my @sortedArr1 = sort {$a->[0] <=> $b->[0] || $a->[1] <=> $b->[1]} @arr1;
my @sortedArr2 = sort {$a->[0] <=> $b->[0] || $a->[1] <=> $b->[1]} @arr2;
undef @arr1;
undef @arr2;

my $numOfEdges = $#sortedArr1 + 1;
#print "#edge $numOfEdges\n";
my $numOfNodes = ${$sortedArr1[$numOfEdges - 1]}[0];
open(OUT2, ">$file.gexf");
# some header information
print OUT2 "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
print OUT2 "<gexf xmlns:viz=\"http://www.gexf.net/1.1draft/viz\" ",
"version=\"1.1\" xmlns=\"http://www.gexf.net/1.1draft\">\n";
print OUT2 "<meta lastmodifieddate=\"2017-03-01+6:30\">\n";
print OUT2 "<creator>Gephi 0.7</creator>\n";
print OUT2 "</meta>\n";
print OUT2 "<graph defaultedgetype=\"directed\" idtype=\"string\" ",
"type=\"static\">\n";
my $nodes = $numOfNodes + 1;
print OUT2 "<nodes count=\"$nodes\">\n";
foreach my $idx (0..($numOfNodes)) {
	print OUT2 "<node id=\"$idx.0\" label=\"node#$idx\"/>\n";
}
print OUT2 "</nodes>\n";
print OUT2 "<edges count=\"$numOfEdges\">\n";
foreach my $idx (0..($numOfEdges - 1)) {
	print OUT2 "<edge id=\"$idx\" source=\"${$sortedArr1[$idx]}[0].0\" ".
	"target=\"${$sortedArr1[$idx]}[1].0\" weight=\"${$sortedArr1[$idx]}[2]\"/>\n";
}
print OUT2 "</edges>\n";
print OUT2 "</graph>\n";
print OUT2 "</gexf>\n";
close(OUT2);

#print "arr1:\n";
#foreach my $i (0..20) {
#	print "@{$sortedArr1[$i]}\n";
#}
#print "arr2:\n";
#foreach my $i (0..20) {
#	print "@{$sortedArr2[$i]}\n";
#}
open(OUT, ">$file-dependency.wpairs");
open(OUT1, ">$file-assortativity.py");

print OUT1 "#!/usr/bin/python\n\n";
print OUT1 "import networkx as nx\n";
print OUT1 "G = nx.Graph()\n";
print OUT1 "elist = [";
my $pointer1 = 0;
my $pointer2 = 0;
my $value1 = 0;
my $value2 = 0;
my $value3 = 0;
my $flag = 0;
my $counterIter = 0;
#print "${$arr1[$pointer1]}[0]\n";
while ($pointer1 <= $#sortedArr1 || $pointer2 <= $#sortedArr2) {
	#print "$pointer1\t$pointer2\n";
	#print "$#arr1\t$#arr2\n";
	print OUT1 "," if ($counterIter != 0);
	$counterIter++; 
	$flag = 0;
	if ($pointer1 > $#sortedArr1 && $pointer2 <= $#sortedArr2) {
		$value1 = ${$sortedArr2[$pointer2]}[0];
		$value2 = ${$sortedArr2[$pointer2]}[1];
		$value3 = ${$sortedArr2[$pointer2]}[2];
		#print OUT "${$sortedArr2[$pointer2]}[0]\t${$sortedArr2[$pointer2]}[1]\t${$sortedArr2[$pointer2]}[2]\n";
		$pointer2 += 1;
		$flag = 1;
	} elsif ($pointer1 <= $#sortedArr1 && $pointer2 > $#sortedArr2) {
		$value1 = ${$sortedArr1[$pointer1]}[0];
		$value2 = ${$sortedArr1[$pointer1]}[1];
		$value3 = ${$sortedArr1[$pointer1]}[2];
		#print OUT "${$sortedArr1[$pointer1]}[0]\t${$sortedArr1[$pointer1]}[1]\t${$sortedArr1[$pointer1]}[2]\n";
		$pointer1 += 1;
		$flag = 1;
	}
	if (!$flag && ${$sortedArr1[$pointer1]}[0] < ${$sortedArr2[$pointer2]}[0]) {
		$value1 = ${$sortedArr1[$pointer1]}[0];
		$value2 = ${$sortedArr1[$pointer1]}[1];
		$value3 = ${$sortedArr1[$pointer1]}[2];
		#print OUT "${$sortedArr1[$pointer1]}[0]\t${$sortedArr1[$pointer1]}[1]\t${$sortedArr1[$pointer1]}[2]\n";
		$pointer1 += 1;
		#print OUT "1\n";
	} elsif (!$flag && ${$sortedArr1[$pointer1]}[0] > ${$sortedArr2[$pointer2]}[0]) {
		$value1 = ${$sortedArr2[$pointer2]}[0];
		$value2 = ${$sortedArr2[$pointer2]}[1];
		$value3 = ${$sortedArr2[$pointer2]}[2];
		#print OUT "${$sortedArr2[$pointer2]}[0]\t${$sortedArr2[$pointer2]}[1]\t${$sortedArr2[$pointer2]}[2]\n";
		$pointer2 += 1;
		#print OUT "2\n";
	} else {
		if (!$flag && ${$sortedArr1[$pointer1]}[1] < ${$sortedArr2[$pointer2]}[1]) {
			$value1 = ${$sortedArr1[$pointer1]}[0];
			$value2 = ${$sortedArr1[$pointer1]}[1];	
			$value3 = ${$sortedArr1[$pointer1]}[2];		
			#print OUT "${$sortedArr1[$pointer1]}[0]\t${$sortedArr1[$pointer1]}[1]\t${$sortedArr1[$pointer1]}[2]\n";
			$pointer1 += 1;
		} elsif (!$flag && ${$sortedArr1[$pointer1]}[1] >= ${$sortedArr2[$pointer2]}[1]) {
			$value1 = ${$sortedArr2[$pointer2]}[0];
			$value2 = ${$sortedArr2[$pointer2]}[1];
			$value3 = ${$sortedArr2[$pointer2]}[2];
			#print OUT "${$sortedArr2[$pointer2]}[0]\t${$sortedArr2[$pointer2]}[1]\t${$sortedArr2[$pointer2]}[2]\n";
			$pointer2 += 1;
		} 
	}
	#$value1 -= 1;
	#$value2 -= 1;
	print OUT "$value1\t$value2\t$value3\n";
	
	##################################################################
	# Calculate the assortativity using networkX in python
	# make sure networkX is properly installed in Ubuntu

	print OUT1 "($value1, $value2, $value3)";
	
}

print OUT1 "]\n";
print OUT1 "G.add_weighted_edges_from(elist)\n";
print OUT1 "r = nx.degree_assortativity_coefficient(G)\n";
print OUT1 "print(\"assortativity coefficient = %3.3f\"%r)\n";

close(OUT);
close(OUT1);
# Community Detection
# We will get a file called "level" including all communities and
# corresponding nodes

=comment
system("perl communityDetection.pl");
my %comm2node;
open(IN, "level");
while(<IN>) {
	chomp;
	if (/(\d+) (\d+)/) {
		my $node = $1;
		my $community = $2;
		push @{$comm2node{$community}}, $node;
	}
}
close(IN);

# execute assortativity.py and calculate the coefficient
system("python assortativity.py");
=cut