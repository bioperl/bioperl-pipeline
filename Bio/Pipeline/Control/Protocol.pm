
=head1 NAME

Bio::Pipeline::Control::Protocol

=cut

package Bio::Pipeine::Control::Protocol;

use strict;
use vars qw(@ISA %request_response);
use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);

    return $self;
}


sub request_response {
    my ($class, $request) = @_;
    if(ref($request)){ $request = ref($request); }
    # $request, Bio::Pipeline::Control::AllAnalysisRequest
    my $module;
    if($request =~ /\:\:([^:]+)/){ $module = $1; }
    # $module, AllAnalysisRequest
    my $type;
    if($module =~ /(\w+)Request/){ $type = $1; }
    # $type, AllAnalysis
    return 'Bio::Pipeline::Control::', $type, 'Response';
}


sub server_handle {
    my ($self, $request) = @_;

    my $response;
    return $response;
}

1;
