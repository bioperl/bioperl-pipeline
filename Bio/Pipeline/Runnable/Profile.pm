# Pipeline module for Profile Bio::Pipeline::Runnable::Profile
#
# Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Protein::Profile
# originally written by Emmanuel Mongin <mongin@ebi.ac.uk>
# Written in BioPipe by Balamurugan Kumarasamy <savikalpa@fugu-sg.org>
# Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)

# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

Bio::Pipeline::Runnable::Profile

=head1 SYNOPSIS

 my $runnable = Bio::Pipeline::Runnable::Profile->new();
 $runnable->analysis($analysis);
 $runnable->run;
 my $output = $runnable->output;

=head1 DESCRIPTION

Runnable for Profile

=head1 AUTHOR

 Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Protein::Profile
 originally written by Emmanuel Mongin <mongin@ebi.ac.uk>
 Written in BioPipe by Balamurugan Kumarasamy <savikalpa@fugu-sg.org>
 Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)


=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _.

=cut

package Bio::Pipeline::Runnable::Profile;
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
use Bio::Tools::Run::Profile;

@ISA = qw(Bio::Pipeline::RunnableI);

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  return $self;

}

=head2 datatypes

 Title   :   datatypes
 Usage   :   $self->datatypes
 Function:   Returns the datatypes that the runnable requires.
 Returns :   It returns a hash of the different data types.
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
 Function:   Runs Profile
 Returns :
 Args    :

=cut

sub run {
  my ($self) = @_;
  my $seq = ($self->feat1);

  $self->throw("Analysis not set") unless $self->analysis->isa("Bio::Pipeline::Analysis");
  my $factory;
  my $db_file = $self->analysis->db_file;
  
  my @params = $self->parse_params($self->analysis->parameters);
  push @params, ("DB"=> $db_file);

  $factory = Bio::Tools::Run::Profile->new(@params);
  
  my $program_file = $self->analysis->program_file;
  $factory->executable($program_file) if $program_file;
  

  my @genes;
  eval {
    @genes = $factory->predict_protein_features($seq);
  };
	$self->throw("Problems running predict_protein_featuers due to $@") if $@;

  $self->output(\@genes);
  
  return \@genes;

}

=head2 output


 Title   :   output
 Usage   :   $self->output($seq)
 Function:   Get/set method for output
 Returns :   
 Args    :   

=cut

sub output{
    my ($self,$gene) = @_;
    if(defined $gene){
      (ref($gene) eq "ARRAY") || $self->throw("Output must be an array reference.");
      $self->{'_gene'} = $gene;
    }
    return @{$self->{'_gene'}};
} 




