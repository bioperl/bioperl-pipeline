
=head1 NAME

Bio::Pipeline::Monitor;

=cut

package Bio::Pipeline::Monitor;

use strict;
use vars qw(@ISA);
use Bio::Root::Root;
use Bio::Pipeline::SQL::DBAdaptor;

@ISA = qw(Bio::Root::Root);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);

    my ($dbhost, $dbname, $dbuser, $dbpass, $dbobj) = 
        $self->_rearrange([qw(HOST DBNAME USER PASS DBOBJ)],
            @args);
        
    if(defined $dbobj){
        $self->dbobj($dbobj);
    }elsif($dbname){
        my $db = Bio::Pipeline::SQL::DBAdaptor->new(
            -host => $dbhost,
            -dbname => $dbname,
            -user => $dbname,
            -pass => $dbpass
        );
        $self->dbobj($db);
    }else{
        $self->throw("DB object not assigned");
    }
        
    return $self;
}

sub dbobj {
    my ($self, $dbobj) = @_;
    return $self->{_dbobj} = $dbobj if defined $dbobj;
    return $self->{_dbobj};
} 

sub all_analysis {
    my ($self) = @_;
    my @ana = $self->dbobj->get_AnalysisAdaptor->fetch_all;
    return \@ana;
}

=head2 analysis_status

  Return:   a hash ref that the key is status name, and the value is the array
            reference of the number of jobs at each stage.
    {
        'NEW' => 100,
        'SUBMITTED' => {
            'READING' => 20,
            'RUNNING' => 12,
            'WRITING' => 30,
            'BATCHED' => 4
        },
        'FAILED' => {
            'READING' => 0,
            'RUNNING' => 3,
            'WRITING' => 7,
            'BATCHED' => 1
        },
        'COMPLETED' => 230
    }
    
=cut

sub analysis_status {
    my ($self, $dbid) = @_;

    my %status;
    foreach my $status (qw(SUBMITTED FAILED)){
        my @counts;
        my %stage;
        foreach my $stage (qw(READING RUNNING WRITING BATCHED)){
            my $count = $self->dbobj->get_JobAdaptor->get_job_count(
                -status=>[$status], -stage=>[$stage], -analysis_id=>$dbid);
            push @counts, $count;
            $stage{$stage} = $count;
        }
        $status{$status} = \%stage;
        my $total = 0;
        foreach(@counts){ $total += $_; }
        if($total == 0 && $status eq 'NEW'){
            $total = $self->dbobj->get_JobAdaptor->get_job_count(
                -status=>['NEW'], -analysis_id=>$dbid);
        }
        push @counts, $total;
#        $status{$status} = \@counts;
    }
    my $new = $self->dbobj->get_JobAdaptor->get_job_count(
        -status=>['NEW'], -analysis_id=>$dbid);
    $status{'NEW'} = $new;
    my $completed = $self->dbobj->get_JobAdaptor->get_completed_job_count(
        -analysis_id => $dbid);
    $status{'COMPLETED'} = $completed;
    return \%status;
}

sub failed_job {
    my ($self, $analysis_id) = @_;

}
1;

