
=head1 NAME

Bio::Pipeline::Utils::Converter::BaseEnsEMBLConverter

=head1 NOTE

This is never used directly.

No public method in this module.

=cut

package Bio::Pipeline::Utils::Converter::BaseEnsEMBLConverter;

use vars qw(@ISA);

use strict;
# use Bio::SeqFeatureIO;
use Bio::EnsEMBL::Analysis;
use Bio::Pipeline::Utils::Converter;

@ISA = qw(Bio::Pipeline::Utils::Converter);

sub new {
    my ($caller, @args) = @_;
    my $class = ref($caller) || $caller;
    
    if($class eq 'Bio::Pipeline::Utils::Converter::BaseEnsEMBLConverter'){
        my %params = @args;
        @params{map{lc $_} keys %params} = values %params;
        my $instance = $class->_parse_instance($params{-in}, $params{-out});
        return undef unless ($class->_load_module($instance));
        return "$instance"->new(@args);
    }else{
        my $self = $class->SUPER::new(@args);
        $self->_initialize(@args);
        return $self;
    }
}

sub _initialize {
    my ($self, @args) = @_;
    $self->SUPER::_initialize(@args);
    my ($in, $out, $analysis, $contig) = 
        $self->_rearrange([qw(IN OUT ANALYSIS CONTIG)], @args);

    $self->analysis($analysis);
    $self->contig($contig);
    
}

sub _parse_instance {
    my ($self, $in, $out) = @_;
    if($in eq 'Bio::Search::HSP::GenericHSP' and $out eq 'Bio::EnsEMBL::BaseAlignFeature'){
        return 'Bio::Pipeline::Utils::Converter::HSPToEnsEMBLConverter';
    }elsif($in eq 'Bio::SeqFeature::Generic'){
        return 'Bio::Pipeline::Utils::Converter::SeqFeatureToEnsEMBLConverter';
        
    }else{
        $self->throw("[$in] to [$out], not supported");
    }
}

=head2 analysis
    Title   : analysis
    Usage   : $self->analysis
    Function: get and set for analysis
    Return  :
    Args    :

=cut

sub analysis {
    my ($self, $arg) = @_;
    if(defined($arg)){
        $self->{_analysis} = $arg;
    }
    return $self->{_analysis};
}

=head2 contig
    Title   : contig
    Usage   : $self->contig
    Function: get and set for contig
    Return  :
    Args    :

=cut

sub contig {
    my ($self, $arg) = @_;
    if(defined($arg)){
        $self->{_contig} = $arg;
    }
    return $self->{_contig};
}
1;
