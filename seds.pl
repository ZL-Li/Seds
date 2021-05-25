#!/usr/bin/perl -w

# check the arguments
if (@ARGV >= 1 and $ARGV[0] eq '-i') {
    shift(@ARGV);
    $i = 1;
}
if (@ARGV >= 1 and $ARGV[0] eq '-n') {
    shift(@ARGV);
    $n = 1;
}
if (@ARGV >= 2 and $ARGV[0] eq '-f') {
    shift(@ARGV);
    $command = '';
    $command_file = shift(@ARGV);
}
elsif (@ARGV >= 1 and $ARGV[0] !~ /^-/) {
    $command = shift(@ARGV);
}
else{
    print STDERR "usage: $0 [-i] [-n] [-f <script-file> | <sed-command>] [<files>...]\n";
    exit 1;
}
if (@ARGV >= 1) {
    @input_files = @ARGV;
}
# when -i, input files must exist
elsif ($i) {
    print STDERR "usage: $0 [-i] [-n] [-f <script-file> | <sed-command>] [<files>...]\n";
    exit 1;
}

# check command file
if ($command_file) {
    if (open my $f, '<', $command_file){
        my @lines = <$f>;
        close $f;
        $command = join("", @lines);
    }
    else{
        print STDERR "$0: couldn't open file $command_file: No such file or directory\n";
        exit 1;
    }
}

# eliminate the comments
$command =~ s/#.*//g;

# check and classify the commands
my @arguments = split(/[\n;]/, $command);
my @commands;
my %types;

my $index = 0;

while ($index < @arguments) {
    my $command = $arguments[$index];
    if ($command !~ /^\s*$/) {
        my $type = check_command($command);
        if (! $type) {
            # consider ';'
            my $j = $index + 1;
            while ($j < @arguments) {
                $command .= ';' . $arguments[$j];
                my $type = check_command($command);
                if ($type) { # legal when plus ;
                    push @commands, $command;
                    $types{$command} = $type;
                    $index = $j;
                    $find = 1;
                    last;
                }
                $j++;
            }
            if (! $find) {
                print STDERR "$0: command line: invalid command\n";
                exit 1;
            }
        }
        else {
            push @commands, $command;
            $types{$command} = $type;            
        }
    }
    $index++;
}

# check input files
if (@input_files) {
    foreach my $input_file (@input_files) {
        if (open my $f, '<', $input_file){
            close $f;
        }
        else{
            print STDERR "$0: error\n";
            exit 1;
        }
    }
}

# store labels
my %labels; 
$index = 0;

while ($index < @commands) {
    my $command = $commands[$index];
    my $type = $types{$command};

    if ($type eq ':') {
        $command =~ s/^\s*:\s*(\S+)\s*$/$1/;
        $labels{$command} = $index + 1;
    }
    $index++;
}

my %start; # indicator
my $count = 1; # count the line number
my %repeat_c; # store if need to print c
my @output; # store the final output
        
