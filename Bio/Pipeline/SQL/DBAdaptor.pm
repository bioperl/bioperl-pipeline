# BioPerl module for Bio::Pipeline::SQL::DBAdaptor
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

Bio::Pipeline::SQL::DBAdaptor

=head1 SYNOPSIS

  use Bio::Pipeline::SQL::DBAdaptor;
  $DBAdaptor = Bio::Pipeline::SQL::DBAdaptor->new(-dbname =>"my_db",
                                                  -user   =>"root",
                                                  -host   =>"localhost",
                                                  -driver =>"mysql");
  my $jobadaptor - $DBAdaptor->get_JobAdaptor;
  my $ioadaptor - $DBAdaptor->get_IOHandlerAdaptor;

=head1 DESCRIPTION

The object representing the pipeline database. From this object,
you are able to access various pipeline objects via the adaptor
objects which you can retrieve via a get_XXXAdaptor call.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-pipeline@bioperl.org          - General discussion
  http://www.biopipe.org

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

package Bio::Pipeline::SQL::DBAdaptor;


use vars qw(@ISA %ADAPTORS $AUTOLOAD @ALLOWED);
use strict;
use DBI;

use Bio::Root::Root;

# Inherits from the base bioperl object

@ISA = qw(Bio::Root::Root);

BEGIN {

  @ALLOWED  = qw (  IOHandlerAdaptor
                    RuleAdaptor
                    AnalysisAdaptor
                    JobAdaptor
                    NodeAdaptor
                    InputAdaptor
                    NodeGroupAdaptor
                    DataMongerAdaptor
                    TransformerAdaptor);

  foreach my $adpt (@ALLOWED){
    $ADAPTORS{$adpt}=1;
  }
}

=head2 new 

  Title   : new 
  Usage   :  $DBAdaptor = Bio::Pipeline::SQL::DBAdaptor->new(-dbname =>"my_db",
                                                  -user   =>"root",
                                                  -host   =>"localhost",
                                                  -driver =>"mysql"):
  Function: Constructor 
  Returns : L<Bio::Pipeline::SQL::DBAdaptor> 
  Args    : -dbname: the database name 
            -user  : the user name
            -host  : the hostname
            -driver : the DBI driver
            -port   : the port of the database
            -pass   : the password

=cut

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
        $port = 3306; 
    }
    $password ||=undef;
  my $dsn = "DBI:$driver:database=$db;host=$host;port=$port";
  my @params = ("$dsn","$user");
  
  push @params,$password ? "$password":"";
  push @params, {RaiseError => 1};

  my $dbh = DBI->connect(@params) || $self->throw("Could not connect to database $db user $user using [$dsn] as a locator");

  $self->_db_handle($dbh);
  $self->username( $user );
  $self->host( $host );
  $self->dbname( $db );
  $self->port($port);
  $self->password($password);

  return $self; # success - we hope!
}

=head2 dbname

 Title   : dbname
 Function: get/set for dbname
 Example :
 Returns : a string 
 Args    : a string specifying the dbname 

=cut

sub dbname {
  my ($self, $arg ) = @_;
  ( defined $arg ) &&
    ( $self->{_dbname} = $arg );
  $self->{_dbname};
}

=head2 port

 Title   : port
 Function: get/set for port
 Example :
 Returns : a string
 Args    : a string specifying the port number

=cut

sub port {
    my ($self,$port) = @_;
    (defined $port ) && ($self->{_port} = $port);
    return $self->{_port};
}

=head2 username

 Title   : username
 Function: get/set for username
 Example :
 Returns : a string
 Args    : a string specifying the username

=cut

sub username {
  my ($self, $arg ) = @_;
  ( defined $arg ) &&
    ( $self->{_username} = $arg );
  $self->{_username};
}

=head2 password

 Title   : password
 Function: get/set for password
 Example :
 Returns : a string
 Args    : a string specifying the password

=cut

sub password{
  my ($self, $arg ) = @_;
  ( defined $arg ) &&
    ( $self->{_password} = $arg );
  $self->{_password};
}

=head2 host

 Title   : host
 Function: get/set for host
 Example :
 Returns : a string
 Args    : a string specifying the host

=cut

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

=head2 get_TransformerAdaptor

 Title   : get_TransformerAdaptor
 Usage   : $db->get_transformerAdaptor
 Function: The Adaptor for Transformer objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::TransformerAdaptor
 Args    : nothing

=cut

=head2 get_JobAdaptor

 Title   : get_JobAdaptor
 Usage   : $db->get_JobAdaptor
 Function: The Adaptor for Job objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::JobAdaptor
 Args    : nothing

=cut

=head2 get_IOHandlerAdaptor

 Title   : get_IOHandlerAdaptor
 Usage   : $db->get_IOHandlerAdaptor
 Function: The Adaptor for getting input/output handler objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::IOHandlerAdaptor
 Args    : nothing


=cut

=head2 get_InputAdaptor

 Title   : get_InputAdaptor
 Usage   : $db->get_InputAdaptor
 Function: The Adaptor for Input objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::InputAdaptor
 Args    : nothing

=cut

=head2 get_AnalysisAdaptor

 Title   : get_AnalysisAdaptor
 Usage   : $db->get_AnalysisAdaptor
 Function: The Adaptor for Analysis objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::AnalysisAdaptor
 Args    : nothing

=cut

=head2 get_RuleAdaptor

 Title   : get_RuleAdaptor
 Usage   : $db->get_RuleAdaptor
 Function: The Adaptor for Rule objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::RuleAdaptor
 Args    : nothing

=cut

=head2 get_DataMongerAdaptor;

 Title   : get_DataMongerAdaptor;
 Usage   : $db->get_DataMongerAdaptor;
 Function: The Adaptor for DataMonger objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::DataMongerAdaptor
 Args    : nothing

=cut

=head2 get_NodeAdaptor

 Title   : get_NodeAdaptor
 Usage   : $db->get_NodeAdaptor
 Function: The Adaptor for Node objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::NodeAdaptor
 Args    : nothing

=cut

=head2 get_NodeGroupAdaptor

 Title   : get_NodeGroupAdaptor
 Usage   : $db->get_NodeGroupAdaptor
 Function: The Adaptor for NodeGroup objects in this db
 Example :
 Returns : Bio::Pipeline::SQL::NodeGroupAdaptor
 Args    : nothing

=cut

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

=head2 get_XXXAdaptor

 Title   : get_XXXAdaptor
 Usage   : my $feat = $dba->get_JobAdaptor
 Function: Fetches the adaptor for objects
           Uses the AUTOLOAD function to get the adaptor
           The available adaptors are specified in the ADAPTORS array
           specified in the BEGIN block
           Throws an exception if the adpator name is not found
           the array
 Returns : Bio::GFD::SQL::XXXAdaptor
 Args    : nothing

=cut

sub AUTOLOAD {
  my ($self) = @_;
  my $loader = $AUTOLOAD;
  if (($loader =~ /get_(\D+Adaptor)$/) && exists $ADAPTORS{$1}){
    my $adaptor = $1;
    if (! defined $self->{"_$adaptor"}){
      $self->{"_$adaptor"} = '';
      my $module = "Bio/Pipeline/SQL/$adaptor";
      require "$module.pm";
      $module =~ s/\//\::/g;
      $self->{"_$adaptor"} = (${module}->new($self));
    }
    return $self->{"_$adaptor"};
  }else{
    $self->throw("Calling unknown method $loader");
  }
}

=head2 DESTROY

 Title   : DESTROY
 Function: Disconnect from the database
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

1;
