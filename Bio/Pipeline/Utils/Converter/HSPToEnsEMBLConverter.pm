# Bio::Pipeline::Utils::Converter::HSPToEnsEMBLConverter
#
# Created and Cared by Juguang Xiao <juguang@fugu-sg.org>
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation
#

=head1 NAME

Bio::Pipeline::Utils::Converter::HSPToEnsEMBLConverter

=head1 DESCRIPTION

There is not public method in this module. You are not supposed to use this modu
le directly. Please see Bio::Pipeline::Utils::Converter, for the information of 
how to use converter.

The only methods here, _initialize and _convert_single, are invoked by the converter factory.

=head1 AUTHOR Juguang Xiao

Juguang Xiao <juguang@fugu-sg.org>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal method
s are usually preceded with a _

=cut


package Bio::Pipeline::Utils::Converter::HSPToEnsEMBLConverter;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::Utils::Converter::BaseEnsEMBLConverter;
use Bio::EnsEMBL::DnaPepAlignFeature;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::RawContig;
use Bio::EnsEMBL::SeqFeature;
use Bio::EnsEMBL::FeaturePair;

@ISA = qw(Bio::Pipeline::Utils::Converter::BaseEnsEMBLConverter);

sub _initialize {
    my ($self, @args) = @_;
    $self->SUPER::_initialize(@args);
    my ($return_type, $program) =
        $self->_rearrange([qw( RETURNTYPE PROGRAM)], @args);
    
    $return_type ||= 'hsp';
    $self->return_type($return_type);
    $self->program($program);
}

sub return_type{
    my ($self, $arg) =@_;
    if(defined $arg){
        $self->{_return_type} = $arg;
    }
    return $self->{_return_type};
}

sub program{
    my ($self, $program) = @_;
    if(defined $program){
        $self->{_program} = $program;
    }
    return $self->{_program};
}


=head2 _convert_single

   From Bio::Search::HSP::GenericHSP to Bio::EnsEMBL::BaseAlignFeature

=cut

sub _convert_single{
    my ($self, $hsp) = @_;
    
    $hsp || $self->throw("a input object needed");
    unless($hsp->isa("Bio::Search::HSP::GenericHSP")){
        $self->throw("a Bio::Search::HSP::GenericHSP object needed");
    }
    
    my $program = $self->program; 
    my $align_feature;
    
    $self->analysis || $self->throw("an analysis is needed");
    
    # create cigar string. Ensembl BaseAlignFeature needs it.
    # Since the HSP object does not have cigar string. 
    # So we need to parse it from query and hit string.
    
    my $ens_feature1 = $self->_similarity_2_ens_seqFeature($hsp->feature1, $self->analysis);
    my $ens_feature2 = $self->_similarity_2_ens_seqFeature($hsp->feature2, $self->analysis);
    
    $ens_feature1->p_value($hsp->evalue);
    $ens_feature1->score($hsp->score);
    $ens_feature1->percent_id($hsp->percent_identity);

    $ens_feature2->p_value($hsp->evalue);
    $ens_feature2->score($hsp->score);
    $ens_feature2->percent_id($hsp->percent_identity);
    
    my $ens_featurePair = new Bio::EnsEMBL::FeaturePair(
        -feature1 => $ens_feature1,
        -feature2 => $ens_feature2
    );

# I comment out the line below, since Bio::EnsEMBL::BaseAlignFeature is only
# able to generate cigar string for ungapped alignment.
    my $cigar_string = "";
    my @args = (
#        -features => [$ens_featurePair]
        -feature1 => $ens_feature1,
        -feature2 => $ens_feature2,
        -cigar_string => $cigar_string
    );

    my $contig = $self->contig;

    if($self->program =~ /blastn/i){
        
        $align_feature = new Bio::EnsEMBL::DnaDnaAlignFeature( @args );    
        $align_feature->attach_seq($contig);
    }elsif($self->program =~ /blastx/i){

        $align_feature = Bio::EnsEMBL::DnaPepAlignFeature->new( @args );
        $align_feature->attach_seq($contig);
    }else{
        
        $self->throw("$program is not supported yet'");
    }

    return $align_feature;
}

=head2 _generic_2_ens_seqFeature

convert from Bio::SeqFeature::Generic to Bio::EnsEMBL::SeqFeature

=cut 

sub _generic_2_ens_seqFeature{
    my ($self, $generic, $ens_analysis) = @_;
    unless($generic->isa('Bio::SeqFeature::Generic')){
        $self->throw("A Bio::SeqFeature::Generic object is needed as the first argument");
    }
    
    unless($ens_analysis->isa('Bio::EnsEMBL::Analysis')){
        $self->throw("A Bio::EnsEMBL::Analysis object is needed as the second argument");
    }
    my $ens_seqFeature = new Bio::EnsEMBL::SeqFeature(
        -analysis => $ens_analysis,
        -seqname => $generic->seq_id,
        -start => $generic->start,
        -end => $generic->end,
        -strand => $generic->strand,
        -source_tag => $generic->source_tag,
        -primary_tag => $generic->primary_tag
    );
    $ens_seqFeature->score($generic->score);
    
    # Bio::EnsEMBL::SeqFeature has a special requirement on frame.
    # The value must be one of (0, 1, 2).
    $generic->frame =~ /()(\d+)/;
    my ($symbol, $frame) = ($1, $2);
    $frame = 3 if $frame == 0;
    $ens_seqFeature->frame($frame);
    return $ens_seqFeature;
}
    
sub _similarity_2_ens_seqFeature{
    my ($self, $similarity, $ens_analysis) = @_;
    my $ens_seqFeature = $self->_generic_2_ens_seqFeature($similarity, $ens_analysis);
    # What are the field that Similarity has, but not Generic?
    return $ens_seqFeature; 
}
1;

