# Bio::Pipeline::Utils::Converter::FeaturePairToEnsEMBLConverter
#
# Created and Cared by Juguang Xiao <juguang@fugu-sg.org>
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation
#

=head1 NAME

Bio::Pipeline::Utils::Converter::FeaturePairToEnsEMBLConverter

=head1 DESCRIPTION

PLEASE read the document on Bio::Pipeline::Utils::Converter to know
how to use this module.

=head1   


=head1 AUTHOR Juguang Xiao

Juguang Xiao <juguang@fugu-sg.org>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal method
s are usually preceded with a _

=cut

# Let the code starts ...

package Bio::Pipeline::Utils::Converter::FeaturePairToEnsEMBLConverter;

use vars qw(@ISA);

use strict;
use Bio::EnsEMBL::RepeatFeature;
use Bio::EnsEMBL::RepeatConsensus;
use Bio::EnsEMBL::RawContig;
use Bio::Pipeline::Utils::Converter::BaseEnsEMBLConverter;

@ISA = qw(Bio::Pipeline::Utils::Converter::BaseEnsEMBLConverter);


sub new{
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    
    return $self;
}

=head2 _convert_single

From Bio::SeqFeature::FeaturePair to Bio::EnsEMBL::RepeatFeature

=cut


sub _convert_single {
    my ($self, $pair) = @_;
    my $feature1 = $pair->feature1;
    my $feature2 = $pair->feature2;
    my $ens_repeatfeature = new Bio::EnsEMBL::RepeatFeature(
        -seqname => $feature1->seq_id,
        -start => $feature1->start,
        -end => $feature1->end,
        -strand => $feature1->strand,
        -source_tag => $feature1->source_tag,
    );

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
    my $ens_repeat_consensus = 
    $self->_create_consensus($repeat_name, $repeat_class);
    $ens_repeatfeature->repeat_consensus($ens_repeat_consensus);

# Bio::EnsEMBL::DBSQL::RepeatFeatureAdaptor need RepeatFeature 
# to have a RawContig in entire_seq()

    $ens_repeatfeature->attach_seq($self->contig);
    $ens_repeatfeature->analysis($self->analysis);
    return $ens_repeatfeature;
}     

sub _create_consensus{
    my ($self, $repeat_name, $repeat_class) = @_;
    
    my $consensus = new Bio::EnsEMBL::RepeatConsensus;
    $consensus->name($repeat_name);
    $consensus->repeat_class($repeat_class);

    return $consensus;
}
1;
