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
# Bio::Pipeline::Runnable::TribeMCL
#

=head1 SYNOPSIS


  my $runnable = Bio::Pipeline::Runnable::TribeMCL->new();
  $runnable->analysis($analysis);
  $runnable->run;
  my $output = $runnable->output;

=head1 DESCRIPTION

Runnable for TribeMCL that takes in an array of protein blast scores
runs the TribeMCL wrapper.

=head1 CONTACT

shawnh@fugu-sg.org

=head1 APPENDIX

=cut

package Bio::Pipeline::Runnable::TribeMCL;
use vars qw(@ISA);
use strict;

use Bio::Pipeline::DataType;
use Bio::Tools::Run::TribeMCL;
use Bio::Pipeline::RunnableI;
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
  my ($blastdir) = $self->_rearrange([qw(BLASTDIR)],@args);

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
  my $dt = Bio::Pipeline::DataType->new('-match'=>0);

  my %dts;

  $dts{datatypes} = $dt;
  return %dts;

}

=head2 blastdir 

 Title   :   blastdir 
 Usage   :   $self->blastdir()
 Function:   get/set for blast directory 
 Returns :   
 Args    :

=cut

sub blastdir {
    my ($self,$val) = @_;
    if($val){
        $self->{'_blastdir'} = $val;
    }
    return $self->{'_blastdir'};
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
  my $err;
  my $analysis = $self->analysis;
  $self->throw("Analysis not set") unless $self->analysis->isa("Bio::Pipeline::Analysis");
  my $factory;
  my $file;
  my @params = $self->parse_params($analysis->analysis_parameters);
  my $blastdir = $self->blastdir  || $self->throw("Need the location of the blast directory");
  $file = $blastdir."/blast_out.".time().rand(1000);
  system("echo $blastdir/* | xargs cat > $file");
  push @params, ("scorefile"=>$file);

  $factory = Bio::Tools::Run::TribeMCL->new(@params);
  $factory->executable($analysis->program_file) if $analysis->program_file;


  my @clusters;
  eval {
      @clusters = $factory->run();
  };
  unlink $file;
  if($err = $@){
      $self->throw("Problems running TribeMCL for \n[$err]\n");
  }
  $self->output(\@clusters);
  return $self->output; 

}
