#
# BioPerl module for Bio::Pipeline::InputCreate::setup_initial
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME

Bio::Pipeline::InputCreate::setup_initial

=head1 SYNOPSIS

  use Bio::Pipeline::InputCreate::setup_inital;

 my $inc = Bio::Pipeline::InputCreate::setup_initial->new('-protein_ioh'=>1,
                                                          '-dna_ioh'=>2);
 $inc->run();


=head1 DESCRIPTION

Object used for encapsulating "hacky" processing needed to setup
input and job tables. Pluggable into DataMonger object

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org          - General discussion
  http://bio.perl.org/MailList.html             - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:

  bioperl-bugs@bio.perl.org
  http://bugzilla.bioperl.org/

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

package Bio::Pipeline::InputCreate::setup_initial;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::InputCreate;
use Bio::Pipeline::DataType;

@ISA = qw(Bio::Pipeline::InputCreate);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);
   
    #from here on, assume all parameters are for iohandler mapping
    $#args > 0 || $self->throw("Need iohandlers to setup initial jobs"); 
    my %ioh = @args;
    @ioh{ map { lc $_ } keys %ioh} = values %ioh; # lowercase keys

    $self->iohandler_map(\%ioh);


}

=head2 iohandler_map

  Title   : iohandler_map
  Usage   : $self->iohandler_map()
  Function: get/sets of the iohandler map hash
  Returns :
  Args    :

=cut

sub iohandler_map {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_iohandler_map'} = $arg;
    }
    return $self->{'_iohandler_map'};
}

=head2 datatypes

  Title   : datatypes
  Usage   : $self->datatypes()
  Function: get/sets of the datatypes
  Returns :
  Args    :

=cut

sub datatypes {
    my ($self) = @_;
    my $dt = Bio::Pipeline::DataType->new('-object_type'=>'',
                                          '-name'=>'ids',
                                          '-reftype'=>'ARRAY');

    my %dts;
    $dts{input} = $dt;
    return %dts;
}

=head2 run

  Title   : run
  Usage   : $self->run()
  Function: run the input create
  Returns :
  Args    :

=cut

sub run {
    my ($self,$next_anal,$input) = @_;

    (ref($input) eq "HASH") || $self->throw("Expecting a hash reference");
    my $ioh_map = $self->iohandler_map;

    foreach my $key (keys %{$input}){
#       $key = lc $key;
       my $ioh = $ioh_map->{$key};
       if(!$input->{$key}){
           $self->throw("Iohandler map for $key does not have inputs");
       }
       my @input;
       if(ref $input->{$key} eq "ARRAY"){
        @input = [$key,@{$input->{$key}}];
       }
       else {
        push @input, [$key,$input->{$key}];
       }
       foreach my $in(@input){
        my $input1 = $self->create_input($in->[1],$ioh,$in->[0]);

        my $job = $self->create_job($next_anal,[$input1]);

        $self->dbadaptor->get_JobAdaptor->store($job);
       }
        
    }
        
    
}

1;
    



