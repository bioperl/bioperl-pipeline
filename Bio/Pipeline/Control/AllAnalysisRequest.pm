

package Bio::Pipeline::Control::AllAnalysisRequest;

use strict;
use vars qw(@ISA);
use Bio::Pipeline::Control::Request;

@ISA = qw(Bio::Pipeline::Control::Request);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);

    return $self;

}

sub decode {
    my ($class, $message) = @_;

    my @lines;
    if(ref($message) eq 'ARRAY'){
        @lines = @{$message};
    }else{
        @lines = split "\n", $message;
    }
    
    my $command;
    my $firstline = shift @lines;
    if($firstline =~ /\[([\w\_]+)\[/){
        $command = $1;
    }else{
        $class->throw("Can't recognize the command:\t$firstline");
    }

    my %tmp;
    foreach(@lines){
        last if(/^\/\//); 
        
        my ($tag, $value) = split;
        $tmp{$tag} = $value;
    }

    return $class->new(
        -command => $command,
        -host => $tmp{'dbhost'},
        -dbname => $tmp{dbname},
        -user => $tmp{dbuser},
        -pass => $tmp{dbpass}
    );
}

sub encode {
    ;
}

