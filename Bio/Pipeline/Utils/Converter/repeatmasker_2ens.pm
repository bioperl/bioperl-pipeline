
package Bio::Pipeline::Converter::repeatmasker_2ens;

use vars qw(@ISA);

use strict;
use Bio::EnsEMBL::RepeatFeature;
use Bio::Pipeline::Converter::_2ens;

@ISA = qw(Bio::Pipeline::Converter::_2ens);


sub new{
    my($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    return $self;
}

=head2 convert

From Bio::SeqFeature::FeaturePair to Bio::EnsEMBL::RepeatFeature

=cut

sub convert{
    my ($self, $arg) = @_;
    my @pairs = @{$arg};
    my @ens_repeatfeatures;
    
    my $analysis = $self->ens_dbadaptor->get_AnalysisAdaptor->fetch_by_logic_name('repeatmasker');
    
    foreach my $pair (@pairs){
        my $feature1 = $pair->feature1;
        my $feature2 = $pair->feature2;
        my $ens_repeatfeature = new Bio::EnsEMBL::RepeatFeature(
            -seqname => $feature1->seq_id,
            -start => $feature1->start,
            -end => $feature1->end,
            -strand => $feature1->strand,
            -source_tag => $feature1->source_tag,
        );
        $ens_repeatfeature->analysis($analysis);
        $ens_repeatfeature->hstart($feature2->start);
        $ens_repeatfeature->hend($feature2->end);
         push @ens_repeatfeatures, $ens_repeatfeature;
     }

     return  \@ens_repeatfeatures;

}

1;
