# BioPerl runnable for Bio::Pipeline::BatchSubmission::PBS
#
# Based on the Bio::Pipeline::BatchSubmission:LSF module
#
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
   $batchsub->submit_batch();  
   my $hostname = $batchsub->get_host_name(); #returns the hostname
   my @killed_queue_ids = $batchsub->kill_jobs(@queue_ids);
   

=head1 DESCRIPTION

Wrapper for PBS job management system
This has been tested for the freely availabe Torque/Maui System.


=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-pipeline@bioperl.org          - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

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
use Bio::Root::IO;
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

    my $jobadaptor = $self->dbobj->get_JobAdaptor;

    my @jobs = $self->get_jobs;
     
    my %sorted_jobs = %{$self->sort_by_queue(@jobs)};

    #submit jobs to different queues
    #a given batch of jobs may belong to different queues
    foreach my $q(keys %sorted_jobs){
      $self->submit_jobs($q,@{$sorted_jobs{$q}});
    }
    $self->empty_batch;
}

=head2 submit_jobs

  Title    : submit_jobs
  Function : submit jobs given a list of job ids and the queue
  Example  : $bs->submit_jobs($queue, @jobs)
  Returns  : true if successful
  Args     : 1: the queue id (string)
             2: an array of L<Bio::Pipeline::Job>

=cut

sub submit_jobs {
  my ($self,$queue,@jobs) = @_;
    
    #making the stderr and stdout files.
    my $num = int(rand(10));
    my $file = $NFSTMP_DIR."/$num/";
    if (! -e $file){
        system ("mkdir $file");
    }

    my @job_ids;
    foreach my $job(@jobs){
        push (@job_ids,$job->dbID);
        $file .= $job->dbID."_";        
    }

    $file .= $jobs[0]->analysis->logic_name.".".time().".".int(rand(1000));

    #set the stdout and stderr files to that of the job
    $self->stdout_file($jobs[0]->stdout_file);
    $self->stderr_file($jobs[0]->stderr_file);

    #create the qsub command
    my $qsub = $self->construct_command_line($queue);

    #find the runner.pl script
    my $runner = $self->runner_path || $RUNNER || undef;

    unless (-x $runner) {
        $runner = __FILE__;
        $runner =~ s:/([^/]*/[^/]*/[^/]*/[^/]*)$:/runner.pl:;
        $self->throw("Can't locate runner.pl - needs to be set in PipeConf.pm") unless -x $runner;
    }
   
    my $jobID_file = $NFSTMP_DIR."/$num.jobid";   
    open (JOBID, ">$jobID_file");

    #PBS requires a script file to be submitted
    my $pbs_script = "$file.pbs"; 
    open (PBS_SCRIPT, ">$pbs_script");
    $runner = $self->construct_runner_param($runner);
    print PBS_SCRIPT $runner . " " . join(" ",@job_ids);

    #remove script file upon completion
    print PBS_SCRIPT "\nrm $pbs_script"; 
    close (PBS_SCRIPT);
    # Finish Script

    $qsub .= $pbs_script;

    $self->debug("Opening qsub command line:\n $qsub\n");

   
    #Submit the Jobs 
    print STDERR "Submitting jobs ".join(",",@job_ids)." to queue ".$queue."\n";
    open (SUB,$qsub." 2>&1|");

    my $pbs;
    while(<SUB>){
       if (/(\d+).(\w+)/){
           $pbs = $1;  
           print STDERR "PBS OUT: $pbs\n";
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

    my ($self,$queue) = @_;

    my $qsub_line;

    $qsub_line = "qsub -o  ".$self->stdout_file;
    
    $qsub_line .= " -e ".$self->stderr_file;

    $qsub_line .= " -N ".$self->jobname  if defined $self->jobname;

    if($self->nodes){
        my $nodes = $self->nodes;
        # $nodes needs to be a space-delimited list
        $nodes =~ s/,/ /;
        $nodes =~ s/ +/ /;
        # undef $nodes unless $nodes =~ m{(\w+\ )*\w};
        $qsub_line .= " -m '".$nodes."' ";
    } 

    $queue ||= $self->queue; 
    $qsub_line .= " -q ".$queue    if defined $queue;
    $qsub_line .= " ".$self->parameters." "  if defined $self->parameters;

    $qsub_line .= " ";
    
    return $qsub_line;

}
  
=head2 get_host_name

  Title    : get_host_name
  Function : gets the hostname of the node
  Example  : $command = $bs->get_host_name;
  Returns  : a string
  Args     : a string

=cut

sub get_host_name {
  my ($self,$queue_id) = @_; 
  my $io = Bio::Root::IO->new();
  my ($fh,$file) = $io->tempfile();

  #Unix specific, simplest way I can think of right now
  my $hostname = `hostname`;
  return $hostname || "NULL";
}

=head2 kill_jobs

  Title    : kill_jobs
  Function : kills jobs in the queue using qdel command
  Example  : $command = $bs->kill_jobs;
  Returns  : 
  Args     : a list of queue ids

=cut

sub kill_jobs {
  my ($self,@queueIDs) = @_;
  #hash it up to check against list of queue ids to kill
  my %hash_q = map{$_=>1}@queueIDs;

  my @queue = `qstat -f |grep 'Job Id'`;
  my @queue_ids;
  foreach my $q(@queue){
    chomp($q);
    $q=~/Job Id: (\w+)/;
    my $qid = $1;
    next unless $hash_q{$qid};
    my $kill_str = "qdel $qid";
    $self->debug($kill_str);
    my $status = system($kill_str);  
    if($status !=0){
      $self->warn("Couldn't kill $status");
    }
    else {
      push @queue_ids, $qid;

    }
  }
 #return list of successfully killed jobs 
 return @queue_ids;
}




1;
