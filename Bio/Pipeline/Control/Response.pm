
=head1 NAME

Bio::Pipeline::Control::Response

=cut

package Bio::Pipeline::Control::Response;

use strict;
use vars qw(@ISA);
use Bio::Pipeline::Control::RequestResponse;

@ISA = qw(Bio::Pipeline::Control::RequestResponse);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    return $self;
}

sub encode {
    my ($class, $response) = @_;
    $class->throw_not_implement;
}

sub decode {
    my ($class, $message) = @_;
    
    $class->throw_not_implement;
}
