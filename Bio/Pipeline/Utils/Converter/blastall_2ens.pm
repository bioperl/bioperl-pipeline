
package Bio::Pipeline::Converter::blastall_2ens;

use vars qw(@ISA);

use strict;
use Bio::SeqFeatureIO;
use Bio::Pipeline::Converter::_2ens;

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
    my $analysis = $self->ens_dbadaptor->get_AnalysisAdaptor->fetch_by_logic_name('repeatmasker');
    if($self->program =~ /blastn/i){
        my $feature1 = $hsp->feature1;
        my $feature2 = $hsp->feature2;
        
        $align_feature = Bio::EnsEMBL::DnaDnaAlignFeature->new(
            -seqname => $feature1->seq_id,
            -start => $feature1->start,
            -end => $feature1->end,
            -strand => $feature1->strand,
            -hstart => $feature2->start,
            -hend => $feature2->end,
            -analysis =>$analysis 
        );    
    }elsif($self->program =~ /blastx/i){
        my $feature1 = $hsp->feature1;
        my $feature2 = $hsp->feature2;

        $align_feature = Bio::EnsEMBL::DnaDnaAlignFeature->new(
            -seqname => $feature1->seq_id,
            -start => $feature1->start,
            -end => $feature1->end,
            -strand => $feature1->strand,
            -hstart => $feature2->start,
            -hend => $feature2->end,
            -analysis =>$analysis 
        ); 
    }else{
        
        $self->throw("$program is not supported yet'");
    }

    return $align_feature;
}

1;

