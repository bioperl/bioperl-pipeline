package Bio::Pipeline::Utils::Converter::ExonToEnsEMBLConverter;

use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::RawContig;
use Bio::EnsEMBL::Exon;
use vars qw(@ISA);

use Bio::Pipeline::Utils::Converter::BaseEnsEMBLConverter;

@ISA = qw(Bio::Pipeline::Utils::Converter::BaseEnsEMBLConverter);

=head2 new

No implementation for this new. The one in SUPER will be invoked.

=cut

=head2 _convert_single

=cut

sub _convert_single{
    my ($self, $input) = @_;
    
    $input || $self->throw("a input object needed");
    unless(defined $input && ref $input && $input->isa("Bio::SeqFeature::Gene::Exon")){
        $self->throw("a Bio::SeqFeature::Gene::Exon object needed");
    }

    $output = Bio::EnsEMBL::Exon->new(
        -start => $input->start,
        -end => $input->end,
        -strand => $input->strand
    );
    
    $output->contig($self->contig);
    $output->score($input->score);
    
    # The following 3 lines are copied from PredictionExonToEnsEMBLConverter
    my ($phase) = $input->get_tag_values("phase");
    my ($end_phase) = $input->get_tag_values("end_phase");
    my $p_value = $input->significance;
    
    $output->phase($phase);
    $output->phase_end($phase_end);
    $output->p_value($p_value);
    
    return $output;
}

1;
