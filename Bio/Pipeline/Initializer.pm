package Bio::Pipeline::Initializer;
##What Package to put??

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Exon;
use Bio::EnsEMBL::Transcript;
use Bio::EnsEMBL::FeatureFactory;
use Bio::EnsEMBL::DBSQL::RawContigAdaptor;
use DBI;
use Bio::EnsEMBL::DBSQL::Utils;
use Bio::EnsEMBL::DBSQL::DummyStatement;
use Bio::EnsEMBL::DBSQL::FeatureAdaptor;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::SeqFeature;
use Bio::EnsEMBL::FeaturePair;
use Bio::EnsEMBL::Analysis;
use Bio::Root::Root;
@ISA = qw(Bio::Root::Root);

my $db_adaptor;
#my $dbh;
sub new{
my ($class, @args) = @_;
my $self = $class->SUPER::new(@args);
 my (
        $dbname,
        $dbhost,
        $driver,
        $user,
        ) = $self->_rearrange([qw(
            DBNAME
            HOST
            DRIVER
            USER
            )],@args);

$self->dbname($dbname);
$self->dbhost($dbhost);
$self->driver($driver);
$self->user($user);

#my $user =$self->user ;
#my $db =$self->dbname;
#my $dbsource = "DBI:mysql:$db";
#$dbh = DBI->connect($dbsource, $user) ||
#die print "couldn't connect using Source : $dbsource, User : $user";


return $self;

}


sub get_contig_input_through_internal_id{
    my($self)=@_;
   my $user =$self->user ;
   my $db =$self->dbname;
   my $dbsource = "DBI:mysql:$db";
    
   my $dbh = DBI->connect($dbsource, $user) ||
    die print "couldn't connect using Source : $dbsource, User : $user";
   my $count;
   my $sth = $dbh->prepare('SELECT COUNT(*) FROM contig');
   $sth->execute;
   while (my @data = $sth->fetchrow_array()){
    $count = $data[0];
  }
 $dbh->disconnect;
 return $count;   
}
sub dbname {
        my ($self,$dbname) = @_;

        if (defined($dbname)){
        $self->{'_dbname'} = $dbname;
        }
        return $self->{'_dbname'};
}
sub dbhost {
        my ($self,$dbhost) =  @_;

        if (defined($dbhost)){
        $self->{'_dbhost'} = $dbhost;
        }
        return $self->{'_dbhost'};
}

sub user {

       my ($self,$user) =  @_;
       if (defined($user)){
       $self->{'_user'} = $user;
       }
       return $self->{'_user'};

}


sub driver {

       my ($self,$driver) =  @_;
       if (defined($driver)){
       $self->{'_driver'} = $driver;
       }
       return $self->{'_driver'};

}   
1;     
    
    
