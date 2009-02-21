# Pipeline Runnable for Genscan Bio::Pipeline::Runnable::Genscan
#
# Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Genscan
# originally written by Michele Clamp  <michele@sanger.ac.uk>
# Written in BioPipe by Fugu student intern Low Yik Jin
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)
# Written in BioPipe by Fugu student intern Low Yik Jin
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code


=head1 NAME

Bio::Pipeline::Runnable::Genscan

=head1 SYNOPSIS

 my $runnable = Bio::Pipeline::Runnable::Genscan->new();
 $runnable->analysis($analysis);
 $runnable->run;
 my $output = $runnable->output;

=head1 DESCRIPTION

This is the pipeline wrapper for Genscan that makes use of
Bio::Tools::Run::Genscan module.

Note:

  parameters are set in the parameters column inside the biopipeline
  analysis table.
  For more detailed explanation of the parameters  go to
  Bio::Tools::Run:Genscan.


INPUT DATATYPES

The runnable currently accepts  Bio::PrimarySeqI object

OUTPUT DATATYPES

The runnable currently returns an array of Bio::Tools::Prediction::Gene objects

=head1 AUTHOR

Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Genscan.
Originally written by Michele Clamp, michele@sanger.ac.uk.
Written in BioPipe by Fugu student intern Low Yik Jin.
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
Cared for by the Fugu Informatics team, fuguteam@fugu-sg.org.

=head1 APPENDIX

=cut

package Bio::Pipeline::Runnable::Genscan;
use vars qw(@ISA);
use strict;
use FileHandle;
use Bio::PrimarySeq;
use Bio::SeqFeature::FeaturePair;
use Bio::SeqFeature::Generic;
use Bio::SeqI;
use Bio::SeqIO;
use Bio::Root::Root;
use Bio::Pipeline::DataType;
use Bio::Pipeline::RunnableI;
use Bio::Tools::Run::Genscan;

@ISA = qw(Bio::Pipeline::RunnableI);

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  return $self;

}

=head2 datatypes

 Title   :   datatypes
 Usage   :   $self->datatypes
 Function:   Returns the datatypes that the runnable requires. This is used by the Runnable DB to
             match the inputs to the corresponding.
 Returns :   It returns a hash of the different data types. The key of the hash is the name of the
             get/set method used by the RunnableDB to set the input
 Args    :

=cut

sub datatypes {
    my ($self) = @_;
    my $dt1 = Bio::Pipeline::DataType->new('-object_type'=>'Bio::PrimarySeqI',
                                           '-name'=>'sequence',
                                           '-reftype'=>'SCALAR');
    my %dts;
    $dts{feat1} = $dt1;

    return %dts;
}
 
=head2 feat1

 Title   :   feat1
 Usage   :   $self->feat1($seq)
 Function:
 Returns :
 Args    :

=cut

sub feat1{
    my ($self,$feat) = @_;
    if (defined($feat)){
        $self->{'_feat1'} = $feat;
    }
    return $self->{'_feat1'};
}

=head2 run

 Title   :   run
 Usage   :   $self->run($seq)
 Function:   Runs Genscan
 Returns :
 Args    :

=cut

sub run {
  my ($self) = @_;
  my $seq = ($self->feat1);

  $self->throw("Analysis not set") unless $self->analysis->isa("Bio::Pipeline::Analysis");
  my $factory;
  my @params;
  push @params ,$self->parse_params($self->analysis->analysis_parameters);
  $factory = Bio::Tools::Run::Genscan->new(@params);
  $factory->quiet(1);
  my @genes;
  eval {
    @genes = $factory->predict_genes($seq);
  };
  $self->throw("Error predicting genes due to $@") if $@;

  foreach my $g(@genes){
    $self->contig_id && $g->add_tag_value('contig_id'=>$self->contig_id);
  }
  $self->output(\@genes);

  
  return \@genes;

}

sub contig_id {
    my ($self,$value) = @_;
    if($value){
        $self->{'_contig_id'} = $value;
    }
    return $self->{'_contig_id'};
}

=head2 output


 Title   :   output
 Usage   :   $self->output($seq)
 Function:   Get/set method for output
 Returns :   An array of Bio::Tools::Prediction::Gene objects
 Args    :   An array ref to an array of Bio::Tools::Prediction::Gene objects

=cut

sub output{
    my ($self,$gene) = @_;
    if(defined $gene){
      (ref($gene) eq "ARRAY") || $self->throw("Output must be an array reference.");
      $self->{'_gene'} = $gene;
    }
    return @{$self->{'_gene'}};
} 




