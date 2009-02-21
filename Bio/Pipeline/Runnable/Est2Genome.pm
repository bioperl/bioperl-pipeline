# Pipeline module for Est2Genome Bio::Pipeline::Runnable::Est2Genome
#
# Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Est2Genome
# originally written by Michele Clamp <michele@sanger.ac.uk> 
# Written in BioPipe by Shawn Hoon <shawnh@fugu-sg.org>
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
# =pod
#
# =head1 NAME
#
# Bio::Pipeline::Runnable::Est2Genome
#
=head1 SYNOPSIS

  my $runnable = Bio::Pipeline::Runnable::RunnableSkeleton->new();
  $runnable->analysis($analysis);
  $runnable->run;
  my $output = $runnable->output;


=head1 DESCRIPTION

Bare Bones Runnable for writing you own runnable quickly.  You
probably need to do the following:

=over 3

=item 1

Naturally, replace all cases of RunnableSkeleton with the name of your
runnable

=item 2

Create get/set methods for your specified datatypes

=item 3

Write the functionality inside the run routine calling the appropriate
binary wrapper

=back

=head1 AUTHOR

Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Est2Genome
originally written by Michele Clamp, michele@sanger.ac.uk.
Written in BioPipe by Shawn Hoon, shawnh@fugu-sg.org.
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
Cared for by the Fugu Informatics team, fuguteam@fugu-sg.org.

=head1 APPENDIX

=cut

package Bio::Pipeline::Runnable::Est2Genome;
use vars qw(@ISA);
use strict;
use Bio::Root::Root;
use Bio::Root::IO;
use Bio::Pipeline::DataType;
use Bio::Pipeline::RunnableI;
use Bio::Factory::EMBOSS;
use Bio::Tools::Est2Genome;

@ISA = qw(Bio::Pipeline::RunnableI);

=head2 new

 Title   :   new
 Usage   :   $self->new()
 Function:
 Returns :
 Args    :

=cut

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($return_gene) = $self->_rearrange([qw(RETURN_GENE)],@args);
  $self->return_gene($return_gene) if $return_gene;
  return $self;

}

=head2 datatypes

 Title   :   datatypes
 Usage   :   $self->datatypes()
 Function:   returns a hash of the datatypes required by the runnable
 Returns :
 Args    :

=cut

sub datatypes {
  my ($self) = @_;
  my $dt = Bio::Pipeline::DataType->new('-object_type'=>'Bio::PrimarySeqI',
                                        '-name'=>'sequence',
                                        '-reftype'=>'SCALAR');
  my %dts;
  #Replace seq1 with whatever you want to call your get/set methods
  $dts{seq} = $dt;
  return %dts;

}

=head2 strand

 Title   :   strand 
 Usage   :   $self->strand ()
 Function:   get/set for genomic sequence
 Returns :
 Args    : 

=cut

sub strand{
  my ($self,$strand) = @_;
  if($strand){
    $self->{'_strand'} = $strand;
  }
  return $self->{'_strand'};
}
=head2 genome

 Title   :   genome 
 Usage   :   $self->genome ()
 Function:   get/set for genomic sequence
 Returns :
 Args    : 

=cut

sub genome{
  my ($self,$genome) = @_;
  if($genome){
    $self->{'_genome'} = $genome;
  }
  return $self->{'_genome'};
}

=head2 return_gene

 Title   :   return_gene 
 Usage   :   $self->return_gene ()
 Function:   get/set for return gene
 Returns :
 Args    : 

=cut

sub return_gene{
  my ($self,$return_gene) = @_;
  if($return_gene){
    $self->{'_return_gene'} = $return_gene;
  }
  return $self->{'_return_gene'};
}

=head2 cdna

 Title   :   cdna 
 Usage   :   $self->cdna ()
 Function:   get/set for cdna sequence
 Returns :
 Args    : 

=cut

sub cdna{
  my ($self,$cdna) = @_;
  if($cdna){
    $self->{'_cdna'} = $cdna;
  }
  return $self->{'_cdna'};
}

=head2 run

 Title   :   run
 Usage   :   $self->run()
 Function:   execute 
 Returns :   
 Args    :

=cut

sub run {
  my ($self) = @_;
  my $cdna = $self->cdna || $self->throw("Need a cdna sequence to run Est2Genome");
  my $genome = $self->genome || $self->throw("Need a genomic sequence to run Est2Genome");

  my $analysis = $self->analysis; 
  $self->throw("Analysis not set") unless $self->analysis->isa("Bio::Pipeline::Analysis");
  my $factory = new Bio::Factory::EMBOSS;
  my $est2genome = $factory->program('est2genome');
  my $io = Bio::Root::IO->new(); 
  my $tmpdir = $io->tempdir(CLEANUP=>1);
  my ($tfh,$outfile) = $io->tempfile(-dir=>$tmpdir);

  my @params = ('-est'=>$cdna,'-genome'=>$genome,'-outfile'=>$outfile);
  push @params , $self->parse_params($analysis->analysis_parameters,1);

  eval {
      $est2genome->run({@params});
  };
  if($@){
    $self->throw("Est2Genome Runnable had problems running. $@");
  }

  my $parser = Bio::Tools::Est2Genome->new(-file=>$outfile);
  my @feat;
  while(my $f = $parser->parse_next_gene($self->return_gene)){
    push @feat,$f;
  }
  $self->output(\@feat);
  return @feat;
}

1;
