package Bio::Pipeline::Filter::feature_coverage;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::Filter;
use Bio::Pipeline::DataType;

@ISA = qw(Bio::Pipeline::Filter);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);

    my ($threshold) = $self->_rearrange([qw(THRESHOLD)],@args);

    $threshold && $self->threshold($threshold);
}

sub datatypes {
    my ($self) = @_;
    my $dt = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SeqFeatureI',
                                          '-name'=>'sequence',
                                          '-reftype'=>'ARRAY');

    my %dts;
    $dts{input} = $dt;
    return %dts;
}

sub run {
    my ($self,@output) = @_;

    #dummy for now, just return sub set. to be replaced with jerm's filter logic
    $#output > 0 || return;

    return @output[0..1];
}

1;
    



