# Pipeline module for Sim4 Bio::Pipeline::Runnable::Sim4
#
# Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Sim4
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
# Bio::Pipeline::Runnable::Sim4
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

=item 1.

Naturally, replace all cases of RunnableSkeleton with the name of your
runnable

=item 2.

Create get/set methods for your specified datatypes

=item 3.

Write the functionality inside the run routine calling the appropriate
binary wrapper

=back

=head1 AUTHOR

Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::Runnable::Sim4
Originally written by Michele Clamp, michele@sanger.ac.uk.
Written in BioPipe by Shawn Hoon, shawnh@fugu-sg.org.
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
Cared for by the Fugu Informatics team, fuguteam@fugu-sg.org.

=head1 APPENDIX

=cut

package Bio::Pipeline::Runnable::Sim4;
use vars qw(@ISA);
use strict;
use Bio::Root::Root;
use Bio::Root::IO;
use Bio::Pipeline::DataType;
use Bio::Pipeline::RunnableI;
use Bio::Tools::Run::Alignment::Sim4;

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
  my $cdna = $self->cdna || $self->throw("Need a cdna sequence to run Sim4");
  my $genome = $self->genome || $self->throw("Need a genomic sequence to run Sim4");

  my $analysis = $self->analysis; 
  $self->throw("Analysis not set") unless $self->analysis->isa("Bio::Pipeline::Analysis");
  my $io = Bio::Root::IO->new(); 
  my $tmpdir = $io->tempdir(CLEANUP=>1);
  my ($tfh,$outfile) = $io->tempfile(-dir=>$tmpdir);

  my @params = ('cdna_seq'=>$cdna,'genomic_seq'=>$genome);
  push @params , $self->parse_params($analysis->analysis_parameters);
  my $factory = new Bio::Tools::Run::Alignment::Sim4(@params);

  my @exons;
  eval {
      @exons = $factory->align();
  };
  if($@){
    $self->throw("Sim4 Runnable had problems running. $@");
  }

  $self->output(\@exons);
  return @exons;
}

1;
