#
# Object for storing the connection to the analysis database
#
# Written by Simon Potter <scp@sanger.ac.uk>
# Based on Michele Clamp's Bio::Pipeline::SQL::Obj
#
# Copyright GRL/EBI
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code


=pod

=head1 NAME

Bio::Pipeline::SQL::DBAdaptor -
adapter class for EnsEMBL Pipeline DB

=head1 SYNOPSIS

    my $dbobj = new Bio::Pipeline::SQL::DBAdaptor;
    $dbobj->do_funky_db_stuff;

=head1 DESCRIPTION

Interface for the connection to the analysis database

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...

package Bio::Pipeline::SQL::DBAdaptor;


use vars qw(@ISA);
use strict;
use DBI;

use Bio::DB::SQL::DBAdaptor;
use Bio::Pipeline::SQL::InputDBAAdaptor;
use Bio::Pipeline::SQL::OutputDBAAdaptor;
use Bio::Pipeline::SQL::RuleAdaptor;
=head
use Bio::Pipeline::SQL::AnalysisAdaptor;
use Bio::Pipeline::SQL::JobAdaptor;
use Bio::Pipeline::SQL::StateInfoContainer;
=cut
use Bio::Root::Root;

# Inherits from the base bioperl object

@ISA = qw(Bio::DB::SQL::DBAdaptor);


# sub new {
    # my ($class,@args) = @_;
    # my $self = $class->SUPER::new(@args);
    # return $self;
# }

# new() inherited from Bio::DB::SQL::DBAdaptor;


=head2 get_JobAdaptor

 Title   : get_JobAdaptor
 Usage   : $db->get_JobAdaptor
 Function: The Adaptor for Job objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::JobAdaptor
 Args    : nothing



sub get_JobAdaptor {
  my ($self) = @_;

  if( ! defined $self->{_JobAdaptor} ) {
    $self->{_JobAdaptor} = Bio::Pipeline::SQL::JobAdaptor->new
      ( $self );
  }

  return $self->{_JobAdaptor};
}

=cut
=head2 get_input_dba_adaptor

 Title   : get_input_dba_adaptor
 Usage   : $db->get_input_dba_adaptor
 Function: The Adaptor for getting input adaptor objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::InputDBAAdaptor
 Args    : nothing


=cut

sub get_input_dba_adaptor{
  my ($self) = @_;

  if( ! defined $self->{_InputDBAdaptor} ) {
    $self->{_InputDBAdaptor} = Bio::Pipeline::SQL::InputDBAAdaptor->new
      ( $self );
  }

  return $self->{_InputDBAdaptor};
}

=head2 get_output_dba_adaptor

 Title   : get_output_dba_adaptor
 Usage   : $db->get_output_dba_adaptor
 Function: The Adaptor for getting output adaptor objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::OutputDBAAdaptor
 Args    : nothing


=cut

sub get_output_dba_adaptor{
  my ($self) = @_;

  if( ! defined $self->{_OutputDBAdaptor} ) {
    $self->{_OutputDBAdaptor} = Bio::Pipeline::SQL::OutputDBAAdaptor->new
      ( $self );
  }

  return $self->{_OutputDBAdaptor};
}

=head2 get_AnalysisAdaptor

 Title   : get_AnalysisAdaptor
 Usage   : $db->get_AnalysisAdaptor
 Function: The Adaptor for Analysis objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::AnalysisAdaptor
 Args    : nothing


sub get_AnalysisAdaptor {
  my ($self) = @_;

  if( ! defined $self->{_AnalysisAdaptor} ) {
    require Bio::Pipeline::SQL::AnalysisAdaptor;
    $self->{_AnalysisAdaptor} = Bio::Pipeline::SQL::AnalysisAdaptor->new
      ( $self );
  }

  return $self->{_AnalysisAdaptor};
}

=cut

=head2 get_RuleAdaptor

 Title   : get_RuleAdaptor
 Usage   : $db->get_RuleAdaptor
 Function: The Adaptor for Rule objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::RuleAdaptor
 Args    : nothing

=cut

sub get_RuleAdaptor {
  my ($self) = @_;

  if( ! defined $self->{_RuleAdaptor} ) {
    $self->{_RuleAdaptor} = Bio::Pipeline::SQL::RuleAdaptor->new
      ( $self );
  }

  return $self->{_RuleAdaptor};
}


=head2 get_StateInfoContainer

 Title   : get_StateInfoContainer
 Usage   : $db->get_StateInfoContainer
 Function:
 Example :
 Returns : Bio::Pipeline::SQL::StateInfoContainer
 Args    : nothing


sub get_StateInfoContainer {
  my ($self) = @_;

  if( ! defined $self->{_StateInfoContainer} ) {
    $self->{_StateInfoContainer} = Bio::Pipeline::SQL::StateInfoContainer->new
      ( $self );
  }

  return $self->{_StateInfoContainer};
}

=cut

sub delete_Job {
    my ($self,$id) = @_;

    $self->warn(q/You really should use "$job->remove" :)/);

    $self->get_JobAdaptor->fetch_by_dbID($id)->remove
     or $self->warn("Can't recreate job with ID $id");
}


=head2 _db_handle

 Title   : _db_handle
 Usage   : $sth = $dbobj->_db_handle($dbh);
 Function: Get/set method for the database handle
 Example :
 Returns : A database handle object
 Args    : A database handle object

=cut

sub _db_handle {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_db_handle} = $arg;
    }
    return $self->{_db_handle};
}


=head2 _lock_tables

 Title   : _lock_tables
 Usage   :
 Function:
 Example :
 Returns :
 Args    :

=cut

sub _lock_tables{
   my ($self,@tables) = @_;

   my $state;
   foreach my $table ( @tables ) {
       if( $self->{'_lock_table_hash'}->{$table} == 1 ) {
	   $self->warn("$table already locked. Relock request ignored");
       } else {
	   if( $state ) { $state .= ","; }
	   $state .= "$table write";
	   $self->{'_lock_table_hash'}->{$table} = 1;
       }
   }

   my $sth = $self->prepare("lock tables $state");
   my $rv = $sth->execute();
   $self->throw("Failed to lock tables $state") unless $rv;

}


=head2 _unlock_tables

 Title   : _unlock_tables
 Usage   :
 Function:
 Example :
 Returns :
 Args    :

=cut

sub _unlock_tables{
   my ($self,@tables) = @_;

   my $sth = $self->prepare("unlock tables");
   my $rv  = $sth->execute();
   $self->throw("Failed to unlock tables") unless $rv;
   %{$self->{'_lock_table_hash'}} = ();
}


=head2
 Title   : DESTROY
 Usage   :
 Function:
 Example :
 Returns :
 Args    :

=cut

sub DESTROY {
   my ($obj) = @_;

   $obj->_unlock_tables();

   if( $obj->{'_db_handle'} ) {
       $obj->{'_db_handle'}->disconnect;
       $obj->{'_db_handle'} = undef;
   }
}