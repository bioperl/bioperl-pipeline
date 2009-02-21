# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
# Copyright Shawn Hoon
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
# =pod

=head1 NAME

Bio::Pipeline::Runnable::RunnableSkeleton

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

package Bio::Pipeline::Runnable::Phylip;

use vars qw(@ISA);
use strict;
use Bio::Root::Root;
use Bio::Pipeline::DataType;
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
  my ($program,$input_dir) = $self->_rearrange([qw(PROGRAM INPUTDIR)],@args);
  $program || $self->throw("Need to specify a program");
  $self->program($program);
  $self->input_dir($input_dir) if $input_dir;

  return $self;

}

sub input_dir {
    my ($self,$val) = @_;
    if($val){
        $self->{'_input_dir'} = $val;
    }
    return $self->{'_input_dir'};
}

sub input {
    my ($self,$val) = @_;
    if($val){
        $self->{'_input'} = $val;
    }
    return $self->{'_input'};
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
  my $dta = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SimpleAlign',
                                         '-name'=>'alignment',
                                         '-reftype'=>'ARRAY');

  my $dtb = Bio::Pipeline::DataType->new('-object_type'=>'Bio::Matrix::PhylipDist',
                                         '-name'=>'alignment',
                                         '-reftype'=>'SCALAR');

  my $dtc = Bio::Pipeline::DataType->new('-object_type'=>'Bio::Tree::TreeI',
                                         '-name'=>'alignment',
                                         '-reftype'=>'SCALAR');


  my %dts;
  $dts{input} = [];
  push @{$dts{align}},$dta;
  push @{$dts{align}},$dtb;
  push @{$dts{align}},$dtc;

  return %dts;

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
  my $program = $self->program;
  my $ok;

  my $module = "Bio::Tools::Run::Phylo::Phylip::$program";
  eval{
   $ok = $self->_load_module($module);
  };
  if($@){
      print STDERR <<END;
$self:$module cannot be found.
Exception $@
Problems loading, pls check your PERL5LIB path
END
;
}
  my @params = $self->parse_params($self->analysis->analysis_parameters);
  my $phylip = $module->new(@params);
  my $runner;
  if($program=~/ProtDist/i){
      $runner = "create_distance_matrix";
  }
  elsif($program=~/ProtPars/i || $program=~/Neighbor/i){
      $runner = "create_tree";
  }
  elsif($program=~/SeqBoot/i || $program=~/Consense/i){
      $runner = "run";
  }
  elsif($program=~/DrawTree/i || $program=~/DrawGram/i){
      $runner = "draw_tree";
  }
  else {
      $self->throw("$program currently not supported by  Bio::Pipeline::Runnable::Phylip");
  }
  my $input;
  if($self->input){
      $input  = $self->input;
  }
  elsif($self->infile){
      $input = $self->infile;
  }
  else {
       $self->throw("No input supplied");
  }
  return 0 unless(-e $input);
  my $output; 
  eval {
      $output = $phylip->$runner($input);
  };
  if($@){
    $self->throw("Problems running Phylip program $program: $@");
}
   if(($program=~/DrawTree/i) || ($program=~/DrawGram/i)){ 
       system("cp ". $output ." ". $self->infile.".ps");
       return;
  }

  $self->output($output);

  return;
}

sub _get_suffix {
    my ($self,$program) = @_;
    if($program=~/ProtDist/i || $program=~/SeqBoot/i ||$program=~/ProtPars/i){
        return ".aln";
    }
    elsif($program=~/Neighbor/i){
      return ".matrix";
    }
    elsif($program=~/Consense/i ||$program=~/DrawTree/i || $program=~/DrawGram/i){
      return ".tree"; 
    }
    else {
      $self->throw("$program not supported");
    }
}

1;
