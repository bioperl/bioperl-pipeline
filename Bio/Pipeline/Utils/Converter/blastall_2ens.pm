:
package Bio::Pipeline::Converter::blastall_2ens;

use vars qw(@ISA);

use strict;
use Bio::SeqFeatureIO;
use Bio::Pipeline::Converter::_2ens;
use Bio::EnsEMBL::DnaPepAlignFeature;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::Pipeline::Converter::blastall_utils;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::RawContig;
use Bio::EnsEMBL::SeqFeature;
use Bio::EnsEMBL::FeaturePair;

@ISA = qw(Bio::Pipeline::Converter::_2ens);

sub new{
    my($class, @args) = @_;
    my $self = $class->SUPER::new(@args);  
    my($return_type,$program) =
      $self->_rearrange([qw( RETURNTYPE PROGRAM)], @args);

    unless(defined $return_type){
        $self->{_return_type} = 'hsp';
    }else{
        $self->{_return_type} = $return_type;
    }
    
    $self->{_program} = $program;

    return $self;
}

sub convert{
   my ($self, $arg) = @_;
   
   
   if($self->return_type =~ /hit/i){
       $self->throw("currently not supported");
   }else{
      my @hsps = @{$arg};
      my @align_features;
      foreach my $hsp (@hsps){
          my $align_feature = $self->_hsp_2ens($hsp);
          push @align_features, $align_feature;
      }
      return \@align_features;
   }
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


=head2 _hsp_2ens

   From Bio::Search::HSP::GenericHSP to Bio::EnsEMBL::BaseAlignFeature

=cut

sub _hsp_2ens{
    my ($self, $hsp) = @_;
    my $program = $self->program; 
    my $align_feature;
    
    $self->analysis || $self->throw("an analysis is needed");
    my $analysis = $self->analysis;
    
    # create cigar string. Ensembl BaseAlignFeature needs it.
    # Since the HSP object does not have cigar string. 
    # So we need to parse it from query and hit string.
    my $blastall_utils = new Bio::Pipeline::Converter::blastall_utils;
    my ($align_coordinates_ref, $cigar_string) = $blastall_utils->split_HSP($hsp);
    
    my $ens_feature1 = $self->_similarity_2_ens_seqFeature($hsp->feature1, $analysis);
    my $ens_feature2 = $self->_similarity_2_ens_seqFeature($hsp->feature2, $analysis);
    
    my $ens_featurePair = new Bio::EnsEMBL::FeaturePair(
        -feature1 => $ens_feature1,
        -feature2 => $ens_feature2
    );
    
    my @args = (
#        -features => [$ens_featurePair]
        -feature1 => $ens_feature1,
        -feature2 => $ens_feature2,
        -cigar_string => $cigar_string
    );

    my $contig = new Bio::EnsEMBL::RawContig(
        $self->contig_dbID()
    );

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
    
    # Bio::EnsEMBL::SeqFeature has a special requirement on frame.
    # The value must be one of (0, 1, 2).
    # $ens_seqFeature->frame($generic->frame);
    return $ens_seqFeature;
}
    
sub _similarity_2_ens_seqFeature{
    my ($self, $similarity, $ens_analysis) = @_;
    my $ens_seqFeature = $self->_generic_2_ens_seqFeature($similarity, $ens_analysis);
    # What are the field that Similarity has, but not Generic?
    return $ens_seqFeature; 
}
1;

