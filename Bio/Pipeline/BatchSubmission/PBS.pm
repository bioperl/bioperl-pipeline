# BioPerl runnable for Bio::Pipeline::BatchSubmission::PBS

# Written by FuguI team (fugui@fugu-sg.org)
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod

=head1 NAME

Bio::Pipeline::BatchSubmission::PBS

=head1 SYNOPSIS

   my $batchsub = Bio::Pipeline::BatchSubmission::PBS->new(
                  -dbobj => $dbobj,
                  -stdout => $stdout,
                  -stderr => $stderr,
                  -parameters => $pars,
                  -pre_exec => $pre,
                  -command => $command,
                  -queue => $queue,
                  -jobname => $jobn,
                  -nodes => $nodes
                  );

=head1 DESCRIPTION

Wrapper for PBS job management system

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-pipeline@bioperl.org          - General discussion
  http://bio.perl.org/MailList.html             - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:

  bioperl-bugs@bio.perl.org
  http://bugzilla.bioperl.org/

=head1 AUTHOR

Email fugui@fugu-sg.org

=head1 APPENDIX
The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::BatchSubmission::PBS;

use Bio::Pipeline::BatchSubmission;
use Bio::Root::Root;
use vars qw(@ISA);
use strict;

use Bio::Pipeline::PipeConf qw (RUNNER
                                NFSTMP_DIR
                                );


@ISA = qw(Bio::Pipeline::BatchSubmission) ;

=head2 submit_batch

  Title    : submit_batch
  Function : do the actual job submission to PBS
  Example  : $bs->submit_batch
  Returns  : true if successful
  Args     :

=cut

sub submit_batch{
    my ($self) = @_;

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

#   Why are we creating the stdout & stderr file again??
#    $self->stdout_file($file.".out");
#    $self->stderr_file($file.".err");
    $self->stdout_file($jobs[0]->stdout_file);
    $self->stderr_file($jobs[0]->stderr_file);


    my $qsub = $self->construct_command_line;

    my $runner = $RUNNER || undef;

    unless (-x $runner) {
        $runner = __FILE__;
        $runner =~ s:/([^/]*/[^/]*/[^/]*/[^/]*)$:/runner.pl:;
        $self->throw("Can't locate runner.pl - needs to be set in PipeConf.pm") unless -x $runner;
    }
   
    my $jobID_file = $NFSTMP_DIR."/$num.jobid";   
    open (JOBID, ">$jobID_file");

# Create Script
    my $pbs_script = $NFSTMP_DIR."/$num.pbs"; 
    open (PBS_SCRIPT, ">$pbs_script");

    $runner = $self->construct_runner_param($runner);

    print PBS_SCRIPT $runner . " " . join(" ",@job_ids);
    close (PBS_SCRIPT);
# Finish Script

#    $qsub .= "$runner ". " < $jobID_file";
    $qsub .= $pbs_script;

    print STDERR "opening qsub command line:\n $qsub\n";
    
    open (SUB,$qsub." 2>&1|");

    my $pbs;
    #checks if jobs were submitted to PBS. checking for the hostname in 132.white.bii-sg.org

    while(<SUB>){

       if (/(\d+).(\w+)/){
           $pbs = $1;  
       }
    }

    if (! defined $pbs){
        print STDERR "couldn't submit jobs ".join(" ",@job_ids)." to PBS.\n";
        foreach my $job (@jobs){
            $job->set_status('FAILED');
        }
    }else{
        foreach my $job (@jobs){
            $job->set_status('SUBMITTED');
            $job->queue_id($pbs);
            $job->adaptor->update($job);
        }
    }
    close (SUB);

    $self->empty_batch;
    
    return 1;

}

=head2 construct_command_line

  Title    : construct_command_line
  Function : constructs the PBS command line
  Example  : $command = $bs->construct_command_line;
  Returns  : a string
  Args     : a string

=cut

sub construct_command_line{

    my ($self) = @_;

    my $qsub_line;
     

    $qsub_line = "qsub -o  ".$self->stdout_file;
    
    $qsub_line .= " -e ".$self->stderr_file;

    $qsub_line .= " -N ".$self->jobname  if defined $self->jobname;

    $qsub_line .= " -l nodes=1";

    if($self->nodes){
        my $nodes = $self->nodes;
    # $nodes needs to be a space-delimited list
        $nodes =~ s/,/ /;
        $nodes =~ s/ +/ /;
    # undef $nodes unless $nodes =~ m{(\w+\ )*\w};
        $qsub_line .= " -m '".$nodes."' ";
    } 

    $qsub_line .= " -q ".$self->queue    if defined $self->queue;

    $qsub_line .= " ";
    
    return $qsub_line;

}
    


1;