# when no input files -> <STDIN>
if (! @input_files) {
    while (my $line = <STDIN>) {
        # indicate the last line
        my $eof = 0;
        $eof = 1 if (eof);
        my $delete = 0;
        my $index = 0;
        my $success_substitution = 0;

        while ($index < @commands) {
            my $command = $commands[$index];
            my $type = $types{$command};

            if ($type eq 'q') {
                if (command_q ($command, $line, $count, $eof)) {
                    push @output, $line if (! $n);
                    print @output;
                    exit 0;
                }
            }
            elsif ($type eq 'p') {
                my $address = $command;
                $address =~ s/^(.*)p\s*$/$1/;
                if (check_line($command, $address, $line, $count, $eof, \%start)) {
                    push @output, $line;
                }
            }
            elsif ($type eq 'd') {
                my $address = $command;
                $address =~ s/^(.*)d\s*$/$1/;
                if (check_line($command, $address, $line, $count, $eof, \%start)){
                    $delete = 1;
                    last;
                }
            }
            elsif ($type eq 's') {
                $command =~ /^(.*)s(.)((\\\2|(?!\2).)+)\2((\\\2|(?!\2).)*)\2\s*(g?)\s*$/;
                my $address = $1;
                my $dilimiter = $2;
                my $pattern = $3;
                my $substitution = $5;
                my $g = $7;
                if (check_line($command, $address, $line, $count, $eof, \%start)){
                    my $old_line = $line;
                    $line = command_s($line, $dilimiter, $pattern, $substitution, $g);
                    $success_substitution = 1 if ($old_line ne $line);        
                }
            }
            elsif ($type eq 'b') {
                $command =~ /^(.*?)b\s*(\S*)\s*$/;
                my $address = $1;
                my $label = $2;
                if (check_line($command, $address, $line, $count, $eof, \%start)) {
                    if (! $label) {
                        $index = @commands;
                    }
                    else {
                        if ($labels{$label}) {
                            $index = $labels{$label} - 1;
                        }
                        else {
                            print STDERR "$0: error\n";
                            exit 1;
                        }
                    }
                }
            }
            elsif ($type eq 't') {
                $command =~ /^(.*?)t\s*(\S*)\s*$/;
                my $address = $1;
                my $label = $2;
                if (check_line($command, $address, $line, $count, $eof, \%start)) {
                    if (! $label) {
                        if ($success_substitution) {
                            $index = @commands;
                            $success_substitution = 0;
                        }
                    }
                    else {
                        if ($labels{$label}) {
                            if ($success_substitution) {
                                $index = $labels{$label} - 1;
                                $success_substitution = 0;
                            }
                        }
                        else {
                            print STDERR "$0: error\n";
                            exit 1;
                        }
                    }
                }
            }
            elsif ($type eq 'a') {
                $command =~ /^(.*?)a\s*(.+)$/;
                my $address = $1;
                my $words = $2;
                if (check_line($command, $address, $line, $count, $eof, \%start)) {
                    push @output, $line if (! $n);
                    push @output, $words . "\n";
                    $delete = 1;
                }
            }
            elsif ($type eq 'i') {
                $command =~ /^(.*?)i\s*(.+)$/;
                my $address = $1;
                my $words = $2;
                if (check_line($command, $address, $line, $count, $eof, \%start)) {
                    push @output, $words . "\n";
                }
            }
            elsif ($type eq 'c') {
                $command =~ /^(.*?)c\s*(.+)$/;
                my $address = $1;
                my $words = $2;
                if (check_line($command, $address, $line, $count, $eof, \%start)) {
                    if ($address =~ /^\s*\/((\\\/|[^\/])+)\/\s*$/){
                        push @output, $words . "\n";
                    }
                    elsif ($address =~ /^\s*([0-9]*|\$)\s*$/) {
                        push @output, $words . "\n";
                    }
                    else {
                        push @output, $words . "\n" if (! $start{$command});
                    }
                    $delete = 1;
                }
            }
            $index++;
        }
        $count++;
        push @output, $line if (! $n and ! $delete);
    }
    print @output;
}
# when with input files
else {
    foreach my $input_file (@input_files) {
        if ($i) {
            $count = 1;
            @output = ();
        }

        open my $f, '<', $input_file or die "Can not open $input_file\n";
        while (my $line = <$f>){
            # indicate the last line
            my $eof = 0;
            $eof = 1 if (eof);
            my $delete = 0;
            my $index = 0;
            my $success_substitution = 0;

            while ($index < @commands) {
                my $command = $commands[$index];
                my $type = $types{$command};

                if ($type eq 'q') {
                    if (command_q ($command, $line, $count, $eof)) {
                        push @output, $line if (! $n);
                        close $f;
                        if ($i) {
                            open my $f_temp, '>', $input_file or die "Can not open $input_file\n";
                            print $f_temp @output;
                            close $f_temp;
                        }
                        else {
                            print @output;
                        }
                        exit 0;
                    }
                }
                elsif ($type eq 'p') {
                    my $address = $command;
                    $address =~ s/^(.*)p\s*$/$1/;
                    if (check_line($command, $address, $line, $count, $eof, \%start)) {
                        push @output, $line;
                    }
                }
                elsif ($type eq 'd') {
                    my $address = $command;
                    $address =~ s/^(.*)d\s*$/$1/;
                    if (check_line($command, $address, $line, $count, $eof, \%start)){
                        $delete = 1;
                        last;
                    }
                }
                elsif ($type eq 's') {
                    $command =~ /^(.*)s(.)((\\\2|(?!\2).)+)\2((\\\2|(?!\2).)*)\2\s*(g?)\s*$/;
                    my $address = $1;
                    my $dilimiter = $2;
                    my $pattern = $3;
                    my $substitution = $5;
                    my $g = $7;
                    if (check_line($command, $address, $line, $count, $eof, \%start)){
                        my $old_line = $line;
                        $line = command_s($line, $dilimiter, $pattern, $substitution, $g);
                        $success_substitution = 1 if ($old_line ne $line);              
                    }
                }
                elsif ($type eq 'b') {
                    $command =~ /^(.*)b\s+(\S*)\s*$/;
                    my $address = $1;
                    my $label = $2;
                    if (check_line($command, $address, $line, $count, $eof, \%start)) {
                        if (! $label) {
                            $index = @commands;
                        }
                        else {
                            if ($labels{$label}) {
                                $index = $labels{$label} - 1;
                            }
                            else {
                                print STDERR "$0: error\n";
                                exit 1;
                            }
                        }          
                    }
                }
                elsif ($type eq 't') {
                    $command =~ /^(.*)t\s+(\S*)\s*$/;
                    my $address = $1;
                    my $label = $2;
                    if (check_line($command, $address, $line, $count, $eof, \%start)) {
                        if (! $label) {
                            if ($success_substitution) {
                                $index = @commands;
                                $success_substitution = 0;
                            }
                        }
                        else {
                            if ($labels{$label}) {
                                if ($success_substitution) {
                                    $index = $labels{$label} - 1;
                                    $success_substitution = 0;
                                }
                            }
                            else {
                                print STDERR "$0: error\n";
                                exit 1;
                            }
                        }                
                    }
                }
                elsif ($type eq 'a') {
                    $command =~ /^(.*?)a\s*(.+)$/;
                    my $address = $1;
                    my $words = $2;
                    if (check_line($command, $address, $line, $count, $eof, \%start)) {
                        push @output, $line if (! $n);
                        push @output, $words . "\n";
                        $delete = 1;
                    }
                }
                elsif ($type eq 'i') {
                    $command =~ /^(.*?)i\s*(.+)$/;
                    my $address = $1;
                    my $words = $2;
                    if (check_line($command, $address, $line, $count, $eof, \%start)) {
                        push @output, $words . "\n";
                    }
                }
                elsif ($type eq 'c') {
                    $command =~ /^(.*?)c\s*(.+)$/;
                    my $address = $1;
                    my $words = $2;
                    if (check_line($command, $address, $line, $count, $eof, \%start)) {
                        if ($address =~ /^\s*\/((\\\/|[^\/])+)\/\s*$/){
                            push @output, $words . "\n";
                        }
                        elsif ($address =~ /^\s*([0-9]*|\$)\s*$/) {
                            push @output, $words . "\n";
                        }
                        else {
                            push @output, $words . "\n" if (! $start{$command});
                        }
                        $delete = 1;
                    }
                }
                $index++;
            }
            $count++;
            push @output, $line if (! $n and ! $delete);
        }
        close $f;
        if ($i) {
            open my $f_temp, '>', $input_file or die "Can not open $input_file\n";
            print $f_temp @output;
            close $f_temp;
        }
    }
    print @output if (! $i);
}

