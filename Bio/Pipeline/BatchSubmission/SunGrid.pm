# BioPerl runnable for Bio::Pipeline::BatchSubmission::SunGrid
#
# Based on the Bio::Pipeline::BatchSubmission:LSF module
#
# Written by Tania Oh (tania.oh@anat.ox.ac.uk)
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod

=head1 NAME

Bio::Pipeline::BatchSubmission::SunGrid

=head1 SYNOPSIS

   my $batchsub = Bio::Pipeline::BatchSubmission::SunGrid->new(
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

Wrapper for SunGrid job management system

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

Email tania.oh@anat.ox.ac.uk 

=head1 APPENDIX
The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::BatchSubmission::SunGrid;

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
  Function : do the actual job submission to SunGrid
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

    my $runner = $self->runner_path || $RUNNER || undef;

    unless (-x $runner) {
        $runner = __FILE__;
        $runner =~ s:/([^/]*/[^/]*/[^/]*/[^/]*)$:/runner.pl:;
        $self->throw("Can't locate runner.pl - needs to be set in PipeConf.pm") unless -x $runner;
    }
   
    my $jobID_file = $NFSTMP_DIR."/$num.jobid";   
    open (JOBID, ">$jobID_file");

# Create Script
    #wierd, but if i don't put a character in front of the $num, 
    #the sun grid engine rejects it.. so I chose to put "new".
    my $sungrid_script = $NFSTMP_DIR."/new$num.sungrid";  
  open (SunGrid_SCRIPT, ">$sungrid_script");

    $runner = $self->construct_runner_param($runner);

    print SunGrid_SCRIPT  $runner . " " . join(" ",@job_ids);
   #bug fix! need this \n else script never executes!!
    print SunGrid_SCRIPT ";\n";
    close (SunGrid_SCRIPT);
# Finish Script

#    $qsub .= "$runner ". " < $jobID_file";
    $qsub .= $sungrid_script;

    print STDERR "opening qsub command line:\n $qsub\n";
    
    open (SUB,$qsub." 2>&1|");

    my $sungrid;
    #checks if jobs were submitted to SunGrid. 'your job 48044 ("new2.sungrid") has been submitted'

    while(<SUB>){

       if (/job (\d+) \(/){
           $sungrid = $1;  

       }
    }

    if (! defined $sungrid){
        print STDERR "couldn't submit jobs ".join(" ",@job_ids)." to SunGrid.\n";
        foreach my $job (@jobs){
            $job->set_status('FAILED');
        }
    }else{
        foreach my $job (@jobs){
            $job->set_status('SUBMITTED');
            $job->queue_id($sungrid);
            $job->adaptor->update($job);
        }
    }
    close (SUB);

    $self->empty_batch;
    
    return 1;

}

=head2 construct_command_line

  Title    : construct_command_line
  Function : constructs the SunGrid command line
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

    #for sun grid engine here in the lab, one queue = one node. 
    #ie. if you do "-q node01" ie. you are forcing it on node01 
    # and the concept of queues is that if you want a higher priority, 
    # then you need to use the -p option.

            my $nodes = $self->queue   if defined $self->queue; 
          # $nodes needs to be a comma-delimited list
            #$nodes =~ s/,/ /;
            #$nodes =~ s/ +/ /;
          # undef $nodes unless $nodes =~ m{(\w+\ )*\w};
            $qsub_line .= " -q '".$nodes."' ";


    $qsub_line .= " -p ". $self->priority    if defined $self->priority; 
    $qsub_line .= " ";
    
    return $qsub_line;

}
    


1;
