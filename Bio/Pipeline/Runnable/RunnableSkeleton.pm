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

package Bio::Pipeline::Runnable::RunnableSkeleton;
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

=head2 datatypes

 Title   :   datatypes
 Usage   :   $self->datatypes()
 Function:   returns a hash of the datatypes required by the runnable
 Returns :
 Args    :

=cut

sub datatypes {
  my ($self) = @_;
  my $dt = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SeqI',
                                        '-name'=>'sequence',
                                        '-reftype'=>'SCALAR');
  my $dtb = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SimpleAlign',
                                         '-name'=>'alignment',
                                         '-reftype'=>'ARRAY');

  my $dtc = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SimpleAlign',
                                         '-name'=>'alignment',
                                         '-reftype'=>'SCALAR');


  my %dts;
  #Replace seq1 with whatever you want to call your get/set methods
  $dts{seq1} = $dt;
  #You can add more that one datatype.
  #You can also store an array of datatypes in one hash element which 
  #emulates a OR functionality when datatype checking is done

  $dts{align} = [];
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
  #Whatever you want to do here
}

=head2 parse_results

 Title   :   parse_results
 Usage   :   $self->parse_results()
 Function:   whatever additional parsing that needs to be done 
 Returns :
 Args    :

=cut

sub parse_results {
  my ($self) = @_;
  #Whatever you want to do here
}

1;