# check the command, if valid return the simplified version
sub check_regex {
    my ($regex, $dilimiter) = @_;

    # the character \ must be followed by a character
    if ($regex !~ /^(\\.|[^\\])+$/) {
        print STDERR "$0: command line: invalid command\n";
        exit 1;
    }
    if ($dilimiter =~ /\d/) {
        $regex =~ s/\\(.)/$1/g;
    }
    else {
        $regex =~ s/\\(\D)/$1/g;
    }
    return $regex;
}

# check the command, if valid return the command type
sub check_command {
    my ($command, $n) = @_;

    # check command q with regex
    if ($command =~ /^\s*\/(\\\/|[^\/])+\/\s*q\s*$/) {
        return 'q';
    }
    # check command q with num
    if ($command =~ /^\s*([0-9]*|\$)\s*q\s*$/) {
        # eliminate '0q', '00q'...
        return 0 if ($command =~ /^\s*0+\s*q\s*$/);
        return 'q';
    }
    # check command p, d
    if ($command =~ /^(.*)([pd])\s*$/) {
        my $address = $1;
        return $2 if (check_address($address));
    }
    # check command s
    if ($command =~ /^(.*)s(.)(\\\2|(?!\2).)+\2(\\\2|(?!\2).)*\2\s*g?\s*$/) {
        my $address = $1;
        return 's' if (check_address($address));
    }
    # check command :
    if ($command =~ /^\s*:\s*\S+\s*$/) {
        return ':';
    }
    # check command b, t
    if ($command =~ /^(.*?)([bt])\s*\S*\s*$/) {
        my $address = $1;
        return $2 if (check_address($address));
    }
    # check command a, i, c
    if ($command =~ /^(.*?)([aic])\s*.+$/) {
        my $address = $1;
        return $2 if (check_address($address));
    }
    return 0;
}

