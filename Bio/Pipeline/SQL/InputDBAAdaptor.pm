package Bio::Pipeline::SQL::InputDBAAdaptor;

use vars qw(@ISA);
use strict;

use Bio::DB::SQL::BaseAdaptor;
use Bio::DB::SQL::IOAdaptor;

@ISA = qw(Bio::DB::SQL::BaseAdaptor);


sub fetch_by_dbID {
    my ($self,$id) = @_;
    $id || $self->throw("Need a db ID");
    
    my $sth = $self->prepare("SELECT 
                              analysis_id
                              dbadaptor_id
                              biodbadaptor
                              biodbname
                              data_adaptor
                              data_adaptor_method
                              FROM input_dba 
                              WHERE inpuut_dba_id = '$id'"
                              );
    $sth->execute();
    
    my ($analysis_id,$dbadaptor_id,$biodbadaptor,$biodbname,$data_adaptor,$data_adaptor_method) = $sth->fetchrow_array;

    #fetch dbadaptor
    my $dbadaptor;
    if($dbadaptor_id){ #if no dbadaptor, then we are using the biodbadaptor
      $dbadaptor = $self->_fetch_db_adaptor($dbadaptor_id);
    }
    my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_dbID($analysis_id);

    my $ioadpt = Bio::Pipeline::IOAdaptor->new(-dbadaptor=>$dbadaptor,
                                               -analysis=>$analysis,
                                               -biodbadaptor=>$biodbadaptor,
                                               -biodbname=>$biodbname,
                                               -dataadaptor=>$data_adaptor,
                                               -dataadaptormethod=>$data_adaptor_method);

    return $ioadpt;
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

    return $db_adaptor;
}


1;


