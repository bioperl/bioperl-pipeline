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
# Bio::Pipeline::Runnable::DataMonger
#
=head1 SYNOPSIS
Bare Bones Runnable for writing you own runnable quickly. 
You probably need to do the following:

1. Naturally, replace all cases of RunnableSkeleton with the name of your runnable
2. Create get/set methods for your specified datatypes
3. Write the functionality inside the run routine calling the appropriate binary wrapper

=head1 DESCRIPTION

my $runnable = Bio::Pipeline::Runnable::RunnableSkeleton->new();
$runnable->analysis($analysis);
$runnable->run;
my $output = $runnable->output;

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

    return @{$self->{'_filter'}};
}

sub converter {
    my ($self,$converter ) = @_;

    if($converter){
      $converter->isa("Bio::SeqFeatureI") || $self->throw("Not a Bio::SeqFeatureI object ");
      $self->{'_converter'} = $converter;
    }

    return $self->{'_converter'};
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
  elsif($self->converter) {
    return $self->converter->datatypes;
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

=head2 run

Title   :   run
Usage   :   $self->run()
Function:   execute 
Returns :   
Args    :

=cut

sub run {
  my ($self) = @_;

  my $input = $self->input;
  my @output= @{$input};

  if ($self->filters){
      foreach my $filter ($self->filters){
        @output = $filter->run(@output);
      }
      #   @output = $self->filter->run(@output);
  }
  if ($self->converter){
    @output = $self->converter->run(@output);
  }

  #Input creates should not return any outputs
  if($self->input_creates){
    foreach my $inc ($self->input_creates){
      $inc->run($self->next_analysis,@output);
    }
    return;
  }
  $self->output(\@output);
  return \@output;

}

1;
