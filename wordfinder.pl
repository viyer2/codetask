use strict;
use warnings;
use Mojolicious::Lite;
use Data::Dumper;
use Path::Class;
use Tie::File;
use FindBin;
use Fcntl 'O_RDONLY';
get '/ping' => { text => '200 OK' };

get '/wordfinder/:word' => sub {
    my $c = shift;

    # get the users input
    my $response = [];
    $response = $c->look_for_words();
    $c->render( json => $response );
};

helper look_for_words => sub {
    my $c = shift;

    my @response      = ();
    my %response_hash = ();
    my $input         = $c->param('word');

    # make everything one case
    $input = lc($input);

    # now we have work to do
    # Split the input into individual charecters
    my @individual_chars = split( /|/, $input );

    # sort the array so we know which character to pick first
    # we can skip all words that do not beging with a charecter
    # we don't have. Requirements state that input letters can
    # only be used once each. so I can use an alphabet only
    # as many times as I got it
    @individual_chars = sort(@individual_chars);

    # identify the length of the users input
    my $input_length = scalar(@individual_chars);

    if ( $input_length == 1 ) {
        push( @response, $input );
    }
    else {

        my $index_hr = $c->build_or_load_index_file();

        # we need not look at any words that are longer than
        # input_length. Look only for words that are maximum
        # of $input_length charecters long.
        my @dict_array;
        tie( @dict_array, 'Tie::File', "/usr/share/dict/words",
            'mode' => 'O_RDONLY' )
            or die "Cannot open dictionary file for reading $!";
        my $expression = join( '|', @individual_chars );
        my %count_expr = ();
        foreach my $char (@individual_chars) {
            $count_expr{$char} += 1;
        }

        # set this to all other alphabets other than the
        # ones you have. This way we can then skip all words
        # that don't have our alphabets
        my $skip_alphas = $c->get_skip_alphas($expression);
        my %t1;
        my $file_length = @dict_array;
    LOOP: foreach my $char ( sort keys %count_expr ) {
            my $start_index = $index_hr->{$char}{'start'};
            my $end_index   = $index_hr->{$char}{'end'};
            for (
                my $index = $start_index;
                $index <= $end_index;
                $index += 1
                )
            {
                my $word = $dict_array[$index];
                chomp($word);
                $word = lc($word);
                $word = $c->trim($word);

                if (length($word) > $input_length) {
                	next ;
                }
                if ( $skip_alphas->{$char} ) {
                    $index = $index_hr->{$char}{'end'};
                    next LOOP;
                }
                next if ( length($word) == 1 );
                my @t_split = split( /|/, $word );

                # get how many times we have each char in input
                my %count_word = ();
                foreach my $char (@t_split) {
                    $count_word{$char} += 1;
                }

                my $match = 0;
                foreach my $c (@t_split) {
                    next if ( !$count_expr{$c} );
                    if ( $count_word{$c} <= $count_expr{$c} ) {
                        $match += 1;
                    }
                }
                $response_hash{$word} = 1 if ( $match == length($word) );
            }
        }
        untie @dict_array;
    }

    foreach my $key ( sort keys %response_hash ) {
        push( @response, $key );
    }
    return \@response;
};

helper get_skip_alphas => sub {
    my ( $self, $input ) = @_;

    my @chars = ( 'a' .. 'z' );

    my @temp = grep ( !/($input)/, @chars );

    my %hash = map { $_ => 1 } @temp;

    return \%hash;
};

helper build_or_load_index_file => sub {
    my ($self) = @_;

    my $index_file
        = Path::Class::File->new( "$FindBin::Bin", 'cache', 'index_file' );

    my %response   = ();
    my @file_lines = ();
    if ( !-f $index_file ) {
        tie( @file_lines, 'Tie::File', "/usr/share/dict/words",
            'mode' => 'O_RDONLY' )
            or die "Cannot open file $!";

        # this has not slurped the whole file
        # Tie::File is really smart
        my $total_lines = @file_lines;
        for ( my $index = 0; $index < $total_lines; $index += 1 ) {
            my $line = $file_lines[$index];
            chomp($line);
            $line = $self->trim($line);
            my $first_char = substr( $line, 0, 1 );
            if ( $response{$first_char}{'start'} ) {
                $response{$first_char}{'end'} = $index;
            }
            else {
                $response{$first_char}{'start'} = $index;
                $response{$first_char}{'end'}   = $index;
            }
        }
        untie @file_lines;
        my $fh = $index_file->openw
            or die "Cannot open $index_file for writing $!";
        foreach my $key ( keys %response ) {
            print $fh
                "$key|$response{$key}{'start'}|$response{$key}{'end'}\n";
        }
        close($fh) or die "Cannot write file to disk $!";
    }
    else {
        # the file exists
        my $fh = $index_file->openr();
        while (<$fh>) {
            chomp();
            my (@temp) = split(/\|/);
            $response{ $temp[0] }{'start'} = $temp[1];
            $response{ $temp[0] }{'end'}   = $temp[2];
        }
        close($fh);
    }

    return \%response;
};

helper trim => sub {
    my ( $self, $value ) = @_;
    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    $value =~ s/"'-//;
    return $value;
};
app->start