# check the address, if valid return 1
sub check_address {
    my ($address) = @_;

    # with regex
    return 1 if ($address =~ /^\s*\/(\\\/|[^\/])+\/\s*$/);
    # eliminate '0', '00'...
    return 0 if ($address =~ /^\s*0+\s*$/);
    # with num
    return 1 if ($address =~ /^\s*([0-9]*|\$)\s*$/);
    # with regex, num
    return 1 if ($address =~ /^\s*\/((\\\/|[^\/])+)\/\s*,\s*([0-9]+|\$)\s*$/);
    # with num, regex
    return 1 if ($address =~ /^\s*([0-9]+|\$)\s*,\s*\/((\\\/|[^\/])+)\/\s*$/);
    # with regex, regex
    return 1 if ($address =~ /^\s*\/((\\\/|[^\/])+)\/\s*,\s*\/((\\\/|[^\/])+)\/\s*$/);
    # eliminate '0,1', '00,1'...
    return 0 if ($address =~ /^\s*0+\s*,\s*[0-9]+\s*$/);
    # with num, num
    return 1 if ($address =~ /^\s*([0-9]+|\$)\s*,\s*([0-9]+|\$)\s*$/);

    return 0;
}

# check the line, if the line satisfies the address return 1
sub check_line {
    my ($command, $address, $line, $count, $eof, $start) = @_;

    # with regex
    if ($address =~ /^\s*\/((\\\/|[^\/])+)\/\s*$/) {
        my $pattern = $1;

        $pattern = check_regex($pattern, '/');
        return 1 if ($line =~ $pattern);
    }
    # with num
    if ($address =~ /^\s*([0-9]*|\$)\s*$/) {
        my $line_num = $1;

        # consider 'p'
        if (! $line_num){
            return 1;
        }
        else{
            return 1 if ($line_num ne '$' and $line_num == $count);
            return 1 if ($line_num eq '$' and $eof == 1);
        }
    }
    # with regex, num
    if ($address =~ /^\s*\/((\\\/|[^\/])+)\/\s*,\s*([0-9]+|\$)\s*$/) {
        my $pattern = $1;
        $pattern = check_regex($pattern, '/');
        my $line_num = $3;

        if ($line =~ $pattern) {
            $start->{$command} = 1;
            return 1;
        }
        elsif ($start->{$command} and $line_num ne '$' and $count <= $line_num) {
            return 1;
        }
        elsif ($start->{$command} and $line_num eq '$') {
            return 1;
        }
    }
    # with num, regex
    if ($address =~ /^\s*([0-9]+|\$)\s*,\s*\/((\\\/|[^\/])+)\/\s*$/) {
        my $line_num = $1;
        my $pattern = $2;
        $pattern = check_regex($pattern, '/');

        # consider 0,/.../p
        $start->{$command} = 1 if (! $line_num and $count == 1);

        if (! $start->{$command} and $line_num ne '$' and $count == $line_num) {
            $start->{$command} = 1;
            return 1;
        }
        elsif (! $start->{$command} and $line_num eq '$' and $eof == 1) {
            $start->{$command} = 1;
            return 1;
        }
        elsif ($start->{$command} and $line !~ $pattern) {
            return 1
        }
        elsif ($start->{$command} and $line =~ $pattern) {
            $start->{$command} = 0;
            return 1;
        }
    }
    # with regex, regex
    if ($address =~ /^\s*\/((\\\/|[^\/])+)\/\s*,\s*\/((\\\/|[^\/])+)\/\s*$/) {
        my $pattern1 = $1;
        my $pattern2 = $3;
        $pattern1 = check_regex($pattern1, '/');
        $pattern2 = check_regex($pattern2, '/');

        if (! $start->{$command} and $line =~ $pattern1) {
            $start->{$command} = 1;
            return 1;
        }
        elsif ($start->{$command} and $line !~ $pattern2) {
            return 1;
        }
        elsif ($start->{$command} and $line =~ $pattern2) {
            $start->{$command} = 0;
            return 1;
        }
    }
    # with num, num
    if ($address =~ /^\s*([0-9]+|\$)\s*,\s*([0-9]+|\$)\s*$/) {
        my $line_num1 = $1;
        my $line_num2 = $2;

        if ($line_num1 ne '$' and $count == $line_num1) {
            $start->{$command} = 1;
            return 1;
        }
        elsif ($line_num1 eq '$' and $eof == 1) {
            $start->{$command} = 1;
            return 1;
        }
        elsif ($start->{$command} and $line_num2 ne '$' and $count <= $line_num2) {
            return 1;
        }
        elsif ($start->{$command} and $line_num2 eq '$') {
            return 1;
        }
    }
    return 0;
}

