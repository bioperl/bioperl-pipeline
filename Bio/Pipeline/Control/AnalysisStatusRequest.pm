
=head1 NAME

Bio::Pipeline::Control::AnalysisStatusRequest

=cut

package Bio::Pipeline::Control::AnalysisStatusRequest;

use strict;
use vars qw(@ISA);
use Bio::Pipeline::Control::Request;

@ISA = qw(Bio::Pipeline::Control::Request);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    my ($analysis_id) = $self->_rearrange([qw(ANALYSIS_ID)], @args);
    $analysis_id || $self->throw("analysis_id is required");
    $self->analysis_id($analysis_id);
    return $self;
}

    
