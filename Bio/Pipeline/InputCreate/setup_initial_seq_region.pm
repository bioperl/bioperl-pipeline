#
# BioPerl module for Bio::Pipeline::InputCreate::setup_initial
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
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

The setup initial analysis takes in an array of ids and iohandler ids
and creates inputs and jobs. Each input to the analysis is an array of
input ids. Each array of input ids are associated with a given
IOHandler. It has two modes of operation.  It may either create one
input per job or multiple inputs per job.

For example in an xml snippet:

  1   <analysis id="1">
  2      <data_monger>
  3        <initial/>
  4       <input>
  5          <name>gene1</name>
  6          <iohandler>1</iohandler>
  7        </input>
  8        <input>
  9          <name>gene2</name>
  10          <iohandler>2</iohandler>
  11       </input>
  12        <input_create>
  13           <module>setup_initial</module>
  14          <rank>1</rank>
  15           <argument>
  16                <tag>group</tag>
  17               <value>1</value>
  18           </argument>
  19           <argument>
  20                <tag>gene2</tag>
  21                <value>4</value>
  22            </argument>
  23           <argument>
  24                <tag>gene1</tag>
  25                <value>3</value>
  26            </argument>
  27         </input_create>
  28     </data_monger>
  29     <input_iohandler id="1"/>
  30     <input_iohandler id="2"/>
  31   </analysis>

This specifies that there are two inputs (line 4-11) to the
InputCreate job that uses the setup_initial module. Each input has its
own iohandler which would return an array of input ids (line 6 and
line 10). For example in this case gene1 may belong to genes from a
human database and gene2 may belong to gene from a fugu database.

Within the input_create arguments (line 12-27), we next specify how to
map the input ids to its corresponding iohandler. In other words,
given the gene input ids, how does one fetch the actual gene object?
So for this case, input ids from gene1 are fetched using iohandler_id
3 (line 25) and input ids from gene2 are fetched using iohandler_id 4
(line 21)

We also specify that the inputs are grouped (line 15-18) meaning that
each pair of inputs ids (assuming that the number of input ids are
equal for gene1 and gene2) are passed to one job. So what you get:

  gene1_id-> fetched using iohandler id 3 ----> a single job of the next analysis
  gene2_id-> fetched using iohandler id 4

If the group argument is not specified, the jobs are created as such:

  gene1_id-> fetched using iohandler id 3 ---->  a job of the next analysis
  gene2_id-> fetched using iohandler id 4 ---->  a job of the next analysis

Currently it is assumed that the inputs are mapped based on object
type to the inputs of the runnables.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:

  bioperl-bugs@bio.perl.org
  http://bugzilla.open-bio.org/

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

package Bio::Pipeline::InputCreate::setup_initial_seq_region;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::InputCreate;
use Bio::Pipeline::DataType;

@ISA = qw(Bio::Pipeline::InputCreate);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);
    my ($group,$test) = $self->_rearrange([qw(GROUP TEST)],@args);
    $self->group($group) if $group;
    $self->test($test) if $test;

    #from here on, assume all parameters are for iohandler mapping
    $#args > 0 || $self->throw("Need iohandlers to setup initial jobs"); 
    my %ioh = @args;


    @ioh{ map { lc $_} keys %ioh} = values %ioh; # lowercase keys

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

=head2 test

  Title   : test
  Usage   : $self->test()
  Function: get/set from test argument 
  Returns :
  Args    :

=cut

sub test {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_test'} = $arg;
    }
    return $self->{'_test'};
}

=head2 group

  Title   : group
  Usage   : $self->group()
  Function: get/set from group argument 
  Returns :
  Args    :

=cut

sub group {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_group'} = $arg;
    }
    return $self->{'_group'};
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
    if($self->group){
        $self->_create_by_group($next_anal,$input,$ioh_map);
    }
    else {
        $self->_create_single($next_anal,$input,$ioh_map);
    }
}

sub _create_single {
    my ($self,$next_anal,$input,$ioh_map) = @_;
    my $count = 1;
    foreach my $key (keys %{$input}){
       my $ioh = $ioh_map->{$key};
       if(!$input->{$key}){
           $self->throw("Iohandler map for $key does not have inputs");
       }
       my @input;
       if(ref $input->{$key} eq "ARRAY"){
        @input = @{$input->{$key}};
       }
       else {
        push @input, $input->{$key};
       }
       foreach my $in(@input){
       	my $in2 = $in->dbID;

        my $input1 = $self->create_input($in2,$ioh);

        my $job = $self->create_job($next_anal,[$input1]);

        $self->dbadaptor->get_JobAdaptor->store($job);
        if($self->test()){
            last if ($count == $self->test);
        }
        $count++;
       }
    }
}

sub _create_by_group {
      my ($self,$next_anal,$input,$ioh_map) = @_;
      my ($first_key) = keys %$input;
      my $count = 1;
      for my $i(0..scalar(@{$input->{$first_key}})){
          my @input;
          foreach my $key(keys %{$input}){
            my $ioh = $ioh_map->{$key};
            my $in = $input->{$key}->[$i];
            push @input,$self->create_input($in,$ioh);
          }
          my $job = $self->create_job($next_anal,\@input);
          $self->dbadaptor->get_JobAdaptor->store($job);
          if($self->test()){
              last if ($count == $self->test);
          }
          $count++;
      }
}

1;
