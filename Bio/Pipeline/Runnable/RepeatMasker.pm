# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
# Copyright Shawn Hoon
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
# =pod
#
# =head1 NAME
#
# Bio::Pipeline::Runnable::RepeatMasker
#
=head1 SYNOPSIS

  my $runnable = Bio::Pipeline::Runnable::RunnableSkeleton->new();
  $runnable->analysis($analysis);
  $runnable->run;
  my $output = $runnable->output;


=head1 DESCRIPTION

Bare Bones Runnable for writing you own runnable quickly. 
You probably need to do the following:

1. Naturally, replace all cases of RunnableSkeleton with the name of your runnable

2. Create get/set methods for your specified datatypes

3. Write the functionality inside the run routine calling the appropriate binary wrapper

=head1 CONTACT

shawnh@fugu-sg.org

=head1 APPENDIX

=cut

package Bio::Pipeline::Runnable::RepeatMasker;
use vars qw(@ISA);
use strict;
use Bio::Root::Root;
use Bio::Pipeline::DataType;
use Bio::Pipeline::RunnableI;
use Bio::Tools::Run::RepeatMasker;

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

=head2 seq

 Title   :   seq 
 Usage   :   $self->seq ()
 Function:   get/set for sequence to mask 
 Returns :
 Args    : 

=cut

sub seq {
  my ($self,$seq) = @_;
  if($seq){
    $self->{'_seq'} = $seq;
  }
  return $self->{'_seq'};
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
  my $params = $self->params;
  my $seq = $self->seq || $self->throw("Need a sequence to run RepeatMasker");
  
  $self->throw("Analysis not set") unless $self->analysis->isa("Bio::Pipeline::Analysis");
  my $factory;
  if($self->analysis->parameters){
    my @params = $self->parse_params($self->analysis->parameters);
    $factory = Bio::Tools::Run::RepeatMasker->new(@params);
  }
  else {
    $factory = Bio::Tools::Run::RepeatMasker->new();
  }
  my @feats;
  eval {
      @feats = $factory->mask($seq);
  };
  $self->output(\@feats);
  return \@feats;
}

1;
