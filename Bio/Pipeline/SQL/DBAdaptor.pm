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

use Bio::Pipeline::SQL::IOHandlerAdaptor;
use Bio::Pipeline::SQL::RuleAdaptor;
use Bio::Pipeline::SQL::BaseAdaptor;
use Bio::Pipeline::SQL::AnalysisAdaptor;
use Bio::Pipeline::SQL::JobAdaptor;
use Bio::Pipeline::SQL::NodeAdaptor;
use Bio::Pipeline::SQL::NodeGroupAdaptor;
use Bio::Root::Root;

# Inherits from the base bioperl object

@ISA = qw(Bio::Root::Root);


sub new {
  my($pkg, @args) = @_;

  my $self = bless {}, $pkg;

    my (
        $db,
        $host,
        $driver,
        $user,
        $password,
        $port,
        ) = $self->_rearrange([qw(
            DBNAME
            HOST
            DRIVER
            USER
            PASS
            PORT
            )],@args);
    $db   || $self->throw("Database object must have a database name");
    $user || $self->throw("Database object must have a user");

    if( ! $driver ) {
        $driver = 'mysql';
    }
    if( ! $host ) {
        $host = 'localhost';
    }
    if ( ! $port ) {
        $port = '';
    }

    my $dsn = "DBI:$driver:database=$db;host=$host;port=$port";

  my $dbh = DBI->connect("$dsn","$user",$password, {RaiseError => 1});

  $dbh || $self->throw("Could not connect to database $db user $user using [$dsn] as a locator");

  $self->_db_handle($dbh);
  $self->username( $user );
  $self->host( $host );
  $self->dbname( $db );
  $self->port($port);

  return $self; # success - we hope!
}

sub dbname {
  my ($self, $arg ) = @_;
  ( defined $arg ) &&
    ( $self->{_dbname} = $arg );
  $self->{_dbname};
}

sub port {
    my ($self,$port) = @_;
    (defined $port ) && ($self->{_port} = $port);
    return $self->{_port};
}

sub username {
  my ($self, $arg ) = @_;
  ( defined $arg ) &&
    ( $self->{_username} = $arg );
  $self->{_username};
}

sub host {
  my ($self, $arg ) = @_;
  ( defined $arg ) &&
    ( $self->{_host} = $arg );
  $self->{_host};
}

=head2 prepare

 Title   : prepare
 Usage   : $sth = $dbobj->prepare("select seq_start,seq_end from feature where analysis = \" \" ");
 Function: prepares a SQL statement on the DBI handle
 Example :
 Returns : A DBI statement handle object
 Args    : a SQL string


=cut

sub prepare {
   my ($self,$string) = @_;

   if( ! $string ) {
       $self->throw("Attempting to prepare an empty SQL query!");
   }
   if( !defined $self->_db_handle ) {
      $self->throw("Database object has lost its database handle! getting otta here!");
   }
   return $self->_db_handle->prepare($string);
}

=head2 get_JobAdaptor

 Title   : get_JobAdaptor
 Usage   : $db->get_JobAdaptor
 Function: The Adaptor for Job objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::JobAdaptor
 Args    : nothing

=cut


sub get_JobAdaptor {
  my ($self) = @_;

  if( ! defined $self->{_JobAdaptor} ) {
    $self->{_JobAdaptor} = Bio::Pipeline::SQL::JobAdaptor->new
      ( $self );
  }

  return $self->{_JobAdaptor};
}

=head2 get_IOHandlerAdaptor

 Title   : get_IOHandlerAdaptor
 Usage   : $db->get_IOHandlerAdaptor
 Function: The Adaptor for getting input/output handler objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::IOHandlerAdaptor
 Args    : nothing


=cut

sub get_IOHandlerAdaptor{
  my ($self) = @_;

  if( ! defined $self->{_IOHandlerAdaptor} ) {
    $self->{_IOHandlerAdaptor} = Bio::Pipeline::SQL::IOHandlerAdaptor->new
      ( $self );
  }

  return $self->{_IOHandlerAdaptor};
}


=head2 get_InputAdaptor

 Title   : get_InputAdaptor
 Usage   : $db->get_InputAdaptor
 Function: The Adaptor for Input objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::InputAdaptor
 Args    : nothing

=cut

sub get_InputAdaptor {
  my ($self) = @_;

  if( ! defined $self->{_InputAdaptor} ) {
    require Bio::Pipeline::SQL::InputAdaptor;
    $self->{_InputAdaptor} = Bio::Pipeline::SQL::InputAdaptor->new
      ( $self );
  }
  return $self->{_InputAdaptor};
}

=head2 get_AnalysisAdaptor

 Title   : get_AnalysisAdaptor
 Usage   : $db->get_AnalysisAdaptor
 Function: The Adaptor for Analysis objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::AnalysisAdaptor
 Args    : nothing

=cut

sub get_AnalysisAdaptor {
  my ($self) = @_;

  if( ! defined $self->{_AnalysisAdaptor} ) {
    require Bio::Pipeline::SQL::AnalysisAdaptor;
    $self->{_AnalysisAdaptor} = Bio::Pipeline::SQL::AnalysisAdaptor->new
      ( $self );
  }

  return $self->{_AnalysisAdaptor};
}


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

sub delete_Job {
    my ($self,$id) = @_;

    $self->warn(q/You really should use "$job->remove" :)/);

    $self->get_JobAdaptor->fetch_by_dbID($id)->remove
     or $self->warn("Can't recreate job with ID $id");
}

=head2 get_NodeAdaptor
 Title   : get_NodeAdaptor
 Usage   : $db->get_NodeAdaptor
 Function: The Adaptor for Node objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::NodeAdaptor
 Args    : nothing

=cut

sub get_NodeAdaptor {
  my ($self) = @_;

  if( ! defined $self->{_NodeAdaptor} ) {
    $self->{_NodeAdaptor} = Bio::Pipeline::SQL::NodeAdaptor->new
      ( $self );
  }

  return $self->{_NodeAdaptor};
}

=head2 get_NodeGroupAdaptor
 Title   : get_NodeGroupAdaptor
 Usage   : $db->get_NodeGroupAdaptor
 Function: The Adaptor for NodeGroup objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::NodeGroupAdaptor
 Args    : nothing

=cut

sub get_NodeGroupAdaptor {
  my ($self) = @_;

  if( ! defined $self->{_NodeGroupAdaptor} ) {
    $self->{_NodeGroupAdaptor} = Bio::Pipeline::SQL::NodeGroupAdaptor->new
      ( $self );
  }

  return $self->{_NodeGroupAdaptor};
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

   #$obj->_unlock_tables();

   if( $obj->{'_db_handle'} ) {
       $obj->{'_db_handle'}->disconnect;
       $obj->{'_db_handle'} = undef;
   }
}
