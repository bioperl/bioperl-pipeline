

package Bio::Pipeline::Utils::Converter::PredictionExonToEnsEMBLConverter;

use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::RawContig;
use Bio::EnsEMBL::Exon;

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
    unless($input->isa("Bio::Tools::Prediction::Exon")){
        $self->throw("a Bio::Tools::Prediction::Exon object needed");
    }

    $output = Bio::EnsEMBL::Exon->new(
        -start => $input->start,
        -end => $input->end,
        -strand => $input->strand
    );
    
    $output->contig($self->contig);
    $output->score($input->score);
    
    my ($phase) = $input->get_tag_values("phase");
    my ($end_phase) = $input->get_tag_values("end_phase");
    my $p_value = $input->significance;
    
    $output->phase($phase);
    $output->end_phase($end_phase);
    $output->p_value($p_value);
    
    return $output;
}

1;
