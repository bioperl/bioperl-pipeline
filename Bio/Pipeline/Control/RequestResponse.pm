
=head1 NAME

Bio::Pipeline::Control::RequestResponse

=cut

package Bio::Pipeline::Control::RequestResponse;

use strict;
use vars qw(@ISA %modules);
use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);

BEGIN{
    %modules = (
        'get_all_analysis' => 'Bio::Pipeline::Control::AllAnalysisRequest',
        'return_all_analysis' => 'Bio::Pipeline::Control::AllAnalysisResponse',
    );

}

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);

    my ($title) = $self->_rearrange([qw(TITLE)], @args);
    $title && $self->title($title);
    return $self;
}

sub title {
    my ($self, $title) = @_;
    return $self->{_title} = $title if defined $title;
    return $self->{_title};
}


sub clear_lines {
    my ($class, $lines) = @_;
    my @lines;
    @lines = (ref($lines) eq 'ARRAY')? @$lines : split "\n", $lines;
    @lines = map{
        if(/\#/){
            $1 if(/([^\#]+)\#/);
        }else{
            $_;
        }
    } @lines;
    my @lines2;
    foreach(@lines){    push @lines2, $_ if($_ ne '');  }
    return \@lines2;
}

1;

