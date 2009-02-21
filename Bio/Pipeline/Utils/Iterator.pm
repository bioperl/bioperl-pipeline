#
# BioPerl module for Bio::Pipeline::Utils::Iterator
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

Bio::Pipeline::Utils::Iterator 

=head1 SYNOPSIS

  use Bio::Pipeline::Utils::Iterator;
  use Bio::AlignIO;

  my $itr = Bio::Pipeline::Utils::Iterator->new();
  my $aio = Bio::AlignIO->new(-file=>$ARGV[0],-format=>"phylip");

  my $obj = $itr->run($aio); #$obj is a array ref of Bio::SimpleAlign


=head1 DESCRIPTION

Iterator module plugged into a transformer allows fetching of all Iterator
type objects at once to be passed to the runnable. This allows one
to make use of the set of IO type modules like:

  Bio::AlignIO
  Bio::SeqIO
  Bio::MapIO
  Bio::SearchIO
  Bio::ClusterIO
  Bio::TreeIO


=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-pipeline@bioperl.org          - General discussion
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

# Let the code begin...

package Bio::Pipeline::Utils::Iterator;
use vars qw(@ISA);
use strict;
use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);

my %method = ("Bio::AlignIO" =>"next_aln",
              "Bio::SeqIO"   => "next_seq",
              "Bio::MapIO"   =>"next_map",
              "Bio::SearchIO"=>"next_result",
              "Bio::ClusterIO"=>"next_cluster",
              "Bio::TreeIO"  => "next_tree");

=head2 new

  Title   : new
  Usage   : my $Iterator = Bio::Pipeline::Utils::Iterator->new('-module'=>$module);
  Function: constructor for Iterator object 
  Returns : a new Iterator object 
  Args    : module, the list of Iterator modules found in Bio::Pipeline::Utils::Iterator::*

=cut

sub new {
    my ($caller ,@args) = @_;
     my $class = ref($caller) || $caller;

      my ($self) = $class->SUPER::new(@args);
      $self->method(\%method);
      return $self;
}

=head2 run

  Title   : run
  Usage   : $self->run();
  Function: abstract method for running the Iterator 
  Returns :
  Args    :

=cut

sub run {
  my ($self,$iterator) = @_;
  my %method = %{$self->method};
  foreach my $key (%method){
    if ($iterator->isa($key)){
      my $itr = $method{$key};
      $iterator->can($itr) || $self->throw("$itr cannot be called on ". ref $iterator);
      my @obj;
      while (my $obj = $iterator->$itr){
        push @obj, $obj;
      }
      return \@obj;
   }
 }

$self->throw (ref $iterator ." is not supported by Bio::Pipeline::Utils::Iterator");
}


=head2 method

  Title   : method
  Usage   : $inc->method
  Function: get set method for the Iterator method to use 
  Returns : a hash of object to method mapping
  Args    : a hash of object to method mapping

=cut

sub method {
  my ($self,$method) = @_;

  if($method){
    $self->{'_method'} = $method;
  }
  return $self->{'_method'};
}

1;
