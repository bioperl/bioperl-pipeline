# $Id$

# POD documentation - main docs before the code

=head1 NAME

Bio::DB::SQL::DBAdapter - Object representing an instance of a bioperl database

=head1 SYNOPSIS

    $db = Bio::DB::SQL::DBAdaptor->new(
        -user   => 'root',
        -dbname => 'pog',
        -host   => 'caldy',
        -driver => 'mysql',
	    );


=head1 DESCRIPTION

This object represents a database that is implemented somehow (you
shouldn\'t care much as long as you can get the object). From the
object you can pull out other adapters, such as the BioSeqAdapter,


=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package SQL::DBAdaptor;

use vars qw(@ISA);
use strict;

use Bio::Root::Root;
use Bio::DB::SQL::PrimarySeqAdaptor;
use SQL::SeqFeatureAdaptor;

use DBI;
use FileHandle;

@ISA = qw(Bio::Root::Root);

sub new {
  my($pkg, @args) = @_;

  my $self = $pkg->SUPER::new(@args);
  #bless {}, $pkg;

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
    

  my $dsn;
  if( $driver eq 'mysql' ) { 
      $dsn = "DBI:$driver:database=$db;host=$host;port=$port";
  }
  elsif( $driver eq 'Pg' ) {
      $dsn = "DBI:$driver:dbname=$db;host=$host";
      $dsn .= ";port=$port" if $port;
  }
  else {
      $self->throw("unknown driver:$driver\n");
  }
  my $dbh;
  print STDERR "dsn=$dsn; user=$user\n" if $ENV{SQL_TRACE};
  eval {
      $dbh = DBI->connect("$dsn","$user",$password, {RaiseError => 1});
  };
  if ($@) {
      $self->throw("connection err:$@");
  }
  $dbh->{ChopBlanks} = 1;
  $dbh || $self->throw("Could not connect to database $db user $user using [$dsn] as a locator Die is $@, DBI error".$DBI::errstr);
  
  $self->_db_handle($dbh);
  $self->username( $user );
  $self->driver( $driver );
  $self->host( $host );
  $self->dbname( $db );
 
  
  return $self; # success - we hope!
}

#Simple getsets for the dbhandle parameters, in case they need to be called

sub dbname {
  my ($self, $arg ) = @_;
  ( defined $arg ) &&
    ( $self->{_dbname} = $arg );
  $self->{_dbname};
}

sub driver {
  my ($self, $arg ) = @_;
  ( defined $arg ) &&
    ( $self->{_driver} = $arg );
  $self->{_driver};
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


=head2 get_PrimarySeqAdaptor

 Title   : get_PrimarySeqAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_PrimarySeqAdaptor{
   my ($self) = @_;

   if( !defined $self->{'_primaryseqadaptor'} ) {
       $self->{'_primaryseqadaptor'} = Bio::DB::SQL::PrimarySeqAdaptor->new($self);
   }

   return $self->{'_primaryseqadaptor'}
}

=head2 get_SeqFeatureAdaptor_

 Title   : get_SeqFeatureAdaptor_
 Usage   :
 Function:
 Example :
 Returns :
 Args    :


=cut

sub get_SeqFeatureAdaptor{
   my ($self) = @_;

   if( !defined $self->{'_seq_feature_adaptor'} ) {
       $self->{'_seq_feature_adaptor'} = SQL::SeqFeatureAdaptor->new($self);
   }

   return $self->{'_seq_feature_adaptor'}

}



=head2 get_dbNames

 Title   : get_dbNames
 Usage   : $obj->get_dbNames()
 Function: find all possible biodatabase.name's available
 Example : 
 Returns : list of biodatabase.name fields
 Args    : none


=cut

sub get_dbNames{
   my ($self) = @_;
   my $dbh =  $self->{'_db_handle'};
   return undef unless $dbh;

	my $sth = $dbh->prepare('select name from biodatabase');
	$sth->execute;
	my @namelist;
	while (my ($dbn) = $sth->fetchrow_array){
		push @namelist, $dbn;
	}
    return @namelist;

}

=head2 _db_handle

 Title   : _db_handle
 Usage   : $obj->_db_handle($newval)
 Function: 
 Example : 
 Returns : value of _db_handle
 Args    : newvalue (optional)


=cut

sub _db_handle{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'_db_handle'} = $value;
    }
    return $self->{'_db_handle'};

}



=head2 DESTROY

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
   $obj->SUPER::DESTROY();
}


1;
