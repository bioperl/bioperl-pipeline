#Cared for by Balamurugan Kumarasamy <savikalpa@fugu-sg.org>
#
# Copyright Balamurugan Kumarasamy
#
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

=head1 CONTACT

Describe contact details here

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
  my $params = $self->params;

  $self->throw("Analysis not set") unless $self->analysis->isa("Bio::Pipeline::Analysis");
  my $factory;
  if($self->analysis->parameters){
    my @params = $self->parse_params($self->analysis->parameters);
    $factory = Bio::Tools::Run::Genscan->new(@params);
  }
  else {
    $factory = Bio::Tools::Run::Genscan->new();
  }

  my @genes;
  eval {
    @genes = $factory->predict_genes($seq);
  };
  $self->output(\@genes);
  
  return \@genes;

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




