
# BioPipe module for converting 
# BioPerl object Bio::SeqFeature::Generic to
# EnsEMBL object Bio::EnsEMBL::SimpleFeature.
#
# Cared for by Juguang Xiao <juguang@fugu-sg.org>
#
# You may distrubute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME

Bio::Pipeline::Utils::Converter::SeqFeatureToEnsEMBLConverter

=head1 SYNOPSIS

    See L<Converter>

=head1 DESCRIPTION

This module is originally intent to be used in BioPipe, however, you can also 
feel free to apply in any field if you feel comfortable.

The only method in this module, _converter_single, cannot be invoked directly.
You should construct a converter by calling converter factory.
=cut

# Gentlemen, start your engine...

package Bio::Pipeline::Utils::Converter::SeqFeatureToEnsEMBLConverter;

use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::SeqFeature;
use Bio::Pipeline::Utils::Converter::BaseEnsEMBLConverter;

@ISA = qw(Bio::Pipeline::Utils::Converter::BaseEnsEMBLConverter);

sub _convert_single{
     my ($self, $input) = @_;

    unless($input && defined($input) &&  ref($input) && $input->isa('Bio::SeqFeature::Generic')){
        $self->throw("Bio::SeqFeature::Generic object is needed.");
    }

    my $ens_simple_feature = new Bio::EnsEMBL::SeqFeature;
    $ens_simple_feature->analysis($self->analysis);
    $ens_simple_feature->attach_seq($self->contig);
    
    my $generic = $input;
    $ens_simple_feature->start($generic->start);
    $ens_simple_feature->end($generic->end);
    $ens_simple_feature->strand($generic->strand);
    $ens_simple_feature->score($generic->score);
#    $ens_simple_feature->display_label('__NONE__');
    
    return $ens_simple_feature;
}

1;
