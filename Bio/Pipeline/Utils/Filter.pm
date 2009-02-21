#
# BioPerl module for Bio::Pipeline::Utils::Filter
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

Bio::Pipeline::Utils::Filter 

=head1 SYNOPSIS

  use Bio::Pipeline::Utils::Filter;
  my $filter = Bio::Pipeline::Utils::Filter->new('-module'=>$module);
  my @filtered = $filter->run(@inputs)

=head1 DESCRIPTION

Filter object plugged into DataMonger to be carried out between analysis.
List of filter modules may be found in Bio::Pipeline::Utils::Filter::*
Filters do not modify the objects, only returns a subset of the objects

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

package Bio::Pipeline::Utils::Filter;
use vars qw(@ISA);
use strict;
use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);


=head2 new

  Title   : new
  Usage   : my $filter = Bio::Pipeline::Utils::Filter->new('-module'=>$module);
  Function: constructor for filter object 
  Returns : a new Filter object 
  Args    : module, the list of filter modules found in Bio::Pipeline::Utils::Filter::*

=cut

sub new {
    my ($caller ,@args) = @_;
     my $class = ref($caller) || $caller;

    # or do we want to call SUPER on an object if $caller is an
    # object?
    if( $class =~ /Bio::Pipeline::Utils::Filter::(\S+)/ ) {
      my ($self) = $class->SUPER::new(@args);
      $self->_initialize(@args);
      return $self;
    }
    else {
      my %param = @args;
      @param{ map { lc $_ } keys %param } = values %param; # lowercase keys
      my $module= $param{'-module'};
      $module || Bio::Root::Root->throw("Must you must provided a filter module found in Bio::Pipeline::Utils::Filter::*");

      $module = "\L$module";  # normalize capitalization to lower case
      return undef unless ($class->_load_filter_module($module));
      my ($self) =  "Bio::Pipeline::Utils::Filter::$module"->new(@args);
      $self->module($module);
      return $self;
    }
}

sub _initialize {
  my ($self) = @_;
  #do nothing for now
  return;
}

=head2 _load_filter_module

  Title   : new
  Usage   : $self->_load_filter_module('setup_genewise'); 
  Function: creates the specific filter module 
  Returns : a new Filter object
  Args    : the module name 

=cut

sub _load_filter_module {
    my ($self, $module) = @_;
    $module = "Bio::Pipeline::Utils::Filter::" . $module;
    my $ok;

    eval {
      $ok = $self->_load_module($module);
    };
    if ($@) {
    print STDERR <<END;
$self: $module cannot be found
Exception $@
For more information about the Bio::Pipeline::Utils::Filter system please see the pipeline docs 
This includes ways of checking for formats at compile time, not run time
END
  ;
  }
  return $ok;
}

=head2 run

  Title   : run
  Usage   : $self->run();
  Function: abstract method for running the filter 
  Returns :
  Args    :

=cut

sub run {
  my ($self) = @_;
  $self->throw_not_implemented();
}

=head2 module

  Title   : module
  Usage   : $inc->module
  Function: get set method for the filter  module to use 
  Returns :
  Args    :

=cut

sub module {
  my ($self,$module) = @_;

  if($module){
    $self->{'_module'} = $module;
  }
  return $self->{'_module'};
}

=head2 threshold

  Title   : threshold
  Usage   : $self->threshold();
  Function: get set for filter threshold 
  Returns : some value 
  Args    : some value

=cut

sub threshold {
  my ($self,$threshold) = @_;

  if($threshold){
    $self->{'_threshold'} = $threshold;
  }
  return $self->{'_threshold'};
}

=head2 in_datatype

  Title   : in_datatype
  Usage   : $self->in_datatype();
  Function: get set for filter input data type
  Returns : Bio::Pipeline::DataType
  Args    : some value

=cut

sub in_datatype {
  my ($self) = @_;
  $self->throw_not_implemented();
}


=head2 out_datatype

  Title   : out_datatype
  Usage   : $self->out_datatype();
  Function: get set for filter output data type
  Returns : Bio::Pipeline::DataType 
  Args    : some value

=cut

sub out_datatype {
  my ($self) = @_;
  $self->throw_not_implemented();
}
  

1;
