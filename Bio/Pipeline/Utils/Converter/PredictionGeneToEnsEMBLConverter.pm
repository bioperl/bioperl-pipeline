# Converter from Bio::Tools::Prediction::Gene 
# to Bio::EnsEMBL::PredictionTranscript
#
# Author: Xiao Juguang <juguang@fugu-sg.org>
#
# Date: 23.12.2002
#

=head1 NAME

Bio::Pipeline::Converter::PredictionGeneToEnsEMBLConverter

=cut

package Bio::Pipeline::Converter::PredictionGeneToEnsEMBLConverter;

use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::PredictionTranscript;

use Bio::Pipeline::Converter::ExonToEnsEMBLConverter;
use Bio::Pipeline::Converter::BaseEnsEMBLConverter;

@ISA = qw(Bio::Pipeline::Converter::BaseEnsEMBLConverter);

sub new{
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    return $self;
}

=head2 convert


=cut

sub _convert_single{
    my ($self, $input) = @_;
    
    $input || $self->throw("a input object needed");
    unless($input->isa("Bio::Tools::Prediction::Gene")){
        $self->throw("This converter can handle Bio::Tools::Prediction::Gene only");
    }

    my $output = Bio::EnsEMBL::PredictionTranscript->new();

    $output->analysis($self->analysis);

    my $exonConverter = Bio::Pipeline::Converter::ExonToEnsEMBLConverter->new();
    $exonConverter->contig($self->contig);

    my @exons = $input->exons;
    my @ens_exons = @{$exonConverter->convert(\@exons)};

    foreach my $ens_exon (@ens_exons){
        $output->add_Exon($ens_exon);
    }

    return $output;
}

1;
