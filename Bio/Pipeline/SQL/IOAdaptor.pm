package Bio::Pipeline::SQL::IOAdaptor;

use vars qw(@ISA);
use strict;

use Bio::Root::Root;
use Bio::Pipeline::IO;

@ISA = qw(Bio::Root::Root);

sub new {
    my($class,@args) = @_;
    
    my $self = $class->SUPER::new(@args);

    my ($dbadpt,$analysis,$bio_dbadpt,$bio_dbname,$data_adpt,$data_adpt_meth) = $self->_rearrange([qw(DBADAPTOR
                                                                                                      ANALYSIS
                                                                                                      BIODBADAPTOR
                                                                                                      BIODBNAME
                                                                                                      DATAADAPTOR
                                                                                                      DATAADAPTORMETHOD)],@args);
                                                                                                      
    $self->throw("Need a db adaptor or bio db adaptor") unless ($dbadpt || ($bio_dbadpt && $bio_dbname));
    $self->db_adaptor($dbadpt);
    $self->analysis($analysis);
    $self->bio_dbadaptor($bio_dbadpt);
    $self->bio_dbname($bio_dbname);
    $self->data_adaptor($data_adpt);
    $self->data_adaptor_method($data_adpt_meth);
}


sub db_adaptor {
    my ($self,$arg) = @_;

    if (defined($arg)) {
      $self->{'_db_adaptor'} = $arg;
    }
    return $self->{'_db_adaptor'};

}
sub analysis{
    my ($self,$arg) = @_;

    if (defined($arg)) {
      $self->{'_analysis'} = $arg;
    }
    return $self->{'_analysis'};

}
sub bio_dbadaptor {
    my ($self,$arg) = @_;

    if (defined($arg)) {
      $self->{'_bio_dbadaptor'} = $arg;
    }
    return $self->{'_bio_dbadaptor'};

}
sub bio_dbname {
    my ($self,$arg) = @_;

    if (defined($arg)) {
      $self->{'_bio_dbname'} = $arg;
    }
    return $self->{'_bio_dbname'};

}
sub data_adaptor {
    my ($self,$arg) = @_;

    if (defined($arg)) {
      $self->{'_data_adaptor'} = $arg;
    }
    return $self->{'_data_adaptor'};

}
sub data_adaptor_method {
    my ($self,$arg) = @_;

    if (defined($arg)) {
      $self->{'_data_adaptor_method'} = $arg;
    }
    return $self->{'_data_adaptor_method'};

}

sub fetch_by_input_dbID {
    my ($self,$sql) = @_;
    $sql || $self->throw("Need sql statment");
    
    my $sth = $self->prepare($sql);
    $sth->execute();
    
    my ($dbadaptor_id,$analysis_id,$biodbadaptor,$biodbname,$data_adaptor,$data_adaptor_method) = $sth->fetchrow_array;

    #fetch dbadaptor
    my $dbadaptor = $self->_fetch_db_adaptor($dbadaptor_id);
    my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_dbID($analysis_id);

    my $io = Bio::Pipeline::IO->new(-dbadaptor=>$dbadaptor,
                                    -analysis=>$analysis,
                                    -biodbadaptor=>$biodbadaptor,
                                    -biodbname=>$biodbname,
                                    -dataadaptor=>$data_adaptor,
                                    -dataadaptormethod=>$data_adaptor_method);


    return $io;
}
sub fetch_by_input_dbID {
    my ($self,$id) = @_;
    my $sql = "SELECT 
               dbadaptor_id,
               analysis_id,
               biodbadaptor,
               biodbname,
               data_adaptor,
               data_adaptor_method 
               FROM input_adaptor 
               WHERE input_adaptor_id = '$id'";
    my $io = $self->_fetch_io($sql);
    return $io;
}

sub fetch_by_ouput_dbID {
    my ($self,$id) = @_;
    my $sql = "SELECT 
               dbadaptor_id,
               analysis_id,
               biodbadaptor,
               biodbname,
               data_adaptor,
               data_adaptor_method 
               FROM output_adaptor 
               WHERE output_adaptor_id = '$id'";
    my $io = $self->_fetch_io($sql);
    return $io;
}

sub _fetch_db_adaptor {
    my ($self,$id) = @_;
    my $sth = $self->prepare("SELECT dbname,driver,host,user,pass,module 
                              FROM dbadaptor
                              WHERE dbadaptor_id = $id");
    $sth->execute();
    my ($dbname,$driver,$host,$user,$pass,$module) = $sth->fetchrow_array();
    if($module =~/::/)  {
         $module =~ s/::/\//g;
         require "${module}.pm";
         $module =~s/\//::/g;
     }
    my $db_adaptor = "${module}"->new(-dbname=>$dbname,-user=>$user,-host=>$host,-driver=>$driver,-pass=>$pass);
    #    require Bio::EnsEMBL::DBSQL::DBAdaptor ;
    #my $db_adaptor = Bio::EnsEMBL::DBSQL::DBAdaptor->new(-dbname=>$dbname,-user=>$user,-host=>$host,-driver=>$driver,-pass=>$pass);
    return $db_adaptor;
}


1;


