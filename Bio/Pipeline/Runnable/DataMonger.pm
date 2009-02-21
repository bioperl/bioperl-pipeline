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

=head1 NAME

Bio::Pipeline::Runnable::DataMonger

=head1 SYNOPSIS

  my $runnable = Bio::Pipeline::Runnable::RunnableSkeleton->new();
  $runnable->analysis($analysis);
  $runnable->run;
  my $output = $runnable->output;


=head1 DESCRIPTION

Bare Bones Runnable for writing you own runnable quickly.  You
probably need to do the following:

1. Naturally, replace all cases of RunnableSkeleton with the name of
   your runnable

2. Create get/set methods for your specified datatypes

3. Write the functionality inside the run routine calling the
   appropriate binary wrapper

=head1 CONTACT

shawnh@fugu-sg.org

=head1 APPENDIX

=cut

package Bio::Pipeline::Runnable::DataMonger;
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

  return $self;

}

sub add_filter {
    my ($self,$filter) = @_;
    $filter || $self->throw("Adding filter without providing one");
    $filter->isa("Bio::Pipeline::Filter") || $self->throw("Not a Bio::Pipeline::Filter object");
    push (@{$self->{'_filter'}},$filter);
}

sub filters {
    my ($self) = @_;
    if(ref($self->{'_filter'}) eq "ARRAY"){
      return @{$self->{'_filter'}};
    }
    else {
        return;
    }
}

sub next_analysis {
    my ($self,$anal) = @_;
    if($anal){
        $self->{'_next_analysis'} = $anal;
    }
    return $self->{'_next_analysis'};
}

sub add_input_create {
    my ($self,$input_create) = @_;
    $input_create|| $self->throw("Adding input_create without providing one");
    $input_create->isa("Bio::Pipeline::InputCreate") || $self->throw("Not a Bio::Pipeline::InputCreate object");
    push (@{$self->{'_input_create'}},$input_create);
}

sub input_creates {
    my ($self) = @_;

    return @{$self->{'_input_create'}};
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

  if($self->filters){
    my @filters = $self->filters;  
    return $filters[0]->datatypes;
  }
  elsif($self->input_creates){
    my @inc = $self->input_creates;
    return $inc[0]->datatypes;
  } 

}

=head2 input 

 Title   :   input 
 Usage   :   $self->input ()
 Function:   get/set for input 
 Returns :
 Args    : 

=cut

sub input {
  my ($self,$input) = @_;
  if($input){
    $self->{'_input'} = $input;
  }
  return $self->{'_input'};
}

sub rule_group_id {
  my ($self,$rule_group_id) = @_;
  if($rule_group_id){
    $self->{'_rule_group_id'} = $rule_group_id;
  }
  return $self->{'_rule_group_id'};
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
  my ($input,$infile);
  if($self->input){
      $input = $self->input;
  }
  elsif($self->infile){
      ($infile) = values(%{$self->infile});
  }
  else {}

  if ($self->filters){
      foreach my $filter ($self->filters){
        $input = $filter->run($input);
      }
  }

  #Input creates should not return any outputs
  if($self->input_creates){
    foreach my $inc ($self->input_creates){
      $inc->rule_group_id($self->rule_group_id);
      $inc->run($self->next_analysis,$input) if $input;
      $inc->infile($infile) if $infile;
      $inc->run($self->next_analysis) if $infile;
    }
    return;
  }
  $self->output($input);
  return $input;

}

1;
