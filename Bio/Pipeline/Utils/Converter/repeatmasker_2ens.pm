
package Bio::Pipeline::Converter::repeatmasker_2ens;

use vars qw(@ISA);

use strict;
use Bio::EnsEMBL::RepeatFeature;
use Bio::EnsEMBL::RepeatConsensus;
use Bio::EnsEMBL::RawContig;
use Bio::Pipeline::Converter::_2ens;

@ISA = qw(Bio::Pipeline::Converter::_2ens);


sub new{
    my ($class, @args) = @_;
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
    
    $self->analysis || $self-throw("an analysis is needed");
    my $analysis = $self->analysis;
    
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

        my ($h_start, $h_end);

        if($feature1->strand == 1){
            $h_start = $feature2->start;
            $h_end = $feature2->end;
        }elsif($feature1->strand == -1){
            $h_start = $feature2->end;
            $h_end = $feature2->start;
        }else{
            $self->throw("strand cannot be outside of (1, -1)");
        }
        
        $ens_repeatfeature->hstart($h_start);
        $ens_repeatfeature->hend($h_end);

        my $repeat_name = $feature2->seq_id;
        my $repeat_class = $feature1->primary_tag;
        $repeat_class ||= $feature2->primary_tag;
        $repeat_class ||= "not sure";
        my $ens_repeat_consensus = $self->_create_consensus($repeat_name, $repeat_class);
        $ens_repeatfeature->repeat_consensus($ens_repeat_consensus);
        
        # Bio::EnsEMBL::DBSQL::RepeatFeatureAdaptor need RepeatFeature to have a RawContig in entire_seq()
#        unless($self->contig_dbID()){
            my $contig_dbID = $self->ens_dbadaptor->get_RawContigAdaptor->get_internal_id_by_id($self->contig_name());
            $self->contig_dbID($contig_dbID);
#        }
        my $contig = new Bio::EnsEMBL::RawContig(
            $self->contig_dbID()
        );
        
        $ens_repeatfeature->attach_seq($contig);
         
        $ens_repeatfeature->analysis($analysis);

         push @ens_repeatfeatures, $ens_repeatfeature;
     }

     return  \@ens_repeatfeatures;

}

sub _create_consensus{
    my ($self, $repeat_name, $repeat_class) = @_;
    
    my $consensus = new Bio::EnsEMBL::RepeatConsensus;
    $consensus->name($repeat_name);
    $consensus->repeat_class($repeat_class);

    return $consensus;
}
1;
