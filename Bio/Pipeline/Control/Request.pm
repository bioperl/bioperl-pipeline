
=head1 NAME

Bio::Pipeline::Control::Request

=cut

package Bio::Pipeline::Control::Request;

use strict;
use vars qw(@ISA %commandModules);
use Bio::Pipeline::Control::RequestResponse;

@ISA = qw(Bio::Pipeline::Control::RequestResponse);

BEGIN{
    %commandModules = (
        'get_all_analysis' => 'Bio::Pipeline::Control::AllAnalysisRequest'
    );
}

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);

    my ($dbhost, $dbname, $dbuser, $dbpass, $dbobj) = 
        $self->_rearrange([qw(HOST DBNAME USER PASS DBOBJ)],
            @args);
        
    if(defined $dbobj){
        $self->dbobj($dbobj);
    }elsif($dbname){
        my $db = Bio::Pipeline::SQL::DBAdaptor->new(
            -host => $dbhost,
            -dbname => $dbname,
            -user => $dbname,
            -pass => $dbpass
        );
        $self->dbobj($db);
    }else{
        $self->throw("DB object not assigned");
    }
        
    return $self;
}

sub dbobj {
    my ($self, $dbobj) = @_;
    return $self->{_dbobj} = $dbobj if defined $dbobj;
    return $self->{_dbobj};
}

=head2 encode

static sub.

the process to convert request object to message.

=cut 

sub encode {
    my ($class, $request) = @_;
    $class->throw_not_implement;
}

=head2 decode

the process to convert message to request object.

=cut

sub decode {
    my ($class, $message) = @_;
    my @lines = $class->clear_line($message);
    
    my $firstline = $lines[0];
    if($firstline =~ /\[([\w\_]+)\[/){
        my $title = $1;
        return $commandModules{$title}->decode($message);
    }else{
        $class->throw("cannot recongize the command:\t$firstline");
    }
}

#    $class->throw_not_implement;
#}