# quit command, return 1 if quit
sub command_q {
    my ($command, $line, $count, $eof) = @_;

    # with regex
    if ($command =~ /^\s*\/((\\\/|[^\/])+)\/\s*q\s*$/) {
        my $pattern = $1;
        $pattern = check_regex($pattern, '/');
        return 1 if ($line =~ $pattern);
    }
    # with num
    if ($command =~ /^\s*([0-9]*|\$)\s*q\s*$/) {
        my $line_num = $1;
        # consider 'q'
        $line_num = 1 if (! $line_num);
        return 1 if ($line_num ne '$' and $line_num == $count);
        return 1 if ($line_num eq '$' and $eof == 1);
    }
    return 0;
}

# substitute command
sub command_s {
    my ($line, $dilimiter, $pattern, $substitution, $g) = @_;
    
    $pattern = check_regex($pattern, $dilimiter) if ($pattern);
    $substitution = check_regex($substitution, $dilimiter) if ($substitution);
    if ($pattern =~ /\(.*\).*\(.*\)/ and $substitution =~ /\\1/ and $substitution =~ /\\2/) {
        if ($line =~ /$pattern/) {
            my $parenthese1 = $1;
            my $parenthese2 = $2;
            $substitution =~ s/\\1/$parenthese1/;
            $substitution =~ s/\\2/$parenthese2/;
        }
    }
    elsif ($pattern =~ /\(.*\)/ and $substitution =~ /\\1/) {
        if ($line =~ /$pattern/) {
            my $parenthese = $1;
            $substitution =~ s/\\1/$parenthese/;
        }
    }
    $line =~ s/$pattern/$substitution/g if ($g);
    $line =~ s/$pattern/$substitution/;

    return $line;
}
