
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
    my ($dbname, $host, $driver, $user, $pass, $contig_dbID, $analysis_logic_name, $analysis_id) =
        $self->_rearrange([qw( DBNAME HOST DRIVER USER PASS CONTIG_DBID ANALYSIS_LOGIC_NAME ANALYSIS_ID)], @args);
    
    if($dbname && $user){
        require "Bio/EnsEMBL/DBSQL/DBAdaptor.pm";
        my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
            -user => $user,
            -dbname => $dbname,
            -host => $host,
            -driver => $driver,
            -pass => $pass
        );
        $self->ens_dbadaptor($dba);
    }
	
#    $contig_dbID ||= 0; # $self->throw("contig_dbID is needed");
#    $self->contig_dbID($contig_dbID);
    $analysis_logic_name && $self->analysis_logic_name($analysis_logic_name);
    $analysis_id && $self->analysis_id($analysis_id);
    return $self;
}

sub ens_dbadaptor{
   my ($self, $arg) = @_;
   if(defined $arg){
       $self->{"_ens_dbadaptor"} = $arg;
   }
   return $self->{"_ens_dbadaptor"};
}

sub contig_dbID{
    my ($self, $arg) = @_;
    if(defined $arg){
        $self->{"_contig_dbid"} = $arg;
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
            $self->throw("Problem happens when fetching contig by dbID\n$@\n");
        }
        $self->contig($contig);
#        $self->{"_contig_name"} = $arg;
        
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

sub analysis_logic_name{
    my ($self, $arg) = @_;
    if(defined $arg){
        my $analysis;
        eval{
            $analysis = $self->ens_dbadaptor->get_AnalysisAdaptor->fetch_by_logic_name($arg);
        };
        if($@){
            $self->throw("Problem happens when fetching analysis by logic name\n$@");
        }
        $self->analysis($analysis);
#        $self->{'_analysis'} = $analysis;
#        $self->{'_analysis_id'} = $analysis->dbID;
#        $self->{'_analysis_logic_name'} = $arg;
    }
    return $self->{'_analysis_logic_name'};
}

sub analysis_id{
    my ($self, $arg) = @_;
    if(defined $arg){
        my $analysis;
        eval{
            $analysis = $self->ens_dbadaptor->get_AnalysisAdaptor->fetch_by_dbID($arg);
            $self->{'_analysis_logic_name'} = $analysis->logic_name;
        };
        # This is not an honest implementation, but works with BaseFeatureAdaptor well.
        # Because it just need an Analysis object with ID.
        if($@){
            $analysis = Bio::EnsEMBL::Analysis->new(
                -ID => $arg
            );
        }
        $self->{'_analysis'} = $analysis;
        $self->{'_analysis_id'} = $arg;
    }
    return $self->{'_analysis_id'};
}

    
sub analysis{
    my ($self, $arg) = @_;
    if(defined $arg && ref($arg) eq 'Bio::EnsEMBL::Analysis'){
        $self->{'_analysis'} = $arg;
        $self->{'_analysis_id'} = $arg->dbID;
        $self->{'_analysis_logic_name'} = $arg->logic_name;
    }
    return $self->{'_analysis'};
}


1;
