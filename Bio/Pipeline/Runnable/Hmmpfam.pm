# Pipeline module for Hmmpfam Bio::Pipeline::Runnable::Hmmpfam
#
# Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Protein::Hmmpfam
# originally written by Emmanuel Mongin <mongin@ebi.ac.uk>
# Written in BioPipe by Balamurugan Kumarasamy <savikalpa@fugu-sg.org>
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)

# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code


=head1 NAME

Bio::Pipeline::Runnable::Hmmpfam

=head1 SYNOPSIS

 my $runnable = Bio::Pipeline::Runnable::Hmmpfam->new(@params); 
 $runnable->analysis($analysis);
 $runnable->run;
 my $output = $runnable->output;

=head1 DESCRIPTION

Runnable for Hmmpfam

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to the
Bioperl mailing lists  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via
email or the web:

  bioperl-bugs@bio.perl.org
  http://bugzilla.open-bio.org/

=head1 AUTHOR

 Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Protein::Hmmpfam
 originally written by Emmanuel Mongin <mongin@ebi.ac.uk>
 Written in BioPipe by Balamurugan Kumarasamy <savikalpa@fugu-sg.org>
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
 Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)

=head1 APPENDIX

=cut

package Bio::Pipeline::Runnable::Hmmpfam;
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
use Bio::Tools::Run::Hmmer;

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

 Title   : feat1
 Usage   : $self->feat1($seq)
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
 Function:   Runs Hmmpfam
 Returns :
 Args    :

=cut

sub run {
  my ($self) = @_;
  my $seq = ($self->feat1);

  $self->throw("Analysis not set") unless $self->analysis->isa("Bio::Pipeline::Analysis");
  my $factory;
  my $db_file = $self->analysis->db_file;
  my @params = $self->parse_params($self->analysis->analysis_parameters);
  push @params, ("hmm"=> $db_file,"program"=> 'hmmpfam');
  $factory = Bio::Tools::Run::Hmmer->new(@params);
  my $program_file = $self->analysis->program_file;
  $factory->executable($program_file) if $program_file;

  my $searchio;
  eval {
    $searchio = $factory->run($seq);
  };
	$self->throw("Problems running due to $@") if $@;
  my @feat;
  while(my $result = $searchio->next_result){
    while(my $hit = $result->next_hit){
      while(my $hsp = $hit->next_hsp){
        push @feat,$hsp;
      }
    }
  }

  $self->output(\@feat);
  
  return \@feat;

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




