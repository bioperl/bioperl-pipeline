
=head1 NAME

Bio::Pipeline::Control::AnalysisStatus

The summary of analysis status can be viewed like

    {
        'NEW' => 100,
        'SUBMITTED' => {
            'READING' => 20,
            'RUNNING' => 12,
            'WRITING' => 30,
            'BATCHED' => 4
        },
        'FAILED' => {
            'READING' => 0,
            'RUNNING' => 3,
            'WRITING' => 7,
            'BATCHED' => 1
        },
        'COMPLETED' => 230
    }

=cut

package Bio::Pipeline::Control::AnalysisStatus;

use strict;
use vars qw(@ISA);
use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);

sub new {
    my ($class, $status) = @_;
    unless(ref($status) eq 'HASH'){ $class->throw("a hash reference required");}
    my $self = $class->SUPER::new();
    $self->status($status);
    return $self;
}

=head2 status
  Title   : status
  Usage   : $self->status
  Function: get and set for status
  Return  : 
  Args    :    
=cut

sub status {
    my ($self, $arg) = @_;
    if(defined($arg)){
        $self->{_status} = $arg;
    }
    return $self->{_status};
}

1;
