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
# Bio::Pipeline::Runnable::Primate
#
=head1 SYNOPSIS

=head1 DESCRIPTION

my $runnable = Bio::Pipeline::Runnable::Primate->new();
$runnable->analysis($analysis);
$runnable->search;
my $output = $runnable->output;

=head1 CONTACT

shawnh@fugu-sg.org

=head1 APPENDIX

=cut
package Bio::Pipeline::Runnable::Primate;
use vars qw(@ISA);
use strict;
use Bio::Root::Root;
use Bio::Pipeline::DataType;
use Bio::Pipeline::RunnableI;
use Bio::Tools::Run::Primate;

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
  $dts{seq} = $dt;

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
  $self->analysisi->isa("Bio::Pipeline::Analysis") || $self->throw("Need an analysis object");
  my $target = $self->target || $self->throw("Need a target sequence to run primate");
  my $query = $self->analysis->db_file || $self->throw("Need a db file or primer tags");
  (-e $query) || $self->throw("Query file doesn't seem to exist");
 
  my $param_str = $self->analysis->parameters;

  $param_str .= " -q $query -t $target";
  my @params = $self->parse_params($param_str);

  my $factory = Bio::Tools::Run::Primate->new(@params);

  my @feats = $factory->search;

  $self->output(\@feats);

  return \@feats;
  
}


1;
