
package Bio::Pipeline::Converter::BaseEnsEMBLConverter;

use vars qw(@ISA);

use strict;
# use Bio::SeqFeatureIO;
use Bio::EnsEMBL::Analysis;
use Bio::Pipeline::Converter;

@ISA = qw(Bio::Pipeline::Converter);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);

    my $analysis = $self->analysis;
    $self->throw("A Biopipe Analysis object is wanted in converter")
        unless(defined($analysis));

    my $ensembl_analysis = Bio::EnsEMBL::Analysis->new(
        -logic_name => $analysis->logic_name,
        -gff_source => $analysis->gff_source,
        -gff_feature => $analysis->gff_feature,
    );
    
    my $iohandler = $self->iohandler;
    $self->throw("A iohandler is needed in ensembl converter")
        unless(defined($iohandler));

    $self->throw("A DB adaptor is needed in  ensembl converter")
        unless($iohandler->adaptor_type() eq 'DB');

    
#    my ($dba, $dbname, $host, $driver, $user, $pass, 
#        $contig_dbID, 
#        $analysis_logic_name, $analysis_id) =
        
#        $self->_rearrange([qw(
#            DBA DBNAME HOST DRIVER USER PASS 
#            CONTIG_DBID 
#            ANALYSIS_LOGIC_NAME ANALYSIS_ID)], 
#            @args);

#    $self->_autoload_getsets([qw(ens_dbadaptor dba)]);
    
    my $dba = $iohandler->dbadaptor;
    my $dbname = $iohandler->dbadaptor_dbname;
    my $user = $iohandler->dbadaptor_user;
    if(defined $dba and ref($dba) eq 'Bio::EnsEMBL::DBSQL::DBAdaptor'){
        $self->ens_dbadaptor($dba);
#        $self->dba($dba);
    }elsif($dbname && $user){
        my $driver = $iohandler->dbadaptor_driver;
        my $host = $iohandler->dbadaptor_host;
        my $pass = $iohandler->dbadaptor_pass;
        
        $host = 'localhost' unless defined($host);
        require "Bio/EnsEMBL/DBSQL/DBAdaptor.pm";
        my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
            -user => $user,
            -dbname => $dbname,
            -host => $host,
            -driver => $driver,
            -pass => $pass
        );
        $self->ens_dbadaptor($dba);
#        $self->dba($dba);
    }else{
        $self->throw("EnsEMBLConverter does not have the ensembl dbadaptor");
    }
	
# the Bio::EnsEMBL::DBSQL::AnalysisAdaptor::store is responsible to check whether this analysis is in db.
    $self->ens_dbadaptor->get_AnalysisAdaptor->store($ensembl_analysis);
    $self->ensembl_analysis($ensembl_analysis);

#    $contig_dbID ||= 0; # $self->throw("contig_dbID is needed");
#    $self->contig_dbID($contig_dbID);
#    $analysis_logic_name && $self->analysis_logic_name($analysis_logic_name);
#    $analysis_id && $self->analysis_id($analysis_id);
    
    return $self;
}

#sub ens_dbadaptor{
#   my ($self, $arg) = @_;
#   if(defined $arg){
#       $self->{"_ens_dbadaptor"} = $arg;
#   }
#   return $self->{"_ens_dbadaptor"};
#}

sub contig_dbID{
    my ($self, $arg) = @_;
    if(defined $arg){
        my $contig;
        eval{
            $contig = $self->ens_dbadaptor->get_RawContigAdaptor->fetch_by_dbID($arg);
        };
        if($@){
            $self->throw("Problem happens when fetching contig by dbID\n$@\n");
        }
        $self->contig($contig);
    }
    return $self->{"_contig_dbid"};
}

sub contig_name{
    my ($self, $arg) = @_;
    if(defined $arg){
        my $contig;
        eval{
            $contig = $self->ens_dbadaptor->get_RawContigAdaptor->fetch_by_name($arg);
        };
        if($@){
            $self->throw("Problem happens when fetching contig by name\n$@\n");
        }
        $self->contig($contig);
        
    }
    return $self->{"_contig_name"};
}

sub contig{
    my ($self, $arg) = @_;
    if(defined $arg && ref($arg) eq 'Bio::EnsEMBL::RawContig'){
        $self->{'_contig'} = $arg;
        $self->{'_contig_dbid'} = $arg->dbID;
        $self->{'_contig_name'} = $arg->name;
    }
    return $self->{'_contig'};
}

sub ensembl_analysis_logic_name{
    my ($self, $arg) = @_;
    if(defined $arg){
        my $ens_analysis;
        eval{
            $ens_analysis = $self->ens_dbadaptor->get_AnalysisAdaptor->fetch_by_logic_name($arg);
        };
        if($@){
            $self->throw("Problem happens when fetching analysis by logic name\n$@");
        }
        $self->ensembl_analysis($ens_analysis);
#        $self->{'_analysis'} = $analysis;
#        $self->{'_analysis_id'} = $analysis->dbID;
#        $self->{'_analysis_logic_name'} = $arg;
    }
    return $self->{'_ensembl_analysis_logic_name'};
}

sub ensembl_analysis_id{
    my ($self, $arg) = @_;
    if(defined $arg){
        my $ens_analysis;
        eval{
            $ens_analysis = $self->ens_dbadaptor->get_AnalysisAdaptor->fetch_by_dbID($arg);
            $self->{'_ensembl_analysis_logic_name'} = $ens_analysis->logic_name;
        };
        # This is not an honest implementation, but works with BaseFeatureAdaptor well.
        # Because it just need an Analysis object with ID.
        if($@){
            $ens_analysis = Bio::EnsEMBL::Analysis->new(
                -ID => $arg
            );
        }
        $self->{'_ensembl_analysis'} = $ens_analysis;
        $self->{'_ensembl_analysis_id'} = $arg;
    }
    return $self->{'_ensembl_analysis_id'};
}

    
sub ensembl_analysis{
    my ($self, $arg) = @_;
    if(defined $arg){
        $self->throw("a Bio::EnsEMBL::Analysis obj expected")
            unless(ref($arg) eq 'Bio::EnsEMBL::Analysis');
        $self->{'_ensembl_analysis'} = $arg;
        $self->{'_ensembl_analysis_id'} = $arg->dbID;
        $self->{'_ensembl_analysis_logic_name'} = $arg->logic_name;
    }
    return $self->{'_ensembl_analysis'};
}

sub ens_dbadaptor {
    my($self, $arg) = @_;
    $self->{_ens_dbadaptor} = $arg if(defined($arg));
    return $self->{_ens_dbadaptor};
}



1;
