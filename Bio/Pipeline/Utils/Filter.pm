#
# BioPerl module for Bio::Pipeline::Filter
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME
Bio::Pipeline::Filter 
Filter object used for filtering various features.
Part of DataMonger Object.


=head1 SYNOPSIS

=head1 DESCRIPTION

Filter object plugged into DataMonger to be carried out between analysis.
List of filter modules may be found in Bio::Pipeline::Filter::*


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
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut


package Bio::Pipeline::Filter;
use vars qw(@ISA);
use strict;
use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);


=head2 new

  Title   : new
  Usage   : my $filter = Bio::Pipeline::Filter->new('-module'=>$module,'-rank'=>$rank);
  Function: constructor for filter object 
  Returns : a new Filter object 
  Args    : module, the list of filter modules found in Bio::Pipeline::Filter::*
            The rank specifies the order in which to apply the filter in relation to others

=cut

sub new {
    my ($caller ,@args) = @_;
     my $class = ref($caller) || $caller;

    # or do we want to call SUPER on an object if $caller is an
    # object?
    if( $class =~ /Bio::Pipeline::Filter::(\S+)/ ) {
      my ($self) = $class->SUPER::new(@args);
      $self->_initialize(@args);
      return $self;
    }
    else {
      my %param = @args;
      @param{ map { lc $_ } keys %param } = values %param; # lowercase keys
      my $module= $param{'-module'};
      $module || Bio::Root::Root->throw("Must you must provided a filter module found in Bio::Pipeline::Filter::*");

      $module = "\L$module";  # normalize capitalization to lower case
      return undef unless ($class->_load_filter_module($module));
      return "Bio::Pipeline::Filter::$module"->new(@args);
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
    $module = "Bio::Pipeline::Filter::" . $module;
    my $ok;

    eval {
      $ok = $self->_load_module($module);
    };
    if ($@) {
    print STDERR <<END;
$self: $module cannot be found
Exception $@
For more information about the Bio::Pipeline::Filter system please see the pipeline docs 
This includes ways of checking for formats at compile time, not run time
END
  ;
  }
  return $ok;
}

=head2 datatypes

  Title   : datatypes
  Usage   : $self->datatypes();
  Function: abstract method for returing the datatypes required by Filter object 
  Returns : 
  Args    : 

=cut

sub datatypes {
  my ($self) = @_;
  $self->throw_not_implemented();
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

=head2 threshold

  Title   : threshold
  Usage   : $self->threshold();
  Function: get set for filter threshold (not used currently) 
  Returns :
  Args    :

=cut

sub threshold {
  my ($self,$threshold) = @_;

  if($threshold){
    $self->{'_threshold'} = $threshold;
  }
  return $self->{'_threshold'};
}
  

1;
