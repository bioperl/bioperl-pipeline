#
# Object for submitting jobs to and querying the LSF queue
#
# Cared for by Michele Clamp  <michele@sanger.ac.uk>
#
# Copyright Michele Clamp
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::Pipeline::BatchSubmission::LSF

=head1 SYNOPSIS

=head1 DESCRIPTION

Stores run and status details of an analysis job

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::BatchSubmission::LSF;

use Bio::Pipeline::BatchSubmission;
use Bio::Root::Root;
use vars qw(@ISA %OK_FIELD @ACTIONS);
use strict;

use Bio::Pipeline::PipeConf qw (RUNNER
                                NFSTMP_DIR
                                );


@ISA = qw(Bio::Pipeline::BatchSubmission) ;

BEGIN {

    @ACTIONS  = qw(WAITFORALL WAITFORALL_AND_UPDATE UPDATE NOTHING);

    # Authorize attribute fields
    foreach my $attr ( @ACTIONS) {
      $OK_FIELD{$attr}++;
    }
}

sub submit_batch{
    my ($self,$action) = @_;
    if($action) {
        $self->throw ("Action $action not allowed. Use only WAITFORALL WAITFORALL_AND_UPDATE UPDATE NOTHING")
        unless $OK_FIELD{$action};
    }

    my @job_ids;

    my $jobadaptor = $self->dbobj->get_JobAdaptor;


    #making the stderr and stdout files.
    my $num = int(rand(10));
    my $file = $NFSTMP_DIR."/$num/";
    if (! -e $file){
        system ("mkdir $file");
    }

    my @jobs = $self->get_jobs;
    
    foreach my $job(@jobs){
        push (@job_ids,$job->dbID);
        $file .= $job->dbID."_";        
    }

    $file .= $jobs[0]->analysis->logic_name.".".time().".".int(rand(1000));
    $self->stdout_file($jobs[0]->stdout_file);
    $self->stderr_file($jobs[0]->stderr_file);

    my $bsub = $self->construct_command_line;

    my $runner = $RUNNER || undef;

    unless (-x $runner) {
        $runner = __FILE__;
        $runner =~ s:/([^/]*/[^/]*)$:/runner.pl:;
        $self->throw("Can't locate runner.pl - needs to be set in PipeConf.pm") unless -x $runner;
    }

    $runner.= " -action $action" if defined $action;

    $bsub .= "$runner ".join(" ",@job_ids);

    print STDERR "opening bsub command line:\n $bsub\n";
    
    open (SUB,$bsub." 2>&1|");

    my $lsf;
    while(<SUB>){
        if (/Job <(\d+)>/) {
            $lsf = $1;
        }
    }

    if (! defined $lsf){
        print STDERR "couldn't submit jobs ".join(" ",@job_ids)." to LSF.\n";
        foreach my $job (@jobs){
            $job->set_status('FAILED');
        }
    }else{
        foreach my $job (@jobs){
            $job->set_status('SUBMITTED');
            $job->queue_id($lsf);
            $job->adaptor->update($job);
        }
    }
    close (SUB);

    $self->empty_batch;
    
    return 1;

}

sub construct_command_line{

    my ($self) = @_;

    my $bsub_line;
#    $bsub_line = "bsub ";
    $bsub_line = "bsub -o ".$self->stdout_file;

    $bsub_line .= " -e ".$self->stderr_file;

    if($self->nodes){
        my $nodes = $self->nodes;
    # $nodes needs to be a space-delimited list
        $nodes =~ s/,/ /;
        $nodes =~ s/ +/ /;
    # undef $nodes unless $nodes =~ m{(\w+\ )*\w};
        $bsub_line .= " -m '".$nodes."' ";
    } 

    $bsub_line .= " -q ".$self->queue    if defined $self->queue;
    $bsub_line .= " -J ".$self->jobname  if defined $self->jobname;
    $bsub_line .= " ".$self->parameters." "  if defined $self->parameters;
    $bsub_line .= " -E \"".$self->pre_exec."\"" if defined $self->pre_exec;
    $bsub_line .= " ";
    
    return $bsub_line;

}
    


1;
